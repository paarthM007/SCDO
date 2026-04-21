FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# Write Firebase credentials from env var to file at runtime
RUN printf '#!/bin/bash\n\
if [ -n "$GOOGLE_APPLICATION_CREDENTIALS_JSON" ]; then\n\
  echo "$GOOGLE_APPLICATION_CREDENTIALS_JSON" > /app/firebase-key.json\n\
  export GOOGLE_APPLICATION_CREDENTIALS=/app/firebase-key.json\n\
fi\n\
exec python gateway.py\n' > /app/start.sh && chmod +x /app/start.sh

EXPOSE 7860
CMD ["/app/start.sh"]
