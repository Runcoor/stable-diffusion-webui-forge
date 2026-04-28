"""OpenAI-compatible image generation adapter for Stable Diffusion WebUI Forge.

Translates POST /v1/images/generations into POST /sdapi/v1/txt2img so that
clients speaking the OpenAI Images API (e.g. new-api) can drive a Forge backend
unmodified.
"""
import os
import time
from typing import List, Optional

import httpx
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

FORGE_URL = os.getenv("FORGE_URL", "http://forge:7860").rstrip("/")
FORGE_USER = os.getenv("FORGE_USER", "")
FORGE_PASS = os.getenv("FORGE_PASS", "")
ADAPTER_KEY = os.getenv("ADAPTER_KEY", "")

DEFAULT_STEPS = int(os.getenv("DEFAULT_STEPS", "30"))
DEFAULT_SAMPLER = os.getenv("DEFAULT_SAMPLER", "DPM++ 2M Karras")
DEFAULT_CFG = float(os.getenv("DEFAULT_CFG", "7"))
DEFAULT_NEG = os.getenv("DEFAULT_NEGATIVE_PROMPT", "")
REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT", "600"))

app = FastAPI(title="SD-WebUI OpenAI Adapter", version="0.1.0")


class ImageRequest(BaseModel):
    model: Optional[str] = None
    prompt: str
    n: int = 1
    size: str = "1024x1024"
    response_format: str = "b64_json"
    quality: Optional[str] = None
    style: Optional[str] = None
    user: Optional[str] = None


class ImageData(BaseModel):
    b64_json: Optional[str] = None
    url: Optional[str] = None
    revised_prompt: Optional[str] = None


class ImageResponse(BaseModel):
    created: int
    data: List[ImageData]


def _forge_auth():
    return (FORGE_USER, FORGE_PASS) if FORGE_USER else None


def _check_auth(authorization: Optional[str]) -> None:
    if not ADAPTER_KEY:
        return
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    if authorization.split(None, 1)[1] != ADAPTER_KEY:
        raise HTTPException(401, "invalid bearer token")


def _parse_size(size: str) -> tuple[int, int]:
    try:
        w, h = size.lower().split("x", 1)
        return int(w), int(h)
    except Exception:
        raise HTTPException(400, f"invalid size: {size!r} (expected 'WIDTHxHEIGHT')")


async def _maybe_switch_model(client: httpx.AsyncClient, model: Optional[str]) -> None:
    if not model:
        return
    r = await client.post(
        f"{FORGE_URL}/sdapi/v1/options",
        json={"sd_model_checkpoint": model},
        auth=_forge_auth(),
    )
    if r.status_code >= 400:
        raise HTTPException(r.status_code, f"failed to switch model {model!r}: {r.text}")


@app.get("/healthz")
async def healthz():
    async with httpx.AsyncClient(timeout=5) as c:
        try:
            r = await c.get(f"{FORGE_URL}/sdapi/v1/progress", auth=_forge_auth())
            return {"adapter": "ok", "forge_status": r.status_code}
        except Exception as e:
            raise HTTPException(503, f"forge unreachable: {e}")


@app.get("/v1/models")
async def list_models(authorization: Optional[str] = Header(default=None)):
    _check_auth(authorization)
    async with httpx.AsyncClient(timeout=30) as c:
        r = await c.get(f"{FORGE_URL}/sdapi/v1/sd-models", auth=_forge_auth())
    if r.status_code != 200:
        raise HTTPException(r.status_code, r.text)
    return {
        "object": "list",
        "data": [
            {
                "id": m.get("model_name") or m.get("title"),
                "object": "model",
                "created": int(time.time()),
                "owned_by": "forge",
            }
            for m in r.json()
        ],
    }


@app.post("/v1/images/generations", response_model=ImageResponse)
async def images_generations(
    req: ImageRequest,
    authorization: Optional[str] = Header(default=None),
):
    _check_auth(authorization)
    width, height = _parse_size(req.size)
    n = max(1, min(req.n, 8))
    payload = {
        "prompt": req.prompt,
        "negative_prompt": DEFAULT_NEG,
        "width": width,
        "height": height,
        "steps": DEFAULT_STEPS,
        "sampler_name": DEFAULT_SAMPLER,
        "cfg_scale": DEFAULT_CFG,
        "n_iter": 1,
        "batch_size": n,
        "send_images": True,
        "save_images": False,
    }

    async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as c:
        await _maybe_switch_model(c, req.model)
        r = await c.post(f"{FORGE_URL}/sdapi/v1/txt2img", json=payload, auth=_forge_auth())

    if r.status_code != 200:
        raise HTTPException(r.status_code, r.text)

    images = r.json().get("images", [])[:n]
    data: List[ImageData] = []
    for img_b64 in images:
        if req.response_format == "url":
            data.append(ImageData(url=f"data:image/png;base64,{img_b64}"))
        else:
            data.append(ImageData(b64_json=img_b64))
    return ImageResponse(created=int(time.time()), data=data)
