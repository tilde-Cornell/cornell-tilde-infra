from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer
import jwt
import requests

security = HTTPBearer()

JWKS_URL = "https://authentik.example.com/application/o/jwks/"
jwks = requests.get(JWKS_URL).json()

def verify_token(credentials=Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            jwks,  # simplified; normally pick correct key
            algorithms=["RS256"],
            audience="your-client-id",
            issuer="https://authentik.example.com/application/o/"
        )
        return payload
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")