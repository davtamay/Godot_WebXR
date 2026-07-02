#!/usr/bin/env python3
"""Measure raw and compressed size estimates for a web export directory.

Usage:
  python measure_web_build.py /path/to/exported-web-build --out build_size.json

This is intentionally engine-neutral. It can be used on Godot exports, Unity Web builds,
PlayCanvas/Babylon bundles, or any static web build.
"""
from __future__ import annotations

import argparse
import gzip
import json
import os
from pathlib import Path
from typing import Any

try:
    import brotli  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    brotli = None

CATEGORIES = {
    "wasm": {".wasm"},
    "javascript": {".js", ".mjs"},
    "html_css": {".html", ".htm", ".css"},
    "godot_pack": {".pck"},
    "unity_data": {".data", ".symbols.json", ".bundle"},
    "images_textures": {".png", ".jpg", ".jpeg", ".webp", ".ktx", ".ktx2", ".basis", ".dds"},
    "models": {".glb", ".gltf", ".bin", ".fbx", ".obj"},
    "audio": {".ogg", ".mp3", ".wav", ".m4a", ".aac"},
    "video": {".mp4", ".webm", ".mov"},
    "metadata": {".json", ".xml", ".txt", ".md", ".mem"},
}


def category_for(path: Path) -> str:
    suffix = path.suffix.lower()
    for category, suffixes in CATEGORIES.items():
        if suffix in suffixes:
            return category
    return "other"


def gzip_size(data: bytes) -> int:
    return len(gzip.compress(data, compresslevel=9))


def brotli_size(data: bytes) -> int | None:
    if brotli is None:
        return None
    return len(brotli.compress(data, quality=11))


def measure_file(path: Path, root: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {
        "path": str(path.relative_to(root)).replace(os.sep, "/"),
        "category": category_for(path),
        "raw_bytes": len(data),
        "gzip_bytes_estimate": gzip_size(data),
        "brotli_bytes_estimate": brotli_size(data),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("build_dir", type=Path)
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--top", type=int, default=20)
    args = parser.parse_args()

    root = args.build_dir.resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Build directory does not exist or is not a directory: {root}")

    files = [p for p in root.rglob("*") if p.is_file()]
    measurements = [measure_file(p, root) for p in files]

    by_category: dict[str, dict[str, int | None]] = {}
    total_brotli_known = True
    for item in measurements:
        cat = item["category"]
        bucket = by_category.setdefault(cat, {
            "file_count": 0,
            "raw_bytes": 0,
            "gzip_bytes_estimate": 0,
            "brotli_bytes_estimate": 0,
        })
        bucket["file_count"] = int(bucket["file_count"] or 0) + 1
        bucket["raw_bytes"] = int(bucket["raw_bytes"] or 0) + int(item["raw_bytes"])
        bucket["gzip_bytes_estimate"] = int(bucket["gzip_bytes_estimate"] or 0) + int(item["gzip_bytes_estimate"])
        if item["brotli_bytes_estimate"] is None:
            total_brotli_known = False
        else:
            bucket["brotli_bytes_estimate"] = int(bucket["brotli_bytes_estimate"] or 0) + int(item["brotli_bytes_estimate"])

    total = {
        "file_count": len(files),
        "raw_bytes": sum(int(i["raw_bytes"]) for i in measurements),
        "gzip_bytes_estimate": sum(int(i["gzip_bytes_estimate"]) for i in measurements),
        "brotli_bytes_estimate": None if not total_brotli_known else sum(int(i["brotli_bytes_estimate"] or 0) for i in measurements),
    }

    result = {
        "build_dir": str(root),
        "total": total,
        "by_category": by_category,
        "largest_files": sorted(measurements, key=lambda i: int(i["raw_bytes"]), reverse=True)[: args.top],
        "notes": [
            "gzip/brotli values are estimates from local compression, not CDN-verified transfer sizes.",
            "Use identical server compression settings when comparing engines.",
            "Measure cold-cache and warm-cache startup separately in the browser.",
        ],
    }

    text = json.dumps(result, indent=2)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + "\n", encoding="utf-8")
    else:
        print(text)


if __name__ == "__main__":
    main()
