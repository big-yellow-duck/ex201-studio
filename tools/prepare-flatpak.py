#!/usr/bin/env python3
"""Capture the pinned Flutter SDK/pub cache for a network-free Flatpak build.

Run flutter pub get and flutter precache --linux first. This writes local
build inputs, never app data. Large toolchain archives are not release assets.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent.parent
flutter = os.environ.get("EX201_FLUTTER_SDK")
if flutter:
    sdk = Path(flutter).resolve()
else:
    executable = shutil.which("flutter")
    if not executable:
        raise SystemExit("Install Flutter, or set EX201_FLUTTER_SDK to its root directory.")
    sdk = Path(executable).resolve().parent.parent
pub = Path(os.environ.get("PUB_CACHE", str(Path.home() / ".pub-cache"))).resolve()
deps = ROOT / ".flatpak-deps"
deps.mkdir(exist_ok=True)
commit = subprocess.check_output(["git", "-C", str(sdk), "rev-parse", "HEAD"], text=True).strip()
expected = "737ba8f885dc774b53b442759999a312c9461e4e"
if commit != expected:
    raise SystemExit(f"Use Flutter 3.47.8 / commit {expected}; found {commit}.")


def archive(source, name):
    target = deps / name
    if not target.exists():
        print(f"Archiving {source} → {target.name}", flush=True)
        def include(info):
            if info.name.endswith(("/lockfile", "/.lock", "/.DS_Store")):
                return None
            return info
        with tarfile.open(str(target) + ".tmp", "w:gz", compresslevel=1) as out:
            out.add(source, arcname=".", filter=include)
        Path(str(target) + ".tmp").replace(target)
    digest = hashlib.file_digest(target.open("rb"), "sha256").hexdigest()
    return {"file": target.name, "sha256": digest, "bytes": target.stat().st_size}


items = [archive(sdk, "flutter-sdk.tar.gz"), archive(pub, "pub-cache.tar.gz")]
record = {"flutter_version": "3.47.8", "flutter_commit": commit,
          "dart_version": "3.13.7", "runtime": "org.freedesktop.Platform/26.08",
          "archives": items,
          "pubspec_lock_sha256": hashlib.sha256((ROOT / "pubspec.lock").read_bytes()).hexdigest()}
(deps / "toolchain.json").write_text(json.dumps(record, indent=2) + "\n")
# Pin the local archive bytes as well as the Flutter source and pub lock.
manifest = ROOT / "packaging/io.github.big_yellow_duck.EX201Studio.json"
data = json.loads(manifest.read_text())
for source, entry in zip(data["modules"][0]["sources"][1:], items):
    source["sha256"] = entry["sha256"]
manifest.write_text(json.dumps(data, indent=2) + "\n")
print(json.dumps(record, indent=2))
