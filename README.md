# LenFirstWeb

lenbot workspace — `portal-main` 當入口網頁 + API hub，其他子專案以 git submodule 形式掛進來。Vite glob (`import.meta.glob('../../*/App.vue')`) 會自動把同層每個子專案的 `App.vue` 收進 portal-main 的 projects 路由。

## 目錄結構

```
LenFirstWeb/            ← super-repo (這個 repo)
├── portal-main/        → lenbot-portal-main (Nuxt app, 入口 + API)
├── portal/             → lenbot-portal      (聊天介面)
├── dudu/               → lenbot-dudu
├── fitness/            → lenbot-fitness
└── infra-docker/       → lenbot-infra       (MySQL / Nginx / Cloudflared)
```

每個子資料夾都是獨立 git repo。super-repo 只記住「每個 submodule 釘在哪個 commit」。

## Clone

```bash
git clone --recurse-submodules https://github.com/HandsomeGod0516/LenFirstWeb.git
```

或者 clone 後再補：

```bash
git clone https://github.com/HandsomeGod0516/LenFirstWeb.git
cd LenFirstWeb
git submodule update --init --recursive
```

## 拉所有子專案的最新版

```bash
git submodule update --remote --merge
```

(把每個 submodule 拉到各自 default branch 的最新；想釘住版本就 commit super-repo)

## 加新子專案

```bash
./add-subproject.sh <slug> <git-url>
```

例如：

```bash
./add-subproject.sh notes https://github.com/HandsomeGod0516/lenbot-notes.git
```

腳本會跑 `git submodule add` 並自動 commit。子專案的 `App.vue` 一加進去就會被 portal-main 的 Vite glob 掃到。

## 開發

```bash
cd infra-docker && docker compose up -d        # 起 MySQL/Nginx
cd ../portal-main && npm install && npm run dev   # 起入口 (port 3000)
```
