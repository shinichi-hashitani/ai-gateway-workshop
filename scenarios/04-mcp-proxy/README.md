# シナリオ 04: MCP Proxy — MCP サーバーへのゲートウェイ

Model Context Protocol (MCP) サーバーを Kong 経由で公開します。  
AI エージェントやクライアントは Kong のエンドポイントに接続し、Kong が認証とアクセス制御を担います。

```
AI クライアント/エージェント
       │  MCP (Streamable HTTP / JSON-RPC 2.0)
       ▼
  Kong Gateway
  ├── key-auth   (クライアント認証)
  └── mcp-proxy  (MCP プロトコル処理)
       │
       ▼
  MCP Server (外部)
```

**使用プラグイン**

| プラグイン | 役割 |
|-----------|------|
| `mcp-proxy` | MCP Streamable HTTP プロトコルの透過プロキシ |
| `key-auth` | クライアント認証 |

---

## 前提: MCP サーバーの用意

このシナリオには接続先の MCP サーバーが必要です。

### オプション A: ローカルで MCP サーバーを起動する（推奨）

別のターミナルで以下を実行します（Node.js が必要）。

```bash
npx -y @modelcontextprotocol/server-everything
# デフォルトで http://localhost:3000 で起動します
```

Konnect Serverless ゲートウェイはクラウドからリクエストを送るため、  
ローカルサーバーには **ngrok** などのトンネリングツールが必要です。

```bash
ngrok http 3000
# "Forwarding: https://xxxx.ngrok-free.app -> http://localhost:3000" が表示される
```

表示された `https://xxxx.ngrok-free.app` を `.env` の `MCP_SERVER_URL` に設定してください。

### オプション B: ホスト型 MCP サービスを使う

[mcp.run](https://mcp.run) や [Smithery](https://smithery.ai) の Streamable HTTP エンドポイント URL を  
そのまま `MCP_SERVER_URL` に設定できます。

---

## Step 1: デプロイ

```bash
# ルートディレクトリで実行
set -a; source .env; set +a

envsubst < ./scenarios/04-mcp-proxy/deck.yaml \
  | deck gateway sync /dev/stdin \
      --konnect-token "$KONNECT_TOKEN" \
      --konnect-control-plane-name "$KONNECT_CONTROL_PLANE_NAME"
```

---

## Step 2: テスト実行

```bash
bash ./scenarios/04-mcp-proxy/test.sh
```

### 期待される出力

```
=== テスト 1: MCP initialize — サーバー情報の取得 ===
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2025-03-26",
    "serverInfo": { "name": "example-server", "version": "1.0.0" },
    "capabilities": { "tools": {} }
  }
}

=== テスト 2: tools/list — 利用可能なツール一覧 ===
"get_current_time"
"fetch_weather"
...

=== テスト 3: 認証なしのアクセス → 401 でブロック ===
HTTP Status: 401

=== テスト 4: 誤った認証キー → 401 でブロック ===
HTTP Status: 401
```

**確認ポイント:**
- テスト 1 で MCP サーバーの情報が返ること
- テスト 2 でツール名の一覧が返ること
- テスト 3・4 で `401` が返ること（Kong の key-auth が機能している）

---

## Step 3: 手動で試す

### MCP セッションの開始 (initialize)

```bash
curl -s -X POST "${KONNECT_PROXY_URL}/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-03-26",
      "capabilities": {},
      "clientInfo": { "name": "workshop-client", "version": "1.0" }
    }
  }' | jq .
```

### 利用可能なツールを確認する

```bash
curl -s -X POST "${KONNECT_PROXY_URL}/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}' \
  | jq '.result.tools[] | {name, description}'
```

### ツールを実行する (tools/call)

`tools/list` で確認したツール名を使って実行します。  
（以下は `@modelcontextprotocol/server-everything` の例）

```bash
curl -s -X POST "${KONNECT_PROXY_URL}/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "apikey: ${KONG_API_KEY}" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "get_current_time",
      "arguments": { "timezone": "Asia/Tokyo" }
    }
  }' | jq '.result'
```

### 認証なしでアクセスしてみる（Kong がブロックすることを確認）

```bash
curl -s -X POST "${KONNECT_PROXY_URL}/mcp" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}' \
  | jq .
```

MCP サーバーではなく Kong が `401 Unauthorized` を返します。  
MCP サーバーは外部に露出せず、Kong の認証を通過したリクエストだけが届きます。

---

## Claude Desktop から接続する（オプション）

Claude Desktop に Kong の MCP エンドポイントを登録すると、  
Claude が Kong 経由で MCP ツールを使えるようになります。

`~/Library/Application Support/Claude/claude_desktop_config.json` を編集:

```json
{
  "mcpServers": {
    "kong-mcp-gateway": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://<your-proxy-url>/mcp"],
      "env": {
        "HEADER_apikey": "<your-kong-api-key>"
      }
    }
  }
}
```

> `mcp-remote` は HTTP ベースの MCP サーバーに stdio から接続するブリッジツールです。  
> `npm install -g mcp-remote` でインストールできます。

---

## 解説

### MCP プロトコルの基本

MCP は JSON-RPC 2.0 をベースにしており、主に以下のメソッドを使います。

| メソッド | 説明 |
|---------|------|
| `initialize` | セッション開始・プロトコルバージョンのネゴシエーション |
| `tools/list` | サーバーが提供するツールの一覧取得 |
| `tools/call` | ツールを引数付きで実行 |
| `resources/list` | サーバーが提供するリソースの一覧 |

### Kong MCP Proxy の価値

MCP サーバーを直接公開するのと、Kong 経由で公開するのでは何が違うのか？

| 課題 | Kong MCP Proxy による対応 |
|------|--------------------------|
| 認証なしで誰でも接続できてしまう | `key-auth` で API キー認証 |
| 特定クライアントのアクセスを止めたい | Consumer を無効化するだけでよい |
| ツール呼び出しの頻度を制限したい | `rate-limiting` プラグインを追加 |
| アクセスログを残したい | `file-log` / `http-log` プラグインで一元管理 |
| 複数の MCP サーバーを 1 エンドポイントに集約したい | Kong の upstream 機能で対応可能 |
