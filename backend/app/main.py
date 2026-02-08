from __future__ import annotations

from datetime import datetime, timezone

from fastapi import FastAPI

from .models import ConfigResponse, ManifestResponse, ReportRequest
from .store import append_report, load_manifest

app = FastAPI(title="Residue API", version="0.1.0")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "timestamp": datetime.now(timezone.utc).isoformat()}


@app.get("/v1/config", response_model=ConfigResponse)
def get_config() -> ConfigResponse:
    return ConfigResponse(
        game_title="Residue",
        min_supported_app_version="0.1.0",
        feature_flags={
            "use_manifest_assets": True,
            "enable_timed_choices": False,
            "enable_cross_world_rewrite": True,
        },
    )


@app.get("/v1/assets/manifest", response_model=ManifestResponse)
def get_manifest(
    platform: str,
    app_version: str,
    locale: str,
    last_manifest_version: int | None = None,
) -> ManifestResponse:
    _ = (platform, app_version, locale)
    data = load_manifest()
    manifest = ManifestResponse.model_validate(data)

    if last_manifest_version is not None and last_manifest_version >= manifest.manifest_version:
        return ManifestResponse(
            manifest_version=manifest.manifest_version,
            generated_at=manifest.generated_at,
            required_bytes_wifi=0,
            required_bytes_cellular=0,
            assets=[],
            deleted_asset_ids=[],
        )

    return manifest


@app.post("/v1/assets/report")
def report_asset_error(payload: ReportRequest) -> dict:
    append_report(
        {
            "asset_id": payload.asset_id,
            "version": payload.version,
            "error_code": payload.error_code,
            "network_type": payload.network_type,
            "reported_at": datetime.now(timezone.utc).isoformat(),
        }
    )
    return {"accepted": True}
