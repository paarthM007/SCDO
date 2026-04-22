# SCDO Frontend Integration Guide

## Architecture Overview
The Flutter frontend communicates with the Python backend via:
1. **Firestore** — for async simulation jobs (Functionality 1)
2. **HTTP API** — for sync route finding (Functionality 2)

## Functionality 1: Route Cost & Delay Simulation

### Flow: Flutter → Firestore → Worker → Firestore → Flutter

**Step 1: Submit a job**
```dart
final docRef = await FirebaseFirestore.instance.collection('sim_jobs').add({
  'status': 'pending',
  'type': 'simulation',
  'cities': ['Mumbai', 'Delhi', 'Dubai'],
  'modes': ['Road', 'Ship'],
  'cargo_type': 'frozen_food',
  'n_iterations': 50,
  'created_at': FieldValue.serverTimestamp(),
});
String jobId = docRef.id;
```

**Step 2: Listen for result**
```dart
FirebaseFirestore.instance.collection('sim_jobs').doc(jobId)
  .snapshots()
  .listen((snapshot) {
    final data = snapshot.data()!;
    if (data['status'] == 'completed') {
      final result = data['result'];
      // result['simulation_stats']['time']['mean'] → avg lead time (hours)
      // result['simulation_stats']['cost']['mean'] → avg cost ($)
      // result['combined_risk']['score'] → 0.0-1.0 risk score
      // result['combined_risk']['level'] → "LOW"/"MODERATE"/"HIGH"/...
    } else if (data['status'] == 'failed') {
      print('Error: ${data["error"]}');
    }
  });
```

### Result Schema
```json
{
  "job_meta": {
    "cities": ["Mumbai", "Delhi", "Dubai"],
    "modes": ["Road", "Ship"],
    "cargo_type": "frozen_food",
    "n_iterations": 50,
    "timestamp": "2026-04-21T17:00:00Z"
  },
  "combined_risk": {
    "score": 0.32,
    "level": "MODERATE",
    "route_viable": true,
    "recommendation": "Route has moderate risk. Monitor conditions."
  },
  "simulation_stats": {
    "iterations": 50,
    "time": {
      "mean": 245.3, "std": 42.1,
      "p5": 180.2, "p50": 240.1, "p95": 320.5,
      "min": 165.0, "max": 380.2
    },
    "cost": {
      "mean": 4520.50, "std": 890.20,
      "p5": 3200.00, "p50": 4400.00, "p95": 6100.00
    }
  }
}
```

## Functionality 2: Alternate Route Finding

### Flow: Flutter → HTTP POST → Gateway → Response

**API Call:**
```dart
final response = await http.post(
  Uri.parse('https://YOUR-HF-SPACE.hf.space/api/alternate-route'),
  headers: {
    'Content-Type': 'application/json',
    'X-API-Key': 'YOUR_GATEWAY_API_KEY',
  },
  body: jsonEncode({
    'start': 'Mumbai',
    'end': 'Rotterdam',
    'blocked': ['Suez Canal', 'Cairo', 'Port Said'],
    'cargo_type': 'electronics',
  }),
);
final data = jsonDecode(response.body);
// data['result']['fastest'] → fastest route avoiding blocked nodes
// data['result']['cheapest'] → cheapest alternate
// data['result']['balanced'] → balanced alternate
```

### Response Schema
```json
{
  "status": "ok",
  "result": {
    "origin": "Mumbai",
    "destination": "Rotterdam",
    "blocked_nodes": ["Cairo", "Port Said"],
    "fastest": {
      "total_distance_km": 12500.3,
      "total_time_h": 340.5,
      "total_time_readable": "14d 4h 30m",
      "total_cost_usd": 2450.00,
      "modes_used": ["HIGHWAY", "SEA"],
      "waypoints": [
        {"name": "Mumbai", "lat": 19.07, "lon": 72.87},
        {"name": "Colombo", "lat": 6.93, "lon": 79.84, "mode": "SEA"}
      ],
      "segments": [
        {"mode": "HIGHWAY", "from": "Mumbai", "to": "Port X", "time_readable": "8h 30m"},
        {"mode": "SEA", "from": "Port X", "to": "Rotterdam", "time_readable": "13d 20h 0m"}
      ]
    },
    "cheapest": { ... },
    "balanced": { ... }
  }
}
```

## Other Useful Endpoints

### GET /api/cities?q=mum
Search/autocomplete for city names. No auth required for this one.

### GET /api/route?from=Mumbai&to=Rotterdam&mode=BEST
Simple point-to-point routing (no blocked nodes). Requires X-API-Key.

### GET /health
Service liveness check.

## Environment Setup
1. Store `GATEWAY_API_KEY` in your Flutter `.env` file
2. Use the `flutter_dotenv` package to load it
3. HuggingFace Space URL format: `https://YOUR-USERNAME-YOUR-SPACE.hf.space`

## Cargo Types
Valid values for `cargo_type`:
- `general`, `frozen_food`, `perishable`, `live_animals`
- `pharmaceuticals`, `electronics`, `bulk_commodity`
- `hazmat`, `vehicles`
