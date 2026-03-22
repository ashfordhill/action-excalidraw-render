FROM node:20-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY src/package*.json ./

RUN npm ci --only=production

COPY src/ ./

RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
