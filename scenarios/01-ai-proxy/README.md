# シナリオ 01: AI Proxy Advanced — Consumer キーによる LLM ルーティング

同一エンドポイント `POST /ai/chat` に対し、Consumer キーだけで転送先 LLM を切り替えます。  
LLM の API キーは Kong 側のプラグイン設定で一元管理し、Consumer 側には一切持たせません。

```
POST /ai/chat
  apikey: KONG_API_KEY    → Kong → (OPENAI_API_KEY)  → OpenAI  GPT-4o-mini
  apikey: KONG_GEMINI_KEY → Kong → (GEMINI_API_KEY)  → Gemini  2.0 Flash
```

**責務の分離**

| 何を知っているか | demo-user | gemini-user | Kong |
|----------------|:---------:|:-----------:|:----:|
| 自分の Consumer キー | ✓ | ✓ | ✓ |
| OpenAI API キー | ✗ | ✗ | ✓ |
| Gemini API キー | ✗ | ✗ | ✓ |

**使用プラグイン**

| プラグイン | 役割 |
|-----------|------|
| `ai-proxy-advanced` | LLM へのプロキシ。Consumer スコープで転送先を切り替え。 |
| `key-auth` | Consumer キーによるクライアント認証 |

---

## 仕組み: Kong のプラグインスコープ

Kong のプラグインは **スコープ (適用範囲) の組み合わせ**で動作します。  
スコープが詳細なほど優先度が高くなります。

```
優先度 高 │ Consumer + Service/Route スコープ
          │ Consumer スコープのみ
          │ Route スコープのみ
優先度 低 │ Service スコープのみ
```

このシナリオでの設定:

| プラグインインスタンス | スコープ | 適用される Consumer |
|----------------------|---------|-------------------|
| `ai-proxy-advanced` (OpenAI) | Service のみ | 全 Consumer (デフォルト) |
| `ai-proxy-advanced` (Gemini) | Service + `gemini-user` | `gemini-user` のみ |

`gemini-user` からのリクエストには Consumer+Service スコープのプラグイン (Gemini) が優先されるため、  
デフォルトの OpenAI プラグインは実質 `demo-user` 専用として機能します。

---

## 事前準備: 環境変数の設定

`.env` に以下を設定してください。

```bash
# OpenAI API キー
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxx

# Google AI (Gemini) API キー — https://aistudio.google.com/apikey で発行
GEMINI_API_KEY=AIzaxxxxxxxxxx

# Kong Consumer キー (Kong が発行する任意の文字列)
KONG_API_KEY=my-openai-user-key
KONG_GEMINI_KEY=my-gemini-user-key
```

---

## Step 1: デプロイ

```bash
# 環境変数を export してから envsubst で展開した YAML を sync する
set -a; source .env; set +a

envsubst < ./scenarios/01-ai-proxy/deck.yaml \
  | deck gateway sync /dev/stdin \
      --konnect-token "$KONNECT_TOKEN" \
      --konnect-control-plane-name "$KONNECT_CONTROL_PLANE_NAME"
```

> **Note:** `deck` は `deck.yaml` 内の `${...}` を自動展開しません。  
> `envsubst` で事前に展開することで API キーや Consumer キーを正しく Kong に登録します。

`Summary: { create: X, update: 0, delete: 0 }` と表示されれば成功です。

---

## Step 2: テスト実行

```bash
bash ./scenarios/01-ai-proxy/test.sh
```

### 期待される出力

```
=== テスト 1: demo-user → OpenAI (POST /ai/chat) ===
{"id":"chatcmpl-...","object":"chat.completion","model":"gpt-4o-mini","choices":[{"message":{"role":"assistant","content":"Kongは..."}}],"usage":{...}}

=== テスト 2: gemini-user → Gemini (同じ POST /ai/chat) ===
{"id":"...","object":"chat.completion","model":"gemini-2.5-flash","choices":[{"message":{"role":"assistant","content":"Kongは..."}}],"usage":{...}}

=== テスト 3: 認証キーなし → 401 ===
{"message":"Unauthorized","request_id":"..."}

=== テスト 4: 誤った認証キー → 401 ===
{"message":"Unauthorized","request_id":"..."}
```

**確認ポイント:**
- テスト 1・2 は **同じ URL、同じリクエストボディ**。`apikey` ヘッダーの値だけが異なる
- テスト 1 のレスポンス内 `"model"` が `"gpt-4o-mini"`、テスト 2 が `"gemini-2.5-flash"` であること
- テスト 3・4 で `{"message":"Unauthorized"}` が返ること

---

## Step 3: 手動で試す

**OpenAI (demo-user)**

```bash
curl -s -X POST "${KONNECT_PROXY_URL}/ai/chat" \
  -H "Content-Type: application/json" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{"messages": [{"role": "user", "content": "Kongとは何か、一文で説明してください。"}]}'
```

**Gemini (gemini-user)**

```bash
curl -s -X POST "${KONNECT_PROXY_URL}/ai/chat" \
  -H "Content-Type: application/json" \
  -H "apikey: ${KONG_GEMINI_KEY}" \
  -d '{"messages": [{"role": "user", "content": "Kongとは何か、一文で説明してください。"}]}'
```

URL・メソッド・ボディはまったく同じ。`apikey` ヘッダーの値だけが異なります。  
リクエスト・レスポンス形式は両方とも OpenAI Chat Completions 互換で統一されており、  
Gemini ネイティブ形式への変換は Kong が透過的に行います。

---

次のシナリオ → [02: AI Rate Limiting](../02-ai-rate-limiting/README.md)
