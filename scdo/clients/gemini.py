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
            models_to_try = [
                "gemini-1.5-flash", 
                "gemini-1.5-pro",
                "gemini-1.0-pro",
            ]
            response = None
            last_error = None

            for model_id in models_to_try:
                try:
                    response = _call_gemini(model_id)
                    if response and response.text:
                        # Attempt to parse to ensure it's valid JSON before breaking
                        try:
                            data = json.loads(response.text)
                            return data
                        except json.JSONDecodeError:
                            logger.warning(f"Gemini {model_id} returned invalid JSON. Trying next...")
                            continue
                except Exception as e:
                    last_error = str(e)
                    # If it's a quota error, log it and try next
                    if "429" in last_error or "RESOURCE_EXHAUSTED" in last_error:
                        logger.warning(f"Gemini {model_id} quota exhausted. Trying next model...")
                    elif "404" in last_error or "NOT_FOUND" in last_error:
                        logger.warning(f"Gemini {model_id} not found. Trying next model...")
                    else:
                        logger.warning(f"Gemini {model_id} failed: {last_error}. Trying next model...")
            
            raise ValueError(f"All Gemini models failed or returned invalid data. Last error: {last_error}")
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

    def _build_prompt(self, batch_intelligence):
        lines = [
            "You are a supply-chain risk intelligence analyst. Evaluate the disruption risk for these specific locations based on the provided intelligence sources.",
            "Based *only* on the provided intelligence briefs, classify the risk level as LOW, MEDIUM, or HIGH.",
            "- LOW: No significant events reported. Standard operations.",
            "- MEDIUM: Reports of delays, minor disruptions, or isolated incidents that could slow transit.",
            "- HIGH: Reports of major conflict, port closures, severe weather, or widespread unrest making transit dangerous.",
            "",
            "You MUST return a JSON object where the keys are the exact source IDs provided (e.g., 'mumbai_news', 'tehran_reddit').",
            "Use this exact schema for the values:",
            '{',
            '  "SOURCE_ID": {',
            '    "risk_score": "LOW|MEDIUM|HIGH",',
            '    "primary_hazard": "Short description of the main threat, or \'None\'",',
            '    "reasoning": "You MUST justify your score by citing specific evidence from the brief. This is required to prevent bias." ',
            '  }',
            '}',
            "\nINTELLIGENCE BRIEFS:"
        ]
        
        # Iterate over the dictionary we passed from sentiment_risk.py
        for source_id, brief_text in batch_intelligence.items():
            lines.append(f"\n### {source_id}")
            # brief_text is already a formatted string, so we just append it directly!
            lines.append(brief_text)
            
        return "\n".join(lines)
