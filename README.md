# Kong Konnect AI Gateway ハンズオン

Kong Konnect の Serverless ゲートウェイを使って AI Gateway の主要機能を体験するワークショップです。

## シナリオ一覧

| # | テーマ | 使用プラグイン | 所要時間 |
|---|--------|--------------|---------|
| [01](./scenarios/01-ai-proxy/) | AI Proxy — 基本的な LLM プロキシ | `ai-proxy-advanced`, `key-auth` | 約 10 分 |
| [02](./scenarios/02-ai-rate-limiting/) | AI Rate Limiting — トークンベース制限 | `ai-rate-limiting-advanced` | 約 15 分 |
| [03](./scenarios/03-prompt-guard/) | Prompt Guard — プロンプトセキュリティ | `ai-prompt-guard`, `ai-prompt-decorator` | 約 20 分 |
| [04](./scenarios/04-mcp-proxy/) | MCP Proxy — MCP ゲートウェイ | `mcp-proxy` | 約 15 分 |

各シナリオは独立して実行できます。前のシナリオから続けて進めることも可能です。

---

## 事前準備

### 1. 必要なツールの確認

以下のコマンドでバージョンを確認してください。

```bash
deck version    # 1.40 以上が必要
curl --version
jq --version    # テストスクリプトで使用
```

> `jq` が入っていない場合:  
> macOS: `brew install jq` / Linux: `apt install jq` / Windows: https://jqlang.github.io/jq/download/

`deck` のインストールは https://docs.konghq.com/deck/latest/installation/ を参照してください。

### 2. 必要なアカウント・APIキー

- **Kong Konnect アカウント** — https://konghq.com/products/kong-konnect (Free Tier で可)
- **OpenAI API キー** — https://platform.openai.com/api-keys

### 3. Konnect の設定値を手元に用意する

| 値 | 確認場所 |
|----|---------|
| `KONNECT_TOKEN` | Konnect コンソール → 右上アバター → **Personal Access Tokens** → **Generate Token** |
| `KONNECT_CONTROL_PLANE_NAME` | **Gateway Manager** → Control Planes 一覧に表示されるコントロールプレーン名 |
| `KONNECT_PROXY_URL` | Gateway Manager → 対象 CP → **Gateway Services** → Serverless のプロキシ URL |

---

## 環境セットアップ

### Step 1: リポジトリのクローン

```bash
git clone <this-repo-url>
cd ai-gateway-workshop
```

### Step 2: `.env` ファイルの作成

```bash
cp .env.example .env
```

テキストエディタで `.env` を開き、各値を記入します。

```bash
# .env の記入例
KONNECT_TOKEN=kpat_xxxxxxxxxxxx
KONNECT_CONTROL_PLANE_NAME=default
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxx
KONNECT_PROXY_URL=https://xxxxxxxxxx.us.serverless.konghq.com
KONG_API_KEY=workshop-key-2024          # 任意の文字列を設定
```

> **重要**: `.env` は `.gitignore` により Git 管理対象外です。  
> 誤ってコミットしないよう、`git status` で `.env` が表示されないことを確認してください。

### Step 3: Konnect への接続確認

```bash
source .env

deck gateway ping \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name "$KONNECT_CONTROL_PLANE_NAME"
```

以下のように表示されれば準備完了です。

```
Successfully Konnected to the Kong organization!
```

---

## テスト結果の読み方

各シナリオの `test.sh` はリクエストの結果を以下の形式で表示します。

```
--- テスト X: <説明> ---
✓ PASSED  (HTTP 200): <AIの回答の冒頭>
✓ BLOCKED (HTTP 400): <Kongが返したエラーメッセージ>
```

| 表示 | 意味 |
|------|------|
| `✓ PASSED  (HTTP 200)` | リクエストが Kong を通過し、LLM が応答した |
| `✓ BLOCKED (HTTP 400)` | Kong がリクエストをブロックした (Prompt Guard など) |
| `HTTP Status: 401` | 認証失敗 (key-auth) |
| `HTTP Status: 429` | レート制限超過 (ai-rate-limiting-advanced) |

---

## 各シナリオの実行方法

ルートディレクトリで `.env` を export してから、各シナリオの手順に従ってください。

```bash
set -a; source .env; set +a
```

> **Note:** `deck` は `deck.yaml` 内の `${...}` を自動展開しません。  
> 各シナリオの sync コマンドは `envsubst` で事前展開してから送信します。

あとは各シナリオの `README.md` の手順に従ってください。

---

## クリーンアップ

ワークショップ終了後、Konnect 上の設定を全削除する場合:

```bash
deck gateway reset \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name "$KONNECT_CONTROL_PLANE_NAME"
# 確認プロンプトが表示されます
```

---

## トラブルシューティング

**`deck gateway ping` が失敗する**
→ `KONNECT_TOKEN` の値と有効期限を確認してください。トークンは Konnect コンソールで再生成できます。

**`deck gateway sync` でエラーが出る**
→ `KONNECT_CONTROL_PLANE_NAME` が正確か確認してください（大文字小文字を含む完全一致）。

**curl で `Connection refused` または タイムアウトが出る**
→ `KONNECT_PROXY_URL` の末尾にスラッシュが含まれていないか確認してください。

**LLM から `401 Unauthorized` が返る**
→ `OPENAI_API_KEY` の値と、OpenAI アカウントの残高を確認してください。
