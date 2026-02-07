# RAG UI Guide

## Purpose

This UI provides a simple web form for asking questions against your indexed documents with citations.

## How it works

1. User submits a question
2. UI calls Azure OpenAI embeddings
3. Vector search retrieves top chunks from Azure AI Search
4. Azure OpenAI generates an answer using retrieved context
5. UI renders answer + citations

## Setup

```bash
export SEARCH_ENDPOINT="$(cd terraform && terraform output -raw search_service_endpoint)"
export SEARCH_ADMIN_KEY="$(az keyvault secret show --vault-name $(cd terraform && terraform output -raw key_vault_name) --name ai-search-admin-key --query value -o tsv)"
export OPENAI_ENDPOINT="$(cd terraform && terraform output -raw openai_endpoint)"
export OPENAI_KEY="$(az keyvault secret show --vault-name $(cd terraform && terraform output -raw key_vault_name) --name openai-api-key --query value -o tsv)"
export OPENAI_DEPLOYMENT="gpt-4o-mini"
export OPENAI_EMBEDDING_DEPLOYMENT="text-embedding-3-small"

./scripts/run-rag-ui.sh
```

Open: http://localhost:8000
