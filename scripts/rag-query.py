import os
import requests

SEARCH_ENDPOINT = os.getenv("SEARCH_ENDPOINT")
SEARCH_ADMIN_KEY = os.getenv("SEARCH_ADMIN_KEY")
INDEX_NAME = os.getenv("SEARCH_INDEX", "etl-docs-index")
OPENAI_ENDPOINT = os.getenv("OPENAI_ENDPOINT")
OPENAI_KEY = os.getenv("OPENAI_KEY")
OPENAI_DEPLOYMENT = os.getenv("OPENAI_DEPLOYMENT", "gpt-4o-mini")
OPENAI_EMBEDDING_DEPLOYMENT = os.getenv("OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-3-small")
FILTER_EXPR = os.getenv("SEARCH_FILTER")

if not all([SEARCH_ENDPOINT, SEARCH_ADMIN_KEY, OPENAI_ENDPOINT, OPENAI_KEY]):
    raise SystemExit("Missing env vars: SEARCH_ENDPOINT, SEARCH_ADMIN_KEY, OPENAI_ENDPOINT, OPENAI_KEY")

question = input("Ask a question: ")

# Create embedding for vector search
embedding_url = f"{OPENAI_ENDPOINT}/openai/deployments/{OPENAI_EMBEDDING_DEPLOYMENT}/embeddings?api-version=2024-02-15-preview"
embedding_headers = {
    "Content-Type": "application/json",
    "api-key": OPENAI_KEY
}
embedding_payload = {"input": question}

embedding_resp = requests.post(embedding_url, headers=embedding_headers, json=embedding_payload, timeout=30)
embedding_resp.raise_for_status()
embedding = embedding_resp.json()["data"][0]["embedding"]

# Retrieve top documents
search_url = f"{SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version=2023-11-01"
search_payload = {
    "search": question,
    "top": 5,
    "select": "content,metadata_storage_name,metadata_storage_path",
    "vectorQueries": [
        {
            "kind": "vector",
            "vector": embedding,
            "fields": "contentVector",
            "k": 5
        }
    ],
    "semanticConfiguration": "default",
    "queryType": "semantic",
    "captions": "extractive"
}

if FILTER_EXPR:
    search_payload["filter"] = FILTER_EXPR
search_headers = {
    "Content-Type": "application/json",
    "api-key": SEARCH_ADMIN_KEY
}

resp = requests.post(search_url, headers=search_headers, json=search_payload, timeout=30)
resp.raise_for_status()
results = resp.json().get("value", [])
context = "\n\n".join([f"{r.get('metadata_storage_name')}: {r.get('content','')[:1200]}" for r in results])

# Call Azure OpenAI
openai_url = f"{OPENAI_ENDPOINT}/openai/deployments/{OPENAI_DEPLOYMENT}/chat/completions?api-version=2024-02-15-preview"
openai_headers = {
    "Content-Type": "application/json",
    "api-key": OPENAI_KEY
}
openai_payload = {
    "messages": [
        {"role": "system", "content": "You are a helpful assistant. Use the provided context."},
        {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {question}"}
    ],
    "temperature": 0.2,
    "max_tokens": 600
}

resp = requests.post(openai_url, headers=openai_headers, json=openai_payload, timeout=60)
resp.raise_for_status()
print(resp.json()["choices"][0]["message"]["content"])

print("\nCitations:")
for idx, r in enumerate(results, start=1):
    print(f"[{idx}] {r.get('metadata_storage_name')} - {r.get('metadata_storage_path')}")
