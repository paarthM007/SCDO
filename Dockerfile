FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# Set PYTHONPATH so the scdo package is discoverable
ENV PYTHONPATH=/app
# Default Port
EXPOSE 7860

CMD ["python", "gateway.py"]
