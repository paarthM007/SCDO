import requests
from typing import List
from scdo.config import NEWS_API_KEY

import requests
from datetime import datetime, timedelta
from typing import List

class NewsClient:
    """
    Fetches supply-chain related intelligence from NewsAPI and Reddit.
    """
    def __init__(self, news_api_key: str = NEWS_API_KEY):
        self.news_api_key = news_api_key

    def fetch_source_briefs(self, city_name: str, country_name: str) -> dict:
        """Returns isolated intelligence blocks for weighted LLM analysis."""
        news_lines = self._fetch_newsapi(city_name, country_name)
        reddit_lines = self._fetch_reddit(city_name, country_name)
        
        return {
            "news": "\n".join(news_lines[:20]) if news_lines else "No significant news reported.",
            "reddit": "\n".join(reddit_lines[:10]) if reddit_lines else "No significant chatter reported."
        }

    def _fetch_newsapi(self, city_name: str, country_name: str) -> List[str]:
        if not self.news_api_key: return []
        try:
            place_query = f'("{city_name}" OR "{country_name}")' if country_name else f'"{city_name}"'
            q = f"{place_query} AND (\"supply chain\" OR strike OR disruption OR shortage OR embargo OR blockade OR \"port closed\" OR tariff OR hurricane OR earthquake OR flood OR war OR sanctions)"
            
            # CHAT 4 FIX: Enforce the 3-day intelligence window
            from_date = (datetime.now() - timedelta(days=3)).strftime('%Y-%m-%d')
            
            resp = requests.get("https://newsapi.org/v2/everything", params={
                "q": q, "from": from_date, "language": "en", "sortBy": "relevancy", "pageSize": 50, "apiKey": self.news_api_key
            }, timeout=10)
            
            articles = []
            for art in resp.json().get("articles", []):
                title = art.get("title")
                # CHAT 2 FIX: Grab descriptions for rich context
                desc = art.get("description") or "No further description."
                source = art.get("source", {}).get("name", "News")
                
                if title and title != "[Removed]":
                    articles.append(f"- [{source}] {title}: {desc}")
            return articles
        except Exception as e:
            return []

    def _fetch_reddit(self, city_name: str, country_name: str) -> List[str]:
        try:
            q = f"({city_name} OR {country_name}) AND (supply chain OR disruption OR shortage OR strike OR embargo OR war OR sanctions OR flood OR earthquake)"
            resp = requests.get("https://www.reddit.com/search.json", params={
                "q": q, "sort": "new", "limit": 25, "t": "week"
            }, headers={"User-Agent": "SCDO-Bot/2.0"}, timeout=10)
            
            posts = []
            for post in resp.json().get("data", {}).get("children", []):
                data = post.get("data", {})
                title = data.get("title", "")
                snippet = data.get("selftext", "")[:150]
                if title:
                    posts.append(f"- [Reddit] {title}: {snippet}...")
            return posts
        except Exception as e:
            return []