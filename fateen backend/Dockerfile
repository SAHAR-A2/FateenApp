FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

# Cloud Run (and Firebase Hosting in front of it) terminate the connection,
# so the socket peer is Google's proxy for every user. --proxy-headers makes
# request.client the X-Forwarded-For client instead; otherwise the per-IP
# rate limiter in app.main puts all users into one shared bucket.
CMD ["sh", "-c", "uvicorn app.public_gateway:app --host 0.0.0.0 --port ${PORT:-8080} --lifespan off --proxy-headers --forwarded-allow-ips='*'"]
