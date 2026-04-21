"""
gemini.py - Google Gemini AI risk evaluator.
Gracefully degrades if google-genai is not installed.
"""
import json
import logging

logger = logging.getLogger(__name__)

try:
    from google import genai
    HAS_GENAI = True
except ImportError:
    HAS_GENAI = False
    logger.warning("google-genai not installed — Gemini risk scoring disabled")

from scdo.config import GEMINI_API_KEY


class GeminiClient:
    def __init__(self, api_key=GEMINI_API_KEY):
        self.api_key = api_key
        self.client = None
        if HAS_GENAI and api_key:
            try:
                self.client = genai.Client(api_key=api_key)
            except Exception as e:
                logger.warning("Gemini client init failed: %s", e)

    def evaluate_risks(self, city_headlines):
        if not self.client:
            return {city: {"risk_score": 0.05, "primary_hazard": "None (Gemini unavailable)"}
                    for city in city_headlines}

        prompt = self._build_prompt(city_headlines)
        try:
            response = self.client.models.generate_content(
                model="gemini-2.0-flash",
                contents=prompt,
                config=genai.types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                    max_output_tokens=8192
                )
            )
            return json.loads(response.text)
        except Exception as e:
            logger.error("Gemini evaluation failed: %s", e)
            return {city: {"risk_score": 0.05, "primary_hazard": "Analysis Failed"}
                    for city in city_headlines}

    def _build_prompt(self, city_headlines):
        lines = [
            "Evaluate supply-chain disruption risk for these cities based on headlines.",
            "Score 0.0 (safe) to 1.0 (catastrophic).",
            'Return JSON: {"City": {"risk_score": float, "primary_hazard": string}}',
            "\nHeadlines:"
        ]
        for city, hl in city_headlines.items():
            lines.append(f"### {city}\n" + "\n".join(hl[:10]))
        return "\n".join(lines)
