# シナリオ 02: AI Rate Limiting — トークンベースのレート制限

LLM の料金はリクエスト数ではなく **消費トークン数** で決まります。  
`ai-rate-limiting-advanced` でトークン単位の制限をかけ、コストの暴走を防ぎます。  
あわせて `ai-proxy-advanced` の `round-robin` で安価なモデルを優先します。

```
クライアント → Kong → OpenAI
                ├── ai-rate-limiting-advanced  (1分 600 トークンまで → 超過で 429)
                └── ai-proxy-advanced          (gpt-4o-mini / gpt-4o)
```

**使用プラグイン**

| プラグイン | 役割 |
|-----------|------|
| `ai-proxy-advanced` | gpt-4o-mini / gpt-4o を round-robin で振り分け |
| `ai-rate-limiting-advanced` | Consumer ごとに 1分間 600 トークンまで |
| `key-auth` | クライアント認証 |

---

## Step 1: デプロイ

```bash
# ルートディレクトリで実行
set -a; source .env; set +a

envsubst < ./scenarios/02-ai-rate-limiting/deck.yaml \
  | deck gateway sync /dev/stdin \
      --konnect-token "$KONNECT_TOKEN" \
      --konnect-control-plane-name "$KONNECT_CONTROL_PLANE_NAME"
```

---

## Step 2: テスト実行

```bash
bash ./scenarios/02-ai-rate-limiting/test.sh
```

### 期待される出力

```
=== テスト 1: 単発リクエスト + レート制限ヘッダーの確認 ===
HTTP/2 200
x-ai-ratelimit-limit-minute-policy-1: 600
x-ai-ratelimit-remaining-minute-policy-1: 558

=== テスト 2: 繰り返しリクエストでレート制限を確認 ===
リクエスト 1: HTTP 200   (274 トークン消費, 残り 326)
リクエスト 2: HTTP 200   (274 トークン消費, 残り 52)
リクエスト 3: HTTP 429   ← 制限超過
リクエスト 4: HTTP 429
リクエスト 5: HTTP 429
リクエスト 6: HTTP 429
```

**確認ポイント:**
- テスト 1 のレスポンスヘッダーに `RateLimit-Remaining` が含まれること
- テスト 2 で途中から `429` に切り替わること（制限値が低いため早めに発生）

> テスト 2 で最後まで `200` が続く場合、直前のテストから 1 分以上経過している可能性があります。  
> もう一度すぐに `bash test.sh` を実行してみてください。

---

## Step 3: 手動で試す

**レート制限ヘッダーを確認する**

`-si` フラグでレスポンスヘッダーも表示します。

```bash
curl -si -X POST "${KONNECT_PROXY_URL}/ai/chat" \
  -H "Content-Type: application/json" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{"messages": [{"role": "user", "content": "Kong Gatewayについて簡潔に説明してください。"}]}' \
  | grep -iE "^(HTTP|x-ai-ratelimit)"
```

出力例:

```
HTTP/2 200
x-ai-ratelimit-limit-minute-policy-1: 600
x-ai-ratelimit-remaining-minute-policy-1: 556
```

**制限超過のメッセージを確認する**

上記コマンドを数回繰り返すと `429` になります。ボディを確認してみてください。

```bash
curl -s -X POST "${KONNECT_PROXY_URL}/ai/chat" \
  -H "Content-Type: application/json" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{"messages": [{"role": "user", "content": "Kong Gatewayについて簡潔に説明してください。"}]}'
```

`429` 時のレスポンス:

```json
{
  "message": "トークンのレート制限を超えました。しばらくしてから再試行してください。"
}
```

**1 分待ってリセットを確認する**

`RateLimit-Reset` の秒数待ってから再リクエストすると `200` に戻ります。

---

## 解説

### なぜリクエスト数でなくトークン数で制限するのか

LLM の料金はトークン単位で課金されます。リクエスト数が少なくても、  
1 件あたりのトークンが多ければコストは跳ね上がります。  
`ai-rate-limiting-advanced` はレスポンスの `usage.total_tokens` を見てカウントするため、  
実際のコストに比例した制限が可能です。

### `round-robin` でコストを抑える

`deck.yaml` の `balancer` 設定:

```yaml
balancer:
  algorithm: round-robin
  tokens_count_strategy: total_tokens
```

gpt-4o-mini と gpt-4o を round-robin で振り分けます。  
高品質モデルは使いたいが、コストは抑えたい場合の典型的な構成です。

### `sliding` ウィンドウとは

`window_type: sliding` は「現在時刻から過去 1 分間」を常に計測します。  
毎分 0 秒にリセットされる `fixed` と異なり、バースト（瞬間的な大量送信）を防げます。

---

次のシナリオ → [03: Prompt Guard](../03-prompt-guard/README.md)
