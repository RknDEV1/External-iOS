#!/usr/bin/env python3
"""Validate the Free Fire patch category contract.

This intentionally fails when a patch is moved to the wrong category, omitted
from the manifest, duplicated, or has a stale SHA-256 entry. Update
EXPECTED_FILES deliberately when the patch set changes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

EXPECTED_FILES = {
    "Avatar": {
        "HSALTO.3105",
        "HSPEITO.3105",
        "HSPESCOÇO.3105",
        "HSPESCOÇOALTO.3105",
        "HSBYPASSAP.3105",
    },
}


def fail(message: str) -> None:
    raise SystemExit(f"patch category validation failed: {message}")


def validate(root: Path) -> None:
    patch_root = root / "ThreeOneOSFive" / "FreeFirePatches"
    manifest_path = patch_root / "manifest.json"
    if not manifest_path.is_file():
        fail(f"missing manifest: {manifest_path}")

    try:
        entries = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"manifest is not valid JSON: {exc}")
    if not isinstance(entries, list):
        fail("manifest root must be an array")

    expected_files = {
        f"{category}/{name}"
        for category, names in EXPECTED_FILES.items()
        for name in names
    }
    physical_files = {
        str(path.relative_to(patch_root))
        for path in patch_root.rglob("*.3105")
    }
    if physical_files != expected_files:
        fail(f"physical files differ; missing={expected_files - physical_files}, unexpected={physical_files - expected_files}")

    if len(entries) != len(expected_files):
        fail(f"expected {len(expected_files)} manifest entries, got {len(entries)}")

    seen_ids: set[int] = set()
    seen_paths: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            fail("every manifest entry must be an object")
        required = {"id", "category", "file", "path", "sha256"}
        missing = required - entry.keys()
        if missing:
            fail(f"entry is missing fields: {sorted(missing)}")

        entry_id = entry["id"]
        category = entry["category"]
        filename = entry["file"]
        relative_path = entry["path"]
        digest = entry["sha256"]
        if not isinstance(entry_id, int) or entry_id in seen_ids:
            fail(f"duplicate or invalid id: {entry_id!r}")
        seen_ids.add(entry_id)
        if category not in EXPECTED_FILES:
            fail(f"unsupported category {category!r} for {filename!r}")
        if not isinstance(filename, str) or not isinstance(relative_path, str):
            fail(f"invalid filename/path for entry {entry!r}")
        if relative_path != f"{category}/{filename}":
            fail(f"category/path mismatch: {category!r}, {relative_path!r}")
        if relative_path in seen_paths:
            fail(f"duplicate path: {relative_path}")
        seen_paths.add(relative_path)
        if filename not in EXPECTED_FILES[category]:
            fail(f"{filename!r} is assigned to {category}, but the expected mapping is different")
        file_path = patch_root / relative_path
        if not file_path.is_file():
            fail(f"manifest points to missing file: {relative_path}")
        actual_digest = hashlib.sha256(file_path.read_bytes()).hexdigest()
        if digest != actual_digest:
            fail(f"stale SHA-256 for {relative_path}")

    if seen_paths != expected_files:
        fail(f"manifest paths differ; missing={expected_files - seen_paths}, unexpected={seen_paths - expected_files}")

    for category, expected in EXPECTED_FILES.items():
        actual = {entry["file"] for entry in entries if entry["category"] == category}
        if actual != expected:
            fail(f"{category} mapping differs; missing={expected - actual}, unexpected={actual - expected}")

    print(f"patch category validation passed: Avatar={len(EXPECTED_FILES['Avatar'])}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    validate(args.root.resolve())
