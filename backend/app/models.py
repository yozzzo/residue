from __future__ import annotations

from datetime import datetime
from typing import List, Literal

from pydantic import BaseModel, Field


class AssetItem(BaseModel):
    asset_id: str
    type: Literal["image", "audio", "music"] = "image"
    tags: List[str] = Field(default_factory=list)
    priority: Literal["high", "normal", "low"] = "normal"
    version: int
    hash: str
    size_bytes: int
    cdn_url: str


class ManifestResponse(BaseModel):
    manifest_version: int
    generated_at: datetime
    required_bytes_wifi: int
    required_bytes_cellular: int
    assets: List[AssetItem]
    deleted_asset_ids: List[str] = Field(default_factory=list)


class ReportRequest(BaseModel):
    asset_id: str
    version: int
    error_code: str
    network_type: Literal["wifi", "cellular", "offline", "unknown"] = "unknown"


class ConfigResponse(BaseModel):
    game_title: str
    min_supported_app_version: str
    feature_flags: dict[str, bool]
