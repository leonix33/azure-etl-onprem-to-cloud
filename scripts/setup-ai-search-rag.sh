#!/bin/bash

###############################################################################
# Azure AI Search + OpenAI RAG Setup
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${PROJECT_ROOT}/terraform"

INDEX_NAME="etl-docs-index"
DATASOURCE_NAME="etl-blob-ds"
SKILLSET_NAME="etl-skillset"
INDEXER_NAME="etl-indexer"

if ! command -v az &> /dev/null; then
  log_error "Azure CLI not found. Install az first."
  exit 1
fi

if [ ! -d "$TF_DIR" ]; then
  log_error "Terraform folder not found at $TF_DIR"
  exit 1
fi

pushd "$TF_DIR" >/dev/null
SEARCH_SERVICE_NAME=$(terraform output -raw search_service_name)
SEARCH_ENDPOINT=$(terraform output -raw search_service_endpoint)
OPENAI_ENDPOINT=$(terraform output -raw openai_endpoint)
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
KV_NAME=$(terraform output -raw key_vault_name)
popd >/dev/null

SEARCH_ADMIN_KEY=$(az keyvault secret show --vault-name "$KV_NAME" --name ai-search-admin-key --query value -o tsv)
OPENAI_KEY=$(az keyvault secret show --vault-name "$KV_NAME" --name openai-api-key --query value -o tsv)

OPENAI_EMBEDDING_DEPLOYMENT=${OPENAI_EMBEDDING_DEPLOYMENT:-"text-embedding-3-small"}

if [ -z "$SEARCH_ADMIN_KEY" ] || [ -z "$OPENAI_KEY" ]; then
  log_error "Missing AI Search/OpenAI keys in Key Vault."
  exit 1
fi

log_info "Creating data source (ADLS Gen2 container: processed-data)..."
cat > /tmp/ai-search-datasource.json <<EOF
{
  "name": "${DATASOURCE_NAME}",
  "type": "azureblob",
  "credentials": {
    "connectionString": "$(az keyvault secret show --vault-name "$KV_NAME" --name storage-connection-string --query value -o tsv)"
  },
  "container": { "name": "processed-data" },
  "description": "ADLS Gen2 processed-data container"
}
EOF

az rest --method put \
  --url "${SEARCH_ENDPOINT}/datasources/${DATASOURCE_NAME}?api-version=2023-11-01" \
  --headers "api-key=${SEARCH_ADMIN_KEY}" "Content-Type=application/json" \
  --body @/tmp/ai-search-datasource.json >/dev/null

log_info "Creating index..."
cat > /tmp/ai-search-index.json <<EOF
{
  "name": "${INDEX_NAME}",
  "fields": [
    {"name": "id", "type": "Edm.String", "key": true, "filterable": true},
    {"name": "content", "type": "Edm.String", "searchable": true},
    {"name": "contentVector", "type": "Collection(Edm.Single)", "searchable": true, "dimensions": 1536, "vectorSearchProfile": "vector-profile"},
    {"name": "metadata_storage_name", "type": "Edm.String", "filterable": true, "sortable": true},
    {"name": "metadata_storage_path", "type": "Edm.String", "filterable": true, "sortable": true},
    {"name": "lastModified", "type": "Edm.DateTimeOffset", "filterable": true, "sortable": true}
  ],
  "vectorSearch": {
    "algorithms": [
      {
        "name": "hnsw",
        "kind": "hnsw"
      }
    ],
    "profiles": [
      {
        "name": "vector-profile",
        "algorithm": "hnsw"
      }
    ]
  },
  "semantic": {
    "configurations": [
      {
        "name": "default",
        "prioritizedFields": {
          "contentFields": [{"fieldName": "content"}],
          "titleField": {"fieldName": "metadata_storage_name"}
        }
      }
    ]
  }
}
EOF

az rest --method put \
  --url "${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}?api-version=2023-11-01" \
  --headers "api-key=${SEARCH_ADMIN_KEY}" "Content-Type=application/json" \
  --body @/tmp/ai-search-index.json >/dev/null

log_info "Creating skillset (basic text extraction)..."
cat > /tmp/ai-search-skillset.json <<EOF
{
  "name": "${SKILLSET_NAME}",
  "description": "Extract, split, and embed text for RAG",
  "skills": [
    {
      "@odata.type": "#Microsoft.Skills.Text.SplitSkill",
      "name": "splitText",
      "context": "/document",
      "textSplitMode": "pages",
      "maximumPageLength": 2000,
      "pageOverlapLength": 200,
      "inputs": [
        {"name": "text", "source": "/document/content"}
      ],
      "outputs": [
        {"name": "textItems", "targetName": "chunks"}
      ]
    },
    {
      "@odata.type": "#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill",
      "name": "aoaiEmbedding",
      "context": "/document/chunks/*",
      "resourceUri": "${OPENAI_ENDPOINT}",
      "apiKey": "${OPENAI_KEY}",
      "deploymentId": "${OPENAI_EMBEDDING_DEPLOYMENT}",
      "inputs": [
        {"name": "text", "source": "/document/chunks/*"}
      ],
      "outputs": [
        {"name": "embedding", "targetName": "contentVector"}
      ]
    },
    {
      "@odata.type": "#Microsoft.Skills.Text.MergeSkill",
      "name": "mergeText",
      "inputs": [{"name": "text", "source": "/document/chunks/*"}],
      "outputs": [
        {"name": "mergedText", "targetName": "content"}
      ]
    }
  ]
}
EOF

az rest --method put \
  --url "${SEARCH_ENDPOINT}/skillsets/${SKILLSET_NAME}?api-version=2023-11-01" \
  --headers "api-key=${SEARCH_ADMIN_KEY}" "Content-Type=application/json" \
  --body @/tmp/ai-search-skillset.json >/dev/null

log_info "Creating indexer..."
cat > /tmp/ai-search-indexer.json <<EOF
{
  "name": "${INDEXER_NAME}",
  "dataSourceName": "${DATASOURCE_NAME}",
  "targetIndexName": "${INDEX_NAME}",
  "skillsetName": "${SKILLSET_NAME}",
  "schedule": {"interval": "PT1H"},
  "fieldMappings": [
    {"sourceFieldName": "metadata_storage_path", "targetFieldName": "id"}
  ],
  "outputFieldMappings": [
    {"sourceFieldName": "/document/chunks/*", "targetFieldName": "content"},
    {"sourceFieldName": "/document/chunks/*/contentVector", "targetFieldName": "contentVector"}
  ]
}
EOF

az rest --method put \
  --url "${SEARCH_ENDPOINT}/indexers/${INDEXER_NAME}?api-version=2023-11-01" \
  --headers "api-key=${SEARCH_ADMIN_KEY}" "Content-Type=application/json" \
  --body @/tmp/ai-search-indexer.json >/dev/null

log_success "AI Search indexer created. You can run it now:"
log_success "az rest --method post --url ${SEARCH_ENDPOINT}/indexers/${INDEXER_NAME}/run?api-version=2023-11-01 --headers api-key=${SEARCH_ADMIN_KEY}"

log_info "Next: Deploy OpenAI chat model in Azure OpenAI Studio and set OPENAI_DEPLOYMENT in rag-query.py"
