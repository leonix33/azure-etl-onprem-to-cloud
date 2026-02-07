# Azure AI Search + OpenAI RAG Guide

## Overview

This adds a Retrieval‑Augmented Generation (RAG) layer to the Azure ETL project:
1. Index documents in ADLS Gen2 using Azure AI Search
2. Retrieve relevant chunks for a user query
3. Send the retrieved context to Azure OpenAI for Q&A

## What gets created

Terraform adds:
- **Azure AI Search** (for indexing and retrieval)
- **Azure OpenAI** (for LLM inference)
- **Key Vault secrets** for AI Search and OpenAI keys

## Deploy Infrastructure

```bash
cd /Users/user/Desktop/Development/azure-etl-project
./scripts/deploy.sh
```

## Configure AI Search Indexing

```bash
./scripts/setup-ai-search-rag.sh
```

This creates:
- Data source (ADLS processed-data container)
- Search index
- Skillset (text extraction + Azure OpenAI embeddings)
- Indexer (scheduled every hour)

## Vector Embeddings + Semantic Ranking

The setup uses:
- **Azure OpenAI Embeddings** to create `contentVector`
- **HNSW** vector search in Azure AI Search
- **Semantic configuration** for better ranking

## Chunking Strategy

Documents are split into ~2000‑character chunks with 200 overlap. This improves retrieval precision and avoids oversized context.

## Citations

`rag-query.py` prints citations (file name + path) so users can trace answers back to source documents.

## Filters

Set `SEARCH_FILTER` to restrict results by path or metadata:

```bash
export SEARCH_FILTER="startswith(metadata_storage_path, 'processed-data/hr/')"
```

Make sure you have an embeddings deployment:
- Example deployment name: `text-embedding-3-small`

## Deploy OpenAI Model

In Azure OpenAI Studio:
- Deploy a chat model (example: `gpt-4o-mini`)
- Note the deployment name

## Run RAG Query

```bash
export SEARCH_ENDPOINT="$(cd terraform && terraform output -raw search_service_endpoint)"
export SEARCH_ADMIN_KEY="$(az keyvault secret show --vault-name $(cd terraform && terraform output -raw key_vault_name) --name ai-search-admin-key --query value -o tsv)"
export OPENAI_ENDPOINT="$(cd terraform && terraform output -raw openai_endpoint)"
export OPENAI_KEY="$(az keyvault secret show --vault-name $(cd terraform && terraform output -raw key_vault_name) --name openai-api-key --query value -o tsv)"
export OPENAI_DEPLOYMENT="gpt-4o-mini"
export OPENAI_EMBEDDING_DEPLOYMENT="text-embedding-3-small"

python3 scripts/rag-query.py
```

## Notes

- Ensure the `processed-data` container contains text/CSV/PDF documents.
- For large files, consider adding chunking and vector embeddings later.
