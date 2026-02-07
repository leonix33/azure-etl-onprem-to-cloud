# RAG API Guide (Production-Ready)

## What this adds

- **Auth**: API key via `X-API-KEY` header
- **Auth (JWT)**: Bearer tokens (HS256)
- **Rate limiting**: Redis-backed per‑minute rate limits (fallback to in‑memory)
- **Logging**: request/response timing

## Start API

```bash
export RAG_API_KEY="your-strong-key"
export JWT_SECRET="your-jwt-secret"
export JWT_ISSUER="your-issuer"   # optional
export JWT_AUDIENCE="your-audience" # optional
export REDIS_URL="redis://localhost:6379/0"
export RAG_RATE_LIMIT_PER_MIN="120"
export SEARCH_ENDPOINT="$(cd terraform && terraform output -raw search_service_endpoint)"
export SEARCH_ADMIN_KEY="$(az keyvault secret show --vault-name $(cd terraform && terraform output -raw key_vault_name) --name ai-search-admin-key --query value -o tsv)"
export OPENAI_ENDPOINT="$(cd terraform && terraform output -raw openai_endpoint)"
export OPENAI_KEY="$(az keyvault secret show --vault-name $(cd terraform && terraform output -raw key_vault_name) --name openai-api-key --query value -o tsv)"
export OPENAI_DEPLOYMENT="gpt-4o-mini"
export OPENAI_EMBEDDING_DEPLOYMENT="text-embedding-3-small"

./scripts/run-rag-api.sh
```

## Call API

```bash
curl -X POST http://localhost:8080/ask \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: your-strong-key" \
  -H "Authorization: Bearer <jwt>" \
  -d '{"question":"What data sources are ingested?"}'
```

## Notes

- For production hosting, run behind a reverse proxy and store secrets in Key Vault.
- Replace in‑memory limiter with Redis for multi‑instance deployments.
