#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_IMAGE="${1:-${REPO_ROOT}/icon.png}"
APPICON_DIR="${REPO_ROOT}/HoroDrift/Assets.xcassets/AppIcon.appiconset"

if ! command -v sips >/dev/null 2>&1; then
  echo "Error: sips is required but was not found in PATH." >&2
  exit 1
fi

if [[ ! -f "${SOURCE_IMAGE}" ]]; then
  echo "Error: source image not found: ${SOURCE_IMAGE}" >&2
  exit 1
fi

mkdir -p "${APPICON_DIR}"

resize_icon() {
  local filename="$1"
  local size="$2"
  sips -z "${size}" "${size}" "${SOURCE_IMAGE}" --out "${APPICON_DIR}/${filename}" >/dev/null
}

resize_icon "AppIcon-1024.png" 1024
cp "${APPICON_DIR}/AppIcon-1024.png" "${APPICON_DIR}/AppIcon-1024-dark.png"
cp "${APPICON_DIR}/AppIcon-1024.png" "${APPICON_DIR}/AppIcon-1024-tinted.png"

resize_icon "AppIcon-mac-16.png" 16
resize_icon "AppIcon-mac-32.png" 32
resize_icon "AppIcon-mac-32@2x.png" 64
resize_icon "AppIcon-mac-128.png" 128
resize_icon "AppIcon-mac-256.png" 256
resize_icon "AppIcon-mac-256@2x.png" 512
resize_icon "AppIcon-mac-512.png" 512
resize_icon "AppIcon-mac-1024.png" 1024

echo "App icons generated in ${APPICON_DIR}"
