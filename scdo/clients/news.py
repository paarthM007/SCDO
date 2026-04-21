import requests
from typing import List
from scdo.config import NEWS_API_KEY

class NewsClient:
    """
    Fetches supply-chain related headlines from NewsAPI and Reddit.
    """
    def __init__(self, news_api_key: str = NEWS_API_KEY):
        self.news_api_key = news_api_key

    def fetch_headlines(self, city_name: str, country_name: str) -> List[str]:
        headlines = []
        headlines.extend(self._fetch_newsapi(city_name, country_name))
        headlines.extend(self._fetch_reddit(city_name, country_name))
        return headlines

    def _fetch_newsapi(self, city_name: str, country_name: str) -> List[str]:
        if not self.news_api_key: return []
        try:
            place_query = f'("{city_name}" OR "{country_name}")' if country_name else f'"{city_name}"'
            q = f"{place_query} AND (\"supply chain\" OR strike OR disruption OR shortage OR embargo OR blockade OR \"port closed\" OR tariff OR hurricane OR earthquake OR flood OR war OR sanctions)"
            resp = requests.get("https://newsapi.org/v2/everything", params={
                "q": q, "language": "en", "sortBy": "publishedAt", "pageSize": 50, "apiKey": self.news_api_key
            }, timeout=10)
            return [art.get("title") for art in resp.json().get("articles", []) if art.get("title") and art.get("title") != "[Removed]"]
        except:
            return []

    def _fetch_reddit(self, city_name: str, country_name: str) -> List[str]:
        try:
            q = f"({city_name} OR {country_name}) AND (supply chain OR disruption OR shortage OR strike OR embargo OR war OR sanctions OR flood OR earthquake)"
            resp = requests.get("https://www.reddit.com/search.json", params={
                "q": q, "sort": "new", "limit": 25, "t": "week"
            }, headers={"User-Agent": "SCDO-Bot/2.0"}, timeout=10)
            return [post.get("data", {}).get("title", "") for post in resp.json().get("data", {}).get("children", [])]
        except:
            return []
