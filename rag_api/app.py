from fastapi import FastAPI, Header, HTTPException, Request
from pydantic import BaseModel
import os
import time
import logging
import requests
import jwt
import redis

app = FastAPI(title="Azure ETL RAG API", version="1.0")

SEARCH_ENDPOINT = os.getenv("SEARCH_ENDPOINT")
SEARCH_ADMIN_KEY = os.getenv("SEARCH_ADMIN_KEY")
INDEX_NAME = os.getenv("SEARCH_INDEX", "etl-docs-index")
OPENAI_ENDPOINT = os.getenv("OPENAI_ENDPOINT")
OPENAI_KEY = os.getenv("OPENAI_KEY")
OPENAI_DEPLOYMENT = os.getenv("OPENAI_DEPLOYMENT", "gpt-4o-mini")
OPENAI_EMBEDDING_DEPLOYMENT = os.getenv("OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-3-small")
FILTER_EXPR = os.getenv("SEARCH_FILTER")

API_KEY = os.getenv("RAG_API_KEY")
JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ISSUER = os.getenv("JWT_ISSUER")
JWT_AUDIENCE = os.getenv("JWT_AUDIENCE")
RATE_LIMIT_RPS = float(os.getenv("RAG_RATE_LIMIT_RPS", "2"))
RATE_LIMIT_PER_MIN = int(os.getenv("RAG_RATE_LIMIT_PER_MIN", "120"))
REDIS_URL = os.getenv("REDIS_URL")

logger = logging.getLogger("rag_api")
logging.basicConfig(level=logging.INFO)

class AskRequest(BaseModel):
    question: str

class RateLimiter:
    def __init__(self, rate_per_sec: float):
        self.rate = rate_per_sec
        self.allowance = rate_per_sec
        self.last_check = time.time()

    def allow(self) -> bool:
        current = time.time()
        time_passed = current - self.last_check
        self.last_check = current
        self.allowance += time_passed * self.rate
        if self.allowance > self.rate:
            self.allowance = self.rate
        if self.allowance < 1.0:
            return False
        self.allowance -= 1.0
        return True

limiter = RateLimiter(RATE_LIMIT_RPS)
redis_client = redis.from_url(REDIS_URL) if REDIS_URL else None

@app.middleware("http")
async def log_requests(request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = (time.time() - start) * 1000
    logger.info("%s %s %s %.2fms", request.method, request.url.path, response.status_code, duration)
    return response


def require_env():
    if not all([SEARCH_ENDPOINT, SEARCH_ADMIN_KEY, OPENAI_ENDPOINT, OPENAI_KEY]):
        raise HTTPException(status_code=500, detail="Missing required environment variables")


def authenticate(api_key: str | None, authorization: str | None):
    if API_KEY and api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if JWT_SECRET:
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Missing Bearer token")
        token = authorization.split(" ", 1)[1]
        try:
            payload = jwt.decode(
                token,
                JWT_SECRET,
                algorithms=["HS256"],
                audience=JWT_AUDIENCE,
                issuer=JWT_ISSUER,
                options={"verify_aud": bool(JWT_AUDIENCE), "verify_iss": bool(JWT_ISSUER)}
            )
        except jwt.PyJWTError:
            raise HTTPException(status_code=401, detail="Invalid token")


def embed(text: str):
    url = f"{OPENAI_ENDPOINT}/openai/deployments/{OPENAI_EMBEDDING_DEPLOYMENT}/embeddings?api-version=2024-02-15-preview"
    headers = {"Content-Type": "application/json", "api-key": OPENAI_KEY}
    payload = {"input": text}
    resp = requests.post(url, headers=headers, json=payload, timeout=30)
    resp.raise_for_status()
    return resp.json()["data"][0]["embedding"]


def search(question: str):
    search_url = f"{SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version=2023-11-01"
    embedding = embed(question)
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
    citations = [
        {"name": r.get("metadata_storage_name"), "path": r.get("metadata_storage_path")}
        for r in results
    ]
    return context, citations


def answer(question: str, context: str):
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


@app.post("/ask")
def ask(payload: AskRequest, request: Request, x_api_key: str | None = Header(default=None), authorization: str | None = Header(default=None)):
    require_env()
    authenticate(x_api_key, authorization)

    if redis_client:
        key = f"rag_rl:{request.client.host}:{int(time.time() / 60)}"
        count = redis_client.incr(key)
        if count == 1:
            redis_client.expire(key, 60)
        if count > RATE_LIMIT_PER_MIN:
            raise HTTPException(status_code=429, detail="Rate limit exceeded")
    else:
        if not limiter.allow():
            raise HTTPException(status_code=429, detail="Rate limit exceeded")

    question = payload.question.strip()
    if not question:
        raise HTTPException(status_code=400, detail="Question is required")

    context, citations = search(question)
    response = answer(question, context)

    return {
        "answer": response,
        "citations": citations
    }
