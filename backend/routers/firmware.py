import httpx
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/api/firmware", tags=["Firmware"])

GITHUB_REPO = "LarsEsDoch/kyndora"
GITHUB_API_BASE = f"https://api.github.com/repos/{GITHUB_REPO}"


@router.get("/check")
async def check_firmware(channel: str = "stable", version: str | None = None):
    if version:
        url = f"{GITHUB_API_BASE}/releases/tags/{version}"
    elif channel == "stable":
        url = f"{GITHUB_API_BASE}/releases/latest"
    elif channel == "beta":
        url = f"{GITHUB_API_BASE}/releases/tags/beta"
    else:
        raise HTTPException(
            status_code=400,
            detail="Invalid Channel. Use 'stable' or 'beta'.",
        )

    async with httpx.AsyncClient() as client:
        headers = {
            "User-Agent": "FastAPI-OTA-Proxy",
            "Accept": "application/vnd.github+json",
        }
        response = await client.get(url, headers=headers)

    if response.status_code == 404:
        raise HTTPException(
            status_code=404, detail=f"No Release found for channel '{channel}'."
        )
    elif response.status_code != 200:
        raise HTTPException(status_code=500, detail="GitHub API not reachable.")

    data = response.json()

    firmware_asset = next(
        (
            asset
            for asset in data.get("assets", [])
            if asset["name"].endswith("firmware.bin")
        ),
        None,
    )

    if not firmware_asset:
        raise HTTPException(
            status_code=404,
            detail="No 'firmware.bin' asset found in this release.",
        )
    version_string = (
        data.get("tag_name")
        if channel == "stable"
        else f"beta-{data.get('target_commitish')[:7]}"
    )

    return {
        "channel": channel,
        "version": version_string,
        "download_url": firmware_asset["browser_download_url"],
        "updated_at": firmware_asset.get("updated_at"),
    }