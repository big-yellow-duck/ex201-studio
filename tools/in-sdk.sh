#!/usr/bin/env bash
set -euo pipefail
EX201_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${EX201_FLUTTER_SDK:-}" ]]; then
  EX201_SDK="$(realpath "$EX201_FLUTTER_SDK")"
else
  EX201_SDK="$(dirname "$(dirname "$(realpath "$(command -v flutter)")")")"
fi
EX201_PUB_CACHE="$(realpath "${PUB_CACHE:-$HOME/.pub-cache}")"
exec flatpak run --devel --share=network \
  --filesystem="$EX201_ROOT" --filesystem="$EX201_SDK" \
  --filesystem="$EX201_PUB_CACHE" \
  --env="PATH=$EX201_SDK/bin:/usr/lib/sdk/llvm22/bin:/usr/bin:/bin" \
  --env="PUB_CACHE=$EX201_PUB_CACHE" \
  --env="EX201_PROJECT_ROOT=$EX201_ROOT" \
  --command=bash org.freedesktop.Sdk//26.08 \
  -c 'cd "$EX201_PROJECT_ROOT"; exec "$@"' bash "$EX201_SDK/bin/flutter" "$@"
