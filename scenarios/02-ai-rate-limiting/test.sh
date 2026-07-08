#!/usr/bin/env bash
# シナリオ 2 — AI Rate Limiting の動作確認
# 使い方: set -a; source .env; set +a && bash test.sh
set -euo pipefail

: "${KONNECT_PROXY_URL:?'.env に KONNECT_PROXY_URL を設定してください'}"
: "${KONG_API_KEY:?'.env に KONG_API_KEY を設定してください'}"

BASE_URL="${KONNECT_PROXY_URL}/ai/chat"

echo "=== テスト 1: 単発リクエスト + レート制限ヘッダーの確認 ==="
echo "レスポンスヘッダーに X-Kong-AI-* が含まれることを確認します"
curl -si -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{"messages": [{"role": "user", "content": "一文で答えてください: Kongとは？"}]}'

echo ""
echo "=== テスト 2: 繰り返しリクエストでレート制限を確認 ==="
echo "制限: 1分間 2,000 トークン。超過すると 429 が返ります。"
for i in $(seq 1 6); do
  echo ""
  echo "--- リクエスト $i ---"
  curl -s -X POST "$BASE_URL" \
    -H "Content-Type: application/json" \
    -H "apikey: ${KONG_API_KEY}" \
    -d '{"messages": [{"role": "user", "content": "Kubernetesについて500字で詳しく説明してください。"}]}'
  echo ""
  sleep 0.5
done
