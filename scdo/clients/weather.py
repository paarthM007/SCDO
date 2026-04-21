import requests
import time
from collections import OrderedDict
from scdo.config import OWM_API_KEY, WEATHER_CACHE_TTL_SECONDS

class WeatherClient:
    """
    Fetches weather forecasts from OpenWeatherMap with in-memory caching.
    """
    def __init__(self, api_key: str = OWM_API_KEY):
        self.api_key = api_key
        self._cache = OrderedDict()
        self._max_cache = 500

    def get_forecast(self, city_name: str):
        key = city_name.lower()
        if key in self._cache:
            data, ts = self._cache[key]
            if time.time() - ts < WEATHER_CACHE_TTL_SECONDS:
                return data
            del self._cache[key]

        try:
            # Geocoding
            geo_url = f"http://api.openweathermap.org/geo/1.0/direct?q={city_name}&limit=1&appid={self.api_key}"
            geo_data = requests.get(geo_url, timeout=5).json()
            if not geo_data: return None

            lat, lon = geo_data[0]['lat'], geo_data[0]['lon']
            # Forecast
            fc_url = f"https://api.openweathermap.org/data/2.5/forecast?lat={lat}&lon={lon}&appid={self.api_key}&units=metric"
            fc_data = requests.get(fc_url, timeout=5).json()

            # Set cache
            self._cache[key] = (fc_data, time.time())
            if len(self._cache) > self._max_cache:
                self._cache.popitem(last=False)
            return fc_data
        except Exception:
            return None
