#!/usr/bin/env bash
# 把一個新的子專案加入 LenFirstWeb workspace。
#
# 用法：
#   ./add-subproject.sh <slug> <git-url>
#
# 例：
#   ./add-subproject.sh notes https://github.com/HandsomeGod0516/lenbot-notes.git

set -euo pipefail

SLUG="${1:-}"
URL="${2:-}"

if [ -z "$SLUG" ] || [ -z "$URL" ]; then
  echo "用法：$0 <slug> <git-url>" >&2
  exit 1
fi

if [ -e "$SLUG" ]; then
  echo "已存在資料夾 ./$SLUG — 取消" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

git submodule add "$URL" "$SLUG"
git commit -m "add: $SLUG submodule" -- .gitmodules "$SLUG"

echo
echo "✓ $SLUG 加入完成。下次 portal-main 跑 dev server，Vite glob 會自動掃到它的 App.vue。"
echo "  若要推到 super-repo origin：git push"
