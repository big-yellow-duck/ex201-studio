#!/usr/bin/env bash
set -euo pipefail
EX201_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EX201_ROOT"
python3 tools/prepare-flatpak.py
mkdir -p dist
flatpak-builder --user --force-clean --disable-rofiles-fuse \
  --repo=dist/repo build/flatpak packaging/io.github.big_yellow_duck.EX201Studio.json
flatpak build-bundle --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo \
  dist/repo dist/EX201-Studio-1.0.0-x86_64.flatpak io.github.big_yellow_duck.EX201Studio stable
(cd dist && sha256sum EX201-Studio-1.0.0-x86_64.flatpak > SHA256SUMS)
