#!/bin/bash
# 双击本文件即可启动「点墨 · 作文批改台」
# 若双击没反应，请打开「终端」执行（把路径换成实际路径）：
#   bash "/Users/你的用户名/作文批改平台（Teacher_Tony）/启动.command"

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR" || exit 1
SELF="$DIR/启动.command"

say() { echo "  $1"; }
pause_exit() { echo ""; read -r -p "  按回车键关闭窗口…"; exit "${1:-0}"; }

echo ""
echo "  ════════════════════════════════════════════"
echo "   点墨 · 作文批改台"
echo "  ════════════════════════════════════════════"
say "位置：$DIR"
echo ""

# ── 1. 可执行权限（从微信 / U 盘 / Windows 解压过来常会丢）───────────
if [ ! -x "$SELF" ]; then
  chmod +x "$SELF" 2>/dev/null
  say "已修复文件的执行权限。"
fi

# ── 2. 隔离属性（经网络传输的文件会被 macOS 打上，导致无法双击）───────
if command -v xattr >/dev/null 2>&1; then
  if xattr -p com.apple.quarantine "$SELF" >/dev/null 2>&1 \
     || xattr -p com.apple.quarantine "$DIR/server.js" >/dev/null 2>&1; then
    say "检测到 macOS「隔离」标记，正在移除…"
    xattr -dr com.apple.quarantine "$DIR" 2>/dev/null
    say "已移除，以后双击可直接打开。"
  fi
fi

# ── 3. 所在位置是否会被系统隐私保护拦截 ─────────────────────────────
case "$DIR" in
  "$HOME/Desktop"*|"$HOME/Documents"*|"$HOME/Downloads"*)
    say "注意：文件夹在「桌面 / 文稿 / 下载」里，macOS 会要求授权才能读写。"
    say "      首次启动若弹出授权窗口，请点「允许」。"
    say "      若已误点「不允许」，去 系统设置 › 隐私与安全性 › 文件与文件夹，"
    say "      给「终端」勾上对应文件夹；或直接把本文件夹移到个人文件夹下。"
    echo ""
    ;;
esac

# ── 4. 数据目录可写性自检（权限问题的症状都出在这里）─────────────────
mkdir -p "$DIR/data" 2>/dev/null
if ! ( : > "$DIR/data/.write_test" ) 2>/dev/null; then
  echo "  ✗ 无法写入 data 目录 —— 这是权限问题，不是程序出错。"
  echo ""
  echo "    解决办法（任选一种）："
  echo "      1. 把整个「作文批改平台（Teacher_Tony）」文件夹拖到个人文件夹里"
  echo "         （访达 › 前往 › 个人），再重新双击本文件"
  echo "      2. 系统设置 › 隐私与安全性 › 文件与文件夹 › 终端，勾上「桌面」"
  echo ""
  pause_exit 1
fi
rm -f "$DIR/data/.write_test" 2>/dev/null
say "数据目录可读写 ✓"

# ── 5. 找 Node.js ────────────────────────────────────────────────
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.nvm/current/bin:$PATH"

find_node() {
  # 本机打包进来的 Node（如果有）
  for p in "./node/bin/node" "./runtime/node/bin/node"; do
    [ -x "$p" ] && { echo "$(cd "$(dirname "$p")" && pwd)/node"; return; }
  done
  # 系统里常见的位置（Apple 芯片 Homebrew / Intel Homebrew / 官方安装包）
  for p in \
    "/opt/homebrew/bin/node" \
    "/usr/local/bin/node" \
    "/usr/bin/node" ; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  # nvm / volta / asdf 装的 Node
  for p in "$HOME"/.nvm/versions/node/*/bin/node \
           "$HOME"/.volta/bin/node \
           "$HOME"/.asdf/shims/node ; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  # 交给 PATH 找
  command -v node 2>/dev/null
}

NODE_BIN="$(find_node)"

install_node_macos() {
  echo ""
  echo "  检测到本机还没有安装 Node.js，现在帮您自动安装 LTS 稳定版。"
  echo "  安装过程中若弹出授权窗口，请输入开机密码并点「好」。"
  echo ""

  # 1) 装了 Homebrew 时优先用，版本最新、最省事
  if command -v brew >/dev/null 2>&1; then
    echo "  → 检测到 Homebrew，执行 brew install node（首次可能要几分钟）……"
    if brew install node; then
      echo "  ✓ Node.js 已通过 Homebrew 安装完成"
    else
      echo "  ✗ Homebrew 安装失败，改用官网安装包。"
    fi
  fi

  # 2) 没装 brew 或 brew 失败：从官网下载 LTS 安装包（Apple 芯片 / Intel 通用）
  if [ -z "$(find_node)" ]; then
    local ver="" maj
    for maj in 24 22; do
      ver="$(curl -fsSL --max-time 20 "https://nodejs.org/dist/latest-v${maj}.x/" \
        | grep -o 'node-v[0-9]*\.[0-9]*\.[0-9]*\.pkg' | head -1 | sed -e 's/^node-//' -e 's/\.pkg$//')"
      [ -n "$ver" ] && break
    done

    if [ -z "$ver" ]; then
      echo "  ✗ 没能从官网拿到最新版本号（可能网络不通），下面给出手动安装方法。"
    else
      local pkgfile="/tmp/node-${ver}.pkg"
      echo "  → 正在下载 node-${ver}.pkg（约 90 MB）……"
      if curl -fL --max-time 600 -o "$pkgfile" "https://nodejs.org/dist/${ver}/node-${ver}.pkg"; then
        echo "  → 下载完成，正在安装（请在弹出的窗口里输入密码）……"
        if osascript -e "do shell script \"installer -pkg '$pkgfile' -target /\" with administrator privileges" >/dev/null 2>&1; then
          echo "  ✓ Node.js 已安装完成"
        else
          echo "  ✗ 安装没有完成（可能取消了授权），下面给出手动安装方法。"
        fi
      else
        echo "  ✗ 下载失败，请检查网络，下面给出手动安装方法。"
      fi
    fi
  fi
}

if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
  install_node_macos
  NODE_BIN="$(find_node)"
fi

if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
  echo ""
  echo "  ✗ 仍没有找到 Node.js，请手动安装后重新双击本文件："
  echo "      1. 到 https://nodejs.org 下载 LTS 版安装"
  echo "      2. 装了 Homebrew 的话，在终端执行：brew install node"
  echo ""
  echo "    本平台不依赖任何第三方库，只要有 Node.js 就能跑。"
  pause_exit 1
fi
say "Node.js ✓"
echo ""
say "正在启动……浏览器会自动打开"
say "用完在本窗口按 Ctrl + C 关闭服务"
echo ""

"$NODE_BIN" server.js

echo ""
read -r -p "  服务已停止，按回车键关闭窗口…"
