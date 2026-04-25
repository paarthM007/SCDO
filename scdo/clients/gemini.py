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
            logger.warning("Gemini client not initialized (missing API key or google-genai package)")
            return {city: {"risk_score": 0.05, "primary_hazard": "None (Gemini unavailable)"}
                    for city in city_headlines}

        prompt = self._build_prompt(city_headlines)
        
        def _call_gemini(model_id):
            return self.client.models.generate_content(
                model=model_id,
                contents=prompt,
                config=genai.types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                    max_output_tokens=2048
                )
            )

        try:
            # Try models in order of preference
            models_to_try = ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-flash-8b"]
            response = None
            last_error = None

            for model_id in models_to_try:
                try:
                    response = _call_gemini(model_id)
                    if response and response.text:
                        break # Success!
                except Exception as e:
                    last_error = str(e)
                    # If it's a quota error, log it and try next
                    if "429" in last_error or "RESOURCE_EXHAUSTED" in last_error:
                        logger.warning(f"Gemini {model_id} quota exhausted. Trying next model...")
                    elif "404" in last_error or "NOT_FOUND" in last_error:
                        logger.warning(f"Gemini {model_id} not found. Trying next model...")
                    else:
                        # For other errors, maybe it's a prompt issue, but let's try next anyway
                        logger.warning(f"Gemini {model_id} failed: {last_error}. Trying next model...")
            
            if not response or not response.text:
                raise ValueError(f"All Gemini models failed. Last error: {last_error}")
            
            return json.loads(response.text)
        except Exception as e:
            error_msg = str(e)
            if "API key not valid" in error_msg:
                logger.error("Gemini API Key is INVALID. Please check your .env file.")
            elif "429" in error_msg or "RESOURCE_EXHAUSTED" in error_msg:
                logger.error("Gemini Quota Exhausted on all models.")
            else:
                logger.error("Gemini evaluation failed after multiple attempts: %s", error_msg)
            
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
