# LenFirstWeb

`https://lenbotai.com` 的整套 source。Mac 同時當 server，Cloudflare Tunnel 對外。每個子專案各自獨立 git repo，這個 super-repo 用 **git submodules** 把它們收編在一個工作區裡。

```
Internet → Cloudflare (TLS) → Cloudflare Tunnel → Mac → Nuxt :3000 → MySQL / Ollama
```

---

## 目錄結構

```
LenFirstWeb/                ← super-repo (這個 repo)
├── .env                    ← 集中管理的環境變數 (gitignored)
├── add-subproject.sh       ← 一行加新 submodule
├── portal-main/            → 入口 Nuxt app + 所有 API
├── portal/                 → 子專案：Ollama 聊天 (/projects/portal)
├── dudu/                   → 子專案：placeholder (/projects/dudu)
├── fitness/                → 子專案：健身紀錄 (/projects/fitness)
└── infra-docker/           → MySQL 8 + Nginx + cloudflared 設定
```

| Submodule | GitHub repo |
|---|---|
| `portal-main`  | [`lenbot-portal-main`](https://github.com/HandsomeGod0516/lenbot-portal-main) |
| `portal`       | [`lenbot-portal`](https://github.com/HandsomeGod0516/lenbot-portal) |
| `dudu`         | [`lenbot-dudu`](https://github.com/HandsomeGod0516/lenbot-dudu) |
| `fitness`      | [`lenbot-fitness`](https://github.com/HandsomeGod0516/lenbot-fitness) |
| `infra-docker` | [`lenbot-infra`](https://github.com/HandsomeGod0516/lenbot-infra) |

子專案約定俗成放 `App.vue`，被 `portal-main/composables/useProjectComponents.ts` 用 `import.meta.glob('../../*/App.vue')` 自動掃進來，掛在 `/projects/<slug>` 路由下。

---

## 第一次 clone

```bash
git clone --recurse-submodules https://github.com/HandsomeGod0516/LenFirstWeb.git
cd LenFirstWeb
cp .env.example .env       # 編輯填 DB 密碼、SESSION_SECRET、SMTP…
```

或 clone 完才補：

```bash
git clone https://github.com/HandsomeGod0516/LenFirstWeb.git
cd LenFirstWeb
git submodule update --init --recursive
```

---

## 環境變數 (`.env` 集中管理)

整個 workspace 共用**一份** `LenFirstWeb/.env`。`portal-main/.env` 與 `infra-docker/.env` 都是 symlink 到 `../.env`，不要直接編輯它們。

```
LenFirstWeb/
├── .env                       ← 改這份
├── portal-main/.env  -> ../.env
└── infra-docker/.env -> ../.env
```

範本見 `.env.example`。

---

## 拉所有子專案最新版

```bash
git submodule update --remote --merge
```

把每個 submodule 拉到各自 default branch (main) 最新；想把版本釘住就 `git add . && git commit`。

---

## 加新子專案 (一行)

```bash
./add-subproject.sh notes https://github.com/HandsomeGod0516/lenbot-notes.git
```

新子專案的 `App.vue` 一進來就會被 portal-main 的 Vite glob 掃到，掛在 `/projects/notes`。

---

## 每天日常開機 / 關機

整套東西由兩個東西管：**Docker Desktop** (MySQL) 跟 **pm2** (Nuxt + Cloudflare Tunnel)。

### 開機後

```bash
# 1. 確保 Docker Desktop 跑著
open -a Docker

# 2. 起 MySQL 容器
cd /Users/len/Desktop/LenFirstWeb/infra-docker
./start.sh

# 3. Nuxt + Cloudflare Tunnel
pm2 resurrect
```

> 如果做過 `pm2 startup`，第 3 步不用做 — 重開機就會自動 resurrect。

打開瀏覽器：`https://lenbotai.com` 應該秒開。

### 暫停服務

```bash
pm2 stop all
docker compose -f infra-docker/docker-compose.yml stop
```

---

## 常用工作流

### 改 portal-main → 推 production

```bash
cd portal-main
pm2 stop portal-main       # 暫停 production
npm run dev                # localhost:3000，邊改邊看

# 滿意 → push
git add -A && git commit -m "feat: ..." && git push

# 回 production
npm run build && pm2 restart portal-main
```

### 改子專案 (portal / dudu / fitness / 任何 lenbot-*)

```bash
cd portal
# 直接改 App.vue
git add -A && git commit -m "..." && git push

# dev mode 直接 HMR；production 需要：
cd ../portal-main && npm run build && pm2 restart portal-main
```

### 重灌 schema / 重設 admin / 從零裝 DB

```bash
cd portal-main
npm run db:init     # 清掉所有 user/projects/messages，重灌
```

### 看 logs

```bash
pm2 logs portal-main --lines 50
pm2 logs cloudflared-tunnel --lines 50
pm2 monit
docker compose -f infra-docker/docker-compose.yml logs -f mysql
```

### 緊急下線

```bash
pm2 stop cloudflared-tunnel    # 對外不可訪問 (Mac 內仍可)
# 或
pm2 stop portal-main           # Nuxt 直接停 (lenbotai.com 會 502)
```

---

## 第一次部署到別台 Mac

```bash
# 1. clone
git clone --recurse-submodules https://github.com/HandsomeGod0516/LenFirstWeb.git
cd LenFirstWeb
cp .env.example .env       # 編輯：DB 密碼、SESSION_SECRET (openssl rand -hex 32)

# 2. 起 MySQL
cd infra-docker && ./start.sh

# 3. portal-main
cd ../portal-main
npm install
npm run db:init            # 灌 schema + admin/admin123
npm run build
pm2 start "npm start" --name portal-main

# 4. Cloudflare Tunnel
brew install cloudflared
cloudflared tunnel login
cloudflared tunnel create lenbot
cloudflared tunnel route dns lenbot lenbotai.com
cloudflared tunnel route dns lenbot www.lenbotai.com
mkdir -p ~/.cloudflared
cp ../infra-docker/cloudflared/config.example.yml ~/.cloudflared/config.yml
# 編輯把 <UUID> 兩處替換掉
pm2 start cloudflared --name cloudflared-tunnel -- tunnel run lenbot
pm2 save
```

詳細部署步驟見 [`infra-docker/DEPLOY.md`](./infra-docker/DEPLOY.md)。

---

## 設定開機自動啟動 (建議一次性)

```bash
pm2 startup
# 跑它印出的 sudo env PATH=... 指令
```

之後重開機 pm2 process 會自動 resurrect。

---

## 帳號 / 預設值

| 項目 | 值 |
|---|---|
| Admin 帳號 | `admin` |
| 預設密碼 | `admin123` (第一次登入會被強制改) |
| MySQL root 密碼 | `.env` 的 `MYSQL_ROOT_PASSWORD` |
| Nuxt session secret | `.env` 的 `SESSION_SECRET` (64 字元 hex) |
| 公網網址 | `https://lenbotai.com` / `https://www.lenbotai.com` |
| 本機開發 | `http://localhost:3000` (用 `localhost`，**不要** `127.0.0.1` — 後者會被 Vite HMR 攔截回 426) |

---

## Sub-system 一覽

### portal-main (Nuxt 3)
- Auth：簽章 cookie session (HMAC-SHA256 + SESSION_SECRET)
- API：`/api/auth/*`, `/api/projects`, `/api/users`, `/api/agent/chat` (SSE), `/api/admin/*`, `/api/fitness/*`
- Pages：`/login`, `/change-password`, `/`（專案列表）, `/projects/[slug]`（動態載子專案）
- LLM：本機 Ollama，統一 `gemma4:31b` 跑文字/圖片/摘要

### infra-docker (Docker Compose)
- MySQL 8 (linux/arm64)，loopback `127.0.0.1:3306`
- Nginx 80/443 (cloudflared 上線後可 stop)
- 持久化 volume `lenbot_mysql_data`

### cloudflared (Cloudflare Tunnel)
- 設定檔：`~/.cloudflared/config.yml`
- 憑證：`~/.cloudflared/cert.pem` + `~/.cloudflared/<UUID>.json`
- Tunnel name: `lenbot`

---

## 故障排除

| 症狀 | 第一個檢查 |
|---|---|
| lenbotai.com 是 Cloudflare error 1033 | `pm2 logs cloudflared-tunnel` 看 tunnel 連上邊緣沒 |
| lenbotai.com 是 502/525 | `pm2 status portal-main`；`curl http://localhost:3000` 應該 302 |
| 登入失敗 | `pm2 logs portal-main`；MySQL 密碼變過？|
| Ollama 沒回應 | `pm2 logs portal-main` + `curl http://localhost:11434/api/tags` |
| Git push 被拒 | `gh auth status` 看 token |
