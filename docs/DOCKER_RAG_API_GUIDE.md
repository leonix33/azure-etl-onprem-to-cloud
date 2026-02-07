# Docker RAG API Guide

## Overview

This runs the RAG API and Redis locally using Docker Compose.

## Setup

Create a `.env` file (or export env vars) with:

```
SEARCH_ENDPOINT=
SEARCH_ADMIN_KEY=
OPENAI_ENDPOINT=
OPENAI_KEY=
OPENAI_DEPLOYMENT=gpt-4o-mini
OPENAI_EMBEDDING_DEPLOYMENT=text-embedding-3-small
RAG_API_KEY=
JWT_SECRET=
JWT_ISSUER=
JWT_AUDIENCE=
RAG_RATE_LIMIT_PER_MIN=120
```

## Run

```
docker compose up --build
```

## Test

```
curl -X POST http://localhost:8080/ask \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: your-strong-key" \
  -H "Authorization: Bearer <jwt>" \
  -d '{"question":"What data sources are ingested?"}'
```

## Stop

```
docker compose down
```
