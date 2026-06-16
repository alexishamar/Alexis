#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTML_FILE="${SCRIPT_DIR}/sales_bdi_video.html"
OUTPUT_FILE="${SCRIPT_DIR}/sales_bdi_video.mp4"

DISPLAY_NUM=":99"
TMP_ROOT="$(mktemp -d)"
XVFB_PID=""
CHROME_PID=""

cleanup() {
  if [[ -n "${CHROME_PID}" ]] && kill -0 "${CHROME_PID}" 2>/dev/null; then
    kill "${CHROME_PID}" 2>/dev/null || true
    wait "${CHROME_PID}" 2>/dev/null || true
  fi
  if [[ -n "${XVFB_PID}" ]] && kill -0 "${XVFB_PID}" 2>/dev/null; then
    kill "${XVFB_PID}" 2>/dev/null || true
    wait "${XVFB_PID}" 2>/dev/null || true
  fi
  rm -rf "${TMP_ROOT}"
}

trap cleanup EXIT

if [[ ! -f "${HTML_FILE}" ]]; then
  echo "Missing input HTML: ${HTML_FILE}" >&2
  exit 1
fi

echo "Starting virtual display on ${DISPLAY_NUM}..."
Xvfb "${DISPLAY_NUM}" -screen 0 1920x1080x24 -nolisten tcp >"${TMP_ROOT}/xvfb.log" 2>&1 &
XVFB_PID=$!
sleep 1

echo "Launching Chrome presenter..."
DISPLAY="${DISPLAY_NUM}" /usr/local/bin/google-chrome \
  --no-first-run \
  --disable-background-networking \
  --disable-extensions \
  --disable-renderer-backgrounding \
  --disable-dev-shm-usage \
  --autoplay-policy=no-user-gesture-required \
  --start-fullscreen \
  --window-size=1920,1080 \
  --window-position=0,0 \
  --user-data-dir="${TMP_ROOT}/chrome-profile" \
  --app="file://${HTML_FILE}" >"${TMP_ROOT}/chrome.log" 2>&1 &
CHROME_PID=$!

sleep 2

echo "Recording MP4..."
DISPLAY="${DISPLAY_NUM}" ffmpeg -y \
  -f x11grab \
  -video_size 1920x1080 \
  -framerate 30 \
  -i "${DISPLAY_NUM}" \
  -t 30 \
  -an \
  -c:v libx264 \
  -preset veryfast \
  -crf 20 \
  -pix_fmt yuv420p \
  "${OUTPUT_FILE}"

echo "Saved video to ${OUTPUT_FILE}"
