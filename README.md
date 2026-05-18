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
├── wishlist/               → 子專案：願望清單 (/projects/wishlist)
└── infra-docker/           → MySQL 8 + Nginx + cloudflared 設定
```

| Submodule | GitHub repo |
|---|---|
| `portal-main`  | [`lenbot-portal-main`](https://github.com/HandsomeGod0516/lenbot-portal-main) |
| `portal`       | [`lenbot-portal`](https://github.com/HandsomeGod0516/lenbot-portal) |
| `dudu`         | [`lenbot-dudu`](https://github.com/HandsomeGod0516/lenbot-dudu) |
| `fitness`      | [`lenbot-fitness`](https://github.com/HandsomeGod0516/lenbot-fitness) |
| `wishlist`     | [`lenbot-wishlist`](https://github.com/HandsomeGod0516/lenbot-wishlist) |
| `infra-docker` | [`lenbot-infra`](https://github.com/HandsomeGod0516/lenbot-infra) |

子專案約定俗成放 `App.vue`，被 `portal-main/composables/useProjectComponents.ts` 用 `import.meta.glob('../../*/App.vue')` 自動掃進來，掛在 `/projects/<slug>` 路由下。

每個子專案同時是一個獨立的 **Vue + Vite + TS** 專案（有自己的 `package.json` / `vite.config.ts` / `tsconfig.json`），可以單獨 `cd <slug> && npm run dev` 拉起來預覽，不需要先把 portal-main 跑起來。詳見下方「[子專案 standalone 開發](#子專案-standalone-開發)」。

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

如果想讓新子專案也能 standalone 跑(`cd notes && npm run dev`),最快的做法是從 `dudu/` 把這組檔複製過去再改 `package.json` 的 `name` 跟 `vite.config.ts` 的 `port`:`package.json` / `tsconfig.json` / `tsconfig.node.json` / `vite.config.ts` / `index.html` / `main.ts` / `env.d.ts` / `host.css` / `.gitignore`。詳細見「[子專案 standalone 開發](#子專案-standalone-開發)」。

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

### 改子專案 (portal / dudu / fitness / wishlist / 任何 lenbot-*)

兩種模式擇一,通常 UI 迭代用 standalone (快),整合測試用 embedded:

```bash
# A) standalone — 純 UI 預覽,不需要 portal-main / DB / Ollama
cd portal
npm install                # 第一次
npm run dev                # → http://localhost:5183 (見下表)

# B) embedded — 走 portal-main，有完整 auth/API/session
cd portal-main
npm run dev                # → http://localhost:3000/projects/portal

# 滿意 → 在子專案內推自己的 repo
cd portal
git add -A && git commit -m "..." && git push

# production 需要重 build portal-main：
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

## 子專案 standalone 開發

每個子專案資料夾自己就是一個能跑的 Vue + Vite + TS 專案,**`App.vue` 不需要任何改動**就能切換兩種模式:

| 模式 | 怎麼跑 | URL | 用途 |
|---|---|---|---|
| Standalone | `cd <slug> && npm run dev` | 見下表 | 只看 UI、快迭代,不需要 portal-main / DB / Ollama |
| Embedded | `cd portal-main && npm run dev` | `http://localhost:3000/projects/<slug>` | 真實環境,有 auth/API/SSE |

### Standalone 預設 port

| 子專案 | Port |
|---|---|
| dudu | 5180 |
| fitness | 5181 |
| wishlist | 5182 |
| portal | 5183 |
| portal-main (embedded host) | 3000 |

### 內部運作

每個子專案資料夾長這樣:

```
<slug>/
├── App.vue          ← 唯一被 portal-main glob 載入的檔
├── main.ts          ← standalone 入口 (只在 npm run dev 時用)
├── index.html       ← standalone 入口頁
├── host.css         ← standalone 的 design tokens + body 背景
├── vite.config.ts
├── tsconfig.json
└── package.json     ← vue 列 peerDependency,版本要跟 portal-main 同步
```

- **`host.css`** 是 portal-main `assets/css/main.css` 的 `:root` token 區塊的手動複製,只有 `main.ts` 會 import,所以**embed 進 portal-main 時不會載入**,production bundle 不會被污染。
- token 是複製不是引用,改 portal-main 的色票時要記得同步進每個 `host.css`。

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
