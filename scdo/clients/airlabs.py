import requests
import statistics
from datetime import datetime, timezone, timedelta

from scdo.db import get_db
from scdo.config import AIRLABS_API_KEY, GOOGLE_CLOUD_PROJECT, FIRESTORE_CACHE_COLLECTION, AIRLABS_CACHE_TTL_DAYS

class AirLabsClient:
    """
    Resolves air route metrics using AirLabs API with Firestore caching.
    """
    _AIRLABS_SCHEDULES_URL = "https://airlabs.co/api/v9/schedules"

    def __init__(self, api_key: str = AIRLABS_API_KEY):
        self.api_key = api_key
        self.db = get_db()

    def get_route_metrics(self, origin: str, dest: str, force_refresh: bool = False) -> tuple:
        route_id = f"{origin}_{dest}"
        doc_ref = self.db.collection(FIRESTORE_CACHE_COLLECTION).document(route_id)

        if not force_refresh:
            doc = doc_ref.get()
            if doc.exists:
                data = doc.to_dict()
                cached_at = datetime.fromisoformat(data['cached_at'])
                if datetime.now(timezone.utc) - cached_at < timedelta(days=AIRLABS_CACHE_TTL_DAYS):
                    return data['median_duration_h'], data['reliability_pct']

        # Cache miss or forced refresh
        flights = self._fetch_from_api(origin, dest)
        median_h, reliability = self._process_flights(flights)

        # Update cache
        doc_ref.set({
            "route_id": route_id,
            "origin": origin,
            "destination": dest,
            "median_duration_h": median_h,
            "reliability_pct": reliability,
            "cached_at": datetime.now(timezone.utc).isoformat()
        })

        return median_h, reliability

    def _fetch_from_api(self, origin: str, dest: str) -> list:
        params = {
            "api_key": self.api_key,
            "dep_iata": origin,
            "arr_iata": dest,
        }
        resp = requests.get(self._AIRLABS_SCHEDULES_URL, params=params, timeout=10)
        resp.raise_for_status()
        return resp.json().get("response", [])

    def _process_flights(self, flights: list) -> tuple:
        durations_h = []
        active_count = 0

        for flight in flights:
            dur_min = flight.get("duration")
            if dur_min is None: continue
            durations_h.append(dur_min / 60.0)
            if str(flight.get("status", "scheduled")).lower() != "cancelled":
                active_count += 1

        if not durations_h:
            return 8.0, 100.0 # Default fallback

        median_h = statistics.median(durations_h)
        reliability = (active_count / len(durations_h)) * 100.0
        return median_h, reliability
