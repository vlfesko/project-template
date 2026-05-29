FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
EXPOSE 8000
CMD ["python3", "-m", "http.server", "8000"]
