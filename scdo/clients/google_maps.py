import googlemaps
from datetime import timedelta
from functools import lru_cache
from scdo.config import GOOGLE_MAPS_API_KEY

class GoogleMapsClient:
    """
    Wraps the Google Maps Distance Matrix API for road transit times.
    """
    def __init__(self, api_key: str = GOOGLE_MAPS_API_KEY):
        self.client = googlemaps.Client(key=api_key)

    def get_travel_time_hours(self, origin: str, destination: str, simulation_start_dt, current_sim_hours: float) -> float:
        """
        Queries Google Maps for road travel duration_in_traffic.
        """
        # Round to nearest hour for cache bucket
        hour_bucket = round(current_sim_hours)
        departure_dt = simulation_start_dt + timedelta(hours=hour_bucket)
        return self._cached_query(origin, destination, departure_dt)

    @lru_cache(maxsize=512)
    def _cached_query(self, origin: str, destination: str, departure_dt) -> float:
        result = self.client.distance_matrix(
            origins=[origin],
            destinations=[destination],
            mode="driving",
            departure_time=departure_dt
        )

        element = result['rows'][0]['elements'][0]
        if element['status'] != 'OK':
            raise ValueError(f"Google Maps API error for {origin} -> {destination}: {element['status']}")

        if 'duration_in_traffic' in element:
            seconds = element['duration_in_traffic']['value']
        else:
            seconds = element['duration']['value']

        return seconds / 3600.0
