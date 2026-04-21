# Implementation Plan for AirLabs API Cache Resolver Integration

## Goal
Replace the placeholder `AviationEdgeClient.get_transit_time_hours` (currently returning a static value) with a real implementation that:
1. Retrieves the median flight duration between two IATA airports using the AirLabs API (`/schedules` endpoint).
2. Caches results in a local SQLite (or JSON) store (`RoutesTable`) with TTL of 90 days.
3. Returns the median duration (in hours) and reliability percentage.
4. Provides a lazy‑loading cache that refreshes when data is stale or when a forced refresh is requested.

## Scope
- Modify `SCDO.py` (or a new module) to add a `AirLabsCacheResolver` class.
- Update `AviationEdgeClient` to delegate to this resolver.
- Add a small utility for median calculation and TTL handling.
- Ensure the rest of the simulation (AirLink) continues to receive only the total flight duration; ground‑side delays remain unchanged.

## Design Details
### 1. Data Store
- Use **SQLite** (`airlabs_cache.db`) located in the project root for simplicity and atomicity.
- Table schema:
```sql
CREATE TABLE IF NOT EXISTS RoutesTable (
    RouteID TEXT PRIMARY KEY,   -- "ORIGIN_DEST"
    Origin TEXT NOT NULL,
    Dest TEXT NOT NULL,
    MedianDuration REAL NOT NULL,   -- hours
    Reliability REAL NOT NULL,       -- percentage (0‑100)
    Timestamp DATETIME NOT NULL      -- UTC when cached
);
```
- TTL: 90 days. When a cached entry is older, it will be refreshed.

### 2. Cache Resolver Class
```python
class AirLabsCacheResolver:
    def __init__(self, api_key: str, db_path: str = "airlabs_cache.db"):
        self.api_key = api_key
        self.db_path = db_path
        self._init_db()

    def _init_db(self):
        import sqlite3, os
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS RoutesTable (
                RouteID TEXT PRIMARY KEY,
                Origin TEXT NOT NULL,
                Dest TEXT NOT NULL,
                MedianDuration REAL NOT NULL,
                Reliability REAL NOT NULL,
                Timestamp DATETIME NOT NULL
            );
        """)
        conn.commit()
        conn.close()

    def _get_cached(self, key: str):
        import sqlite3, datetime
        conn = sqlite3.connect(self.db_path)
        cur = conn.execute("SELECT MedianDuration, Reliability, Timestamp FROM RoutesTable WHERE RouteID=?", (key,))
        row = cur.fetchone()
        conn.close()
        if row:
            median, reliability, ts = row
            ts = datetime.datetime.fromisoformat(ts)
            # TTL check (90 days)
            if datetime.datetime.utcnow() - ts < datetime.timedelta(days=90):
                return median, reliability
        return None

    def _store(self, key: str, origin: str, dest: str, median: float, reliability: float):
        import sqlite3, datetime
        conn = sqlite3.connect(self.db_path)
        conn.execute(
            "INSERT OR REPLACE INTO RoutesTable (RouteID, Origin, Dest, MedianDuration, Reliability, Timestamp) "
            "VALUES (?,?,?,?,?,?)",
            (key, origin, dest, median, reliability, datetime.datetime.utcnow().isoformat()),
        )
        conn.commit()
        conn.close()

    def _fetch_from_api(self, origin: str, dest: str):
        import requests, json
        url = f"https://airlabs.co/api/v9/schedules?api_key={self.api_key}&dep_iata={origin}&arr_iata={dest}"
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        # AirLabs returns a list under 'response' key
        flights = data.get("response", [])
        if not flights:
            raise ValueError(f"No routes found for {origin}->{dest}")
        return flights

    def _process_flights(self, flights: list):
        # Extract duration in minutes (AirLabs provides 'duration' in minutes)
        durations = []
        active = 0
        for f in flights:
            dur = f.get("duration")  # minutes
            if dur is None:
                continue
            durations.append(dur / 60.0)  # convert to hours
            if f.get("status", "scheduled").lower() != "cancelled":
                active += 1
        if not durations:
            raise ValueError("No valid duration data in API response")
        # Median to ignore outliers
        import statistics
        median = statistics.median(durations)
        reliability = (active / len(durations)) * 100.0
        return median, reliability

    def get_route_metrics(self, origin: str, dest: str, force_refresh: bool = False):
        key = f"{origin}_{dest}"
        if not force_refresh:
            cached = self._get_cached(key)
            if cached:
                return cached  # (median, reliability)
        # Cache miss or forced refresh → fetch from API
        flights = self._fetch_from_api(origin, dest)
        median, reliability = self._process_flights(flights)
        self._store(key, origin, dest, median, reliability)
        return median, reliability
```
### 3. Updating `AviationEdgeClient`
Replace the placeholder method with a thin wrapper that calls the resolver:
```python
class AviationEdgeClient:
    def __init__(self, api_key: str, cache_resolver: Optional[AirLabsCacheResolver] = None):
        self.api_key = api_key
        self.cache = cache_resolver or AirLabsCacheResolver(api_key)

    def get_transit_time_hours(self, origin_iata: str, dest_iata: str) -> float:
        # Only the flight duration is required; ground‑side delays are elsewhere.
        median, _ = self.cache.get_route_metrics(origin_iata, dest_iata)
        return median
```
*   The `reliability` value is currently unused by the simulation but is stored for future risk‑adjusted calculations.
*   If the caller wishes to bypass the cache (e.g., for a tight deadline), they can instantiate the client with `cache_resolver.get_route_metrics(..., force_refresh=True)` – we will expose a helper method on the client if needed.

### 4. Integration Points
- **Where the client is created**: In the simulation setup (likely in `run_simulation_with_risk` or similar), replace the existing `AviationEdgeClient(api_key, simulation_start)` call with:
```python
air_cache = AirLabsCacheResolver(api_key=YOUR_AIRLABS_KEY)
air_client = AviationEdgeClient(api_key=YOUR_AIRLABS_KEY, cache_resolver=air_cache)
```
- **Dependency**: Add `requests` to `requirements.txt` if not already present.
- **Testing**: Write a quick unit test that mocks the AirLabs response and verifies median calculation and cache storage.

## Open Questions (User Review Required)
> [!IMPORTANT]
> 1. **Cache Persistence Preference** – Do you prefer SQLite (as drafted) or a simple JSON file? SQLite offers atomic writes and easy queries, but JSON is human‑readable.
> 2. **TTL Enforcement** – Should the resolver automatically purge stale rows, or is the 90‑day check sufficient?
> 3. **Error Handling** – If the AirLabs API fails (network error, rate‑limit), should we fall back to the existing static 8 h placeholder, raise an exception, or retry a limited number of times?
> 4. **Reliability Usage** – Do you want the reliability percentage to affect any downstream risk model now, or just store it for future use?

## Verification Plan
- **Unit Tests**: Mock `requests.get` to return a deterministic flight list; assert that `get_route_metrics` returns the correct median and reliability and that the cache file is populated.
- **Integration Test**: Run a short simulation with a known origin/destination pair; confirm that `AirLink.traverse` receives a realistic duration (e.g., 2‑3 h) instead of the placeholder.
- **Manual Check**: Print a log line when a cache hit occurs vs. a fresh API fetch, so you can verify caching behavior during a run.

---

*Please review the open questions above and confirm the design choices (SQLite vs JSON, error‑fallback strategy, etc.) so we can proceed with the implementation.*
