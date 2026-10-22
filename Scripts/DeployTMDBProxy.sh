#!/usr/bin/env bash
# Deploy the free Cloudflare Worker that reverse proxies TMDB.
#
# Usage:
#   Scripts/DeployTMDBProxy.sh
#
# The script reuses TMDB_READ_ACCESS_TOKEN from Secrets.xcconfig so you only
# maintain the token in one place.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROXY_DIR="$ROOT_DIR/server/tmdb-proxy"
SECRETS_FILE="$ROOT_DIR/Secrets.xcconfig"

cd "$PROXY_DIR"

if ! command -v npx >/dev/null 2>&1; then
  echo "需要 Node.js / npx，请先安装 Node 18+。" >&2
  exit 1
fi

if [ ! -d node_modules ]; then
  echo "==> 安装 wrangler"
  npm install
fi

# Prefer a scoped API token over the browser OAuth flow: `wrangler login`
# needs a localhost callback and fails behind proxies.
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && [ -f "$PROXY_DIR/.cf_token" ]; then
  CLOUDFLARE_API_TOKEN="$(tr -d '\r\n' < "$PROXY_DIR/.cf_token")"
  export CLOUDFLARE_API_TOKEN
  echo "==> 使用 server/tmdb-proxy/.cf_token"
fi

if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
  npx wrangler whoami >/dev/null 2>&1 || {
    echo "API token 无效或权限不足，请检查 Workers Scripts:Edit。" >&2
    exit 1
  }
else
  if ! npx wrangler whoami >/dev/null 2>&1; then
    echo "==> 需要先登录 Cloudflare（会打开浏览器）"
    npx wrangler login
  fi
fi

TOKEN=""
if [ -f "$SECRETS_FILE" ]; then
  TOKEN="$(grep -E '^[[:space:]]*TMDB_READ_ACCESS_TOKEN[[:space:]]*=' "$SECRETS_FILE" \
    | head -n 1 \
    | sed -E 's/^[^=]*=[[:space:]]*//' \
    | tr -d '"' \
    | tr -d "'" \
    | tr -d '\r' \
    | xargs || true)"
fi

if [ -n "$TOKEN" ]; then
  echo "==> 写入 TMDB_READ_ACCESS_TOKEN（来自 Secrets.xcconfig）"
  printf '%s' "$TOKEN" | npx wrangler secret put TMDB_READ_ACCESS_TOKEN
else
  echo "==> 未在 Secrets.xcconfig 找到 token，请手动粘贴"
  npx wrangler secret put TMDB_READ_ACCESS_TOKEN
fi

echo "==> 部署"
npx wrangler deploy

echo
echo "部署完成后，把下面的地址填进 App 的 设置 → 数据源："
echo "  https://<worker 名称>.<你的子域>.workers.dev/3"
