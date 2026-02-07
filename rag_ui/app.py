from fastapi import FastAPI, Form
from fastapi.responses import HTMLResponse
import os
import requests

app = FastAPI(title="Azure ETL RAG UI")

SEARCH_ENDPOINT = os.getenv("SEARCH_ENDPOINT")
SEARCH_ADMIN_KEY = os.getenv("SEARCH_ADMIN_KEY")
INDEX_NAME = os.getenv("SEARCH_INDEX", "etl-docs-index")
OPENAI_ENDPOINT = os.getenv("OPENAI_ENDPOINT")
OPENAI_KEY = os.getenv("OPENAI_KEY")
OPENAI_DEPLOYMENT = os.getenv("OPENAI_DEPLOYMENT", "gpt-4o-mini")
OPENAI_EMBEDDING_DEPLOYMENT = os.getenv("OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-3-small")
FILTER_EXPR = os.getenv("SEARCH_FILTER")

HTML_PAGE = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Azure ETL RAG UI</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background: #f8fafc; }
    .container { max-width: 900px; margin: 0 auto; background: white; padding: 24px; border-radius: 12px; box-shadow: 0 6px 20px rgba(0,0,0,0.08); }
    textarea { width: 100%; min-height: 100px; padding: 12px; border-radius: 8px; border: 1px solid #cbd5e1; }
    button { background: #2563eb; color: white; border: none; padding: 10px 16px; border-radius: 8px; cursor: pointer; }
    .answer { margin-top: 20px; padding: 16px; background: #f1f5f9; border-radius: 8px; }
    .citations { margin-top: 12px; font-size: 0.9rem; color: #475569; }
  </style>
</head>
<body>
  <div class="container">
    <h2>Azure ETL RAG UI</h2>
    <form method="post" action="/ask">
      <label>Ask a question</label>
      <textarea name="question" placeholder="Ask about the data or docs..." required></textarea>
      <br /><br />
      <button type="submit">Ask</button>
    </form>
    {% if answer %}
      <div class="answer">
        <strong>Answer:</strong>
        <div>{{ answer }}</div>
        <div class="citations">
          <strong>Citations:</strong>
          <ul>
            {% for c in citations %}
              <li>{{ c }}</li>
            {% endfor %}
          </ul>
        </div>
      </div>
    {% endif %}
  </div>
</body>
</html>
"""


def _embed(text: str):
    url = f"{OPENAI_ENDPOINT}/openai/deployments/{OPENAI_EMBEDDING_DEPLOYMENT}/embeddings?api-version=2024-02-15-preview"
    headers = {"Content-Type": "application/json", "api-key": OPENAI_KEY}
    payload = {"input": text}
    resp = requests.post(url, headers=headers, json=payload, timeout=30)
    resp.raise_for_status()
    return resp.json()["data"][0]["embedding"]


def _search(question: str):
    search_url = f"{SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version=2023-11-01"
    embedding = _embed(question)
    payload = {
        "search": question,
        "top": 5,
        "select": "content,metadata_storage_name,metadata_storage_path",
        "vectorQueries": [
            {"kind": "vector", "vector": embedding, "fields": "contentVector", "k": 5}
        ],
        "semanticConfiguration": "default",
        "queryType": "semantic",
        "captions": "extractive"
    }
    if FILTER_EXPR:
        payload["filter"] = FILTER_EXPR
    headers = {"Content-Type": "application/json", "api-key": SEARCH_ADMIN_KEY}
    resp = requests.post(search_url, headers=headers, json=payload, timeout=30)
    resp.raise_for_status()
    results = resp.json().get("value", [])
    context = "\n\n".join([f"{r.get('metadata_storage_name')}: {r.get('content','')[:1200]}" for r in results])
    citations = [f"{r.get('metadata_storage_name')} - {r.get('metadata_storage_path')}" for r in results]
    return context, citations


def _answer(question: str, context: str):
    openai_url = f"{OPENAI_ENDPOINT}/openai/deployments/{OPENAI_DEPLOYMENT}/chat/completions?api-version=2024-02-15-preview"
    openai_headers = {"Content-Type": "application/json", "api-key": OPENAI_KEY}
    openai_payload = {
        "messages": [
            {"role": "system", "content": "You are a helpful assistant. Use the provided context only."},
            {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {question}"}
        ],
        "temperature": 0.2,
        "max_tokens": 600
    }
    resp = requests.post(openai_url, headers=openai_headers, json=openai_payload, timeout=60)
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"]


@app.get("/", response_class=HTMLResponse)
def home():
    return HTML_PAGE


@app.post("/ask", response_class=HTMLResponse)
def ask(question: str = Form(...)):
    if not all([SEARCH_ENDPOINT, SEARCH_ADMIN_KEY, OPENAI_ENDPOINT, OPENAI_KEY]):
        return HTML_PAGE.replace("{% if answer %}", "").replace("{% endif %}", "") + "<p>Missing env vars.</p>"

    context, citations = _search(question)
    answer = _answer(question, context)
    rendered = HTML_PAGE.replace("{% if answer %}", "").replace("{% endif %}", "")
    rendered = rendered.replace("{{ answer }}", answer)
    citation_list = "".join([f"<li>{c}</li>" for c in citations])
    rendered = rendered.replace("{% for c in citations %}\n              <li>{{ c }}</li>\n            {% endfor %}", citation_list)
    return rendered
