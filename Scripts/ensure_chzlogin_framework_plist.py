#!/usr/bin/env python3
import plistlib
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: ensure_chzlogin_framework_plist.py APP_PATH")

app = Path(sys.argv[1]).resolve()
app_info_path = app / "Info.plist"
framework = app / "Frameworks" / "ChzLogin.framework"
binary = framework / "ChzLogin"

if not app_info_path.is_file():
    raise SystemExit(f"app Info.plist not found: {app_info_path}")
if not binary.is_file():
    raise SystemExit(f"ChzLogin binary not found: {binary}")

with app_info_path.open("rb") as handle:
    app_info = plistlib.load(handle)
app_bundle_id = app_info.get("CFBundleIdentifier")
if not app_bundle_id:
    raise SystemExit("app CFBundleIdentifier is missing")

framework.mkdir(parents=True, exist_ok=True)
framework_info = {
    "CFBundleDevelopmentRegion": "en",
    "CFBundleExecutable": "ChzLogin",
    "CFBundleIdentifier": f"{app_bundle_id}.ChzLogin",
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": "ChzLogin",
    "CFBundlePackageType": "FMWK",
    "CFBundleShortVersionString": "1.0",
    "CFBundleSignature": "????",
    "CFBundleSupportedPlatforms": ["iPhoneOS"],
    "CFBundleVersion": "1",
    "MinimumOSVersion": app_info.get("MinimumOSVersion", "16.0"),
}
with (framework / "Info.plist").open("wb") as handle:
    plistlib.dump(framework_info, handle, fmt=plistlib.FMT_XML, sort_keys=False)

print(f"Preserved app Bundle ID: {app_bundle_id}")
print(f"Wrote framework Bundle ID: {framework_info['CFBundleIdentifier']}")
