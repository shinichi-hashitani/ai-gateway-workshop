#!/usr/bin/env bash
# シナリオ 4 — MCP Proxy の動作確認
# 使い方: set -a; source .env; set +a && bash test.sh
set -euo pipefail

: "${KONNECT_PROXY_URL:?'.env に KONNECT_PROXY_URL を設定してください'}"
: "${KONG_API_KEY:?'.env に KONG_API_KEY を設定してください'}"

MCP_URL="${KONNECT_PROXY_URL}/mcp"

echo "=== テスト 1: MCP initialize — サーバー情報の取得 ==="
curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-03-26",
      "capabilities": {
        "roots": {"listChanged": true},
        "sampling": {}
      },
      "clientInfo": {
        "name": "kong-mcp-demo",
        "version": "1.0.0"
      }
    }
  }'

echo ""
echo ""
echo "=== テスト 2: tools/list — 利用可能なツール一覧 ==="
curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list",
    "params": {}
  }'

echo ""
echo ""
echo "=== テスト 3: 認証なしのアクセス → 401 でブロック ==="
curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'

echo ""
echo ""
echo "=== テスト 4: 誤った認証キー → 401 でブロック ==="
curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "apikey: wrong-key" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
echo ""
