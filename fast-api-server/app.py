"""
This is the entry point that runs the fast-api app
"""
from fastapi import FastAPI
from routes import auth

app = FastAPI(
    title="cornell tilde",
    description="interface for cornell tilde users to manage their accounts",
)

@app.get("/health")
async def health():
    return {"status": "ok"}

app.include_router(auth.router)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
    )
