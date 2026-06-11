"""rbrain-cortex entry point."""

from fastapi import FastAPI

CONTEXT_NAME = "cortex"

app = FastAPI(title=f"rbrain-{CONTEXT_NAME}", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "context": CONTEXT_NAME}
