#!/usr/bin/env bash
# シナリオ 1 — Consumer キーによる LLM ルーティングの動作確認
# 使い方: set -a; source .env; set +a && bash test.sh
set -euo pipefail

: "${KONNECT_PROXY_URL:?'.env に KONNECT_PROXY_URL を設定してください'}"
: "${KONG_API_KEY:?'.env に KONG_API_KEY を設定してください'}"
: "${KONG_GEMINI_KEY:?'.env に KONG_GEMINI_KEY を設定してください'}"

BASE_URL="${KONNECT_PROXY_URL}/ai/chat"

echo "=== テスト 1: demo-user → OpenAI (POST /ai/chat) ==="
curl -s -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{"messages": [{"role": "user", "content": "Kongとは何か、一文で説明してください。"}]}'

echo ""
echo ""
echo "=== テスト 2: gemini-user → Gemini (同じ POST /ai/chat) ==="
curl -s -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -H "apikey: ${KONG_GEMINI_KEY}" \
  -d '{"messages": [{"role": "user", "content": "Kongとは何か、一文で説明してください。"}]}'

echo ""
echo ""
echo "=== テスト 3: 認証キーなし → 401 ==="
curl -s -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "hello"}]}'

echo ""
echo ""
echo "=== テスト 4: 誤った認証キー → 401 ==="
curl -s -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -H "apikey: wrong-key" \
  -d '{"messages": [{"role": "user", "content": "hello"}]}'
echo ""
