#!/bin/bash
# ---------------------------------------------------------------------------
# 点墨 · 作文批改台 —— macOS 应用打包
#
# 产出：
#   ~/Desktop/点墨.app                       双击即用（再点一次 = 停止服务）
#   ~/Desktop/点墨_v<版本>_macOS_<日期>.zip   分发用（ditto 压缩，保留签名）
#
# 特性：
#   · 随包 Node 通用运行时（Intel / Apple 芯片都能跑），用户无需安装 Node
#   · 数据不进包：存 ~/Documents/点墨数据，升级替换 App 不动数据
#     （server.js 读取 DIANMO_DATA_DIR 环境变量，命令行直接跑 node server.js
#      时行为不变，数据仍在程序旁的 data/ 目录）
#   · ad-hoc 签名（本机构建本机运行没问题；分发给他人的机器上首次打开
#     需要「右键 → 打开」绕过 Gatekeeper 的未认证提示）
#
# 用法：./pack-macos.sh [版本号]     （缺省 1.4.2）
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-1.4.2}"
APP_NAME="点墨"
DATA_DIR_NAME="点墨数据"
NODE_BIN="$(command -v node)"
[ -n "$NODE_BIN" ] || { echo "✗ 找不到 node，请先安装 Node（brew install node）"; exit 1; }

OUT_APP="$HOME/Desktop/${APP_NAME}.app"
OUT_ZIP="$HOME/Desktop/${APP_NAME}_v${VERSION}_macOS_$(date +%Y%m%d).zip"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

CONTENT="$STAGE/app/Contents"
mkdir -p "$CONTENT/MacOS" "$CONTENT/Resources/app"

echo "① 拷贝程序本体（不含 data/，数据不进包）"
cp server.js "$CONTENT/Resources/app/"
cp -R public "$CONTENT/Resources/app/public"
rm -rf "$CONTENT/Resources/app/public/.DS_Store"
for f in README.md CHANGELOG.md LICENSE; do
  [ -f "$f" ] && cp "$f" "$CONTENT/Resources/app/"
done

echo "①b 拷贝作文评分 skill（默认提示词的来源，server.js 启动时从这里加载）"
SKILL_SRC="${DIANMO_SKILL_SRC:-$HOME/.codex/skills/suzhou-english-essay-25-rubric}"
if [ -d "$SKILL_SRC" ]; then
  # 只装进 App 内置数据目录 data/rubric-skill/（server.js 的第 2 候选路径），
  # 排除 agents/scripts 等运行用不到的目录
  mkdir -p "$CONTENT/Resources/app/data/rubric-skill"
  for item in SKILL.md README.md LICENSE rubric.json references; do
    [ -e "$SKILL_SRC/$item" ] && cp -R "$SKILL_SRC/$item" "$CONTENT/Resources/app/data/rubric-skill/"
  done
  find "$CONTENT/Resources/app/data/rubric-skill" -name ".DS_Store" -delete 2>/dev/null || true
else
  echo "  ✗ 未找到 skill：$SKILL_SRC —— 打出的包启动会报「未找到作文评分 skill」。"
  echo "    可用 DIANMO_SKILL_SRC=路径 指定 skill 目录后重新打包。"
  exit 1
fi

echo "② 拷贝 Node 运行时（$("$NODE_BIN" --version)）"
NODE_REAL="$(realpath "$NODE_BIN")"
cp "$NODE_REAL" "$CONTENT/MacOS/node"

echo "③ 生成图标"
SVG="$STAGE/icon.svg"
cat > "$SVG" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024">
  <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1D4ED8"/><stop offset="1" stop-color="#0F2A5F"/></linearGradient></defs>
  <rect x="64" y="64" width="896" height="896" rx="200" fill="url(#g)"/>
  <text x="512" y="542" font-family="Songti SC, PingFang SC, STSong, serif" font-size="540" font-weight="700" fill="#FFFFFF" text-anchor="middle" dominant-baseline="central">墨</text>
  <rect x="688" y="688" width="180" height="180" rx="26" fill="#C0392B"/>
  <text x="778" y="780" font-family="Songti SC, PingFang SC, serif" font-size="120" font-weight="700" fill="#FFFFFF" text-anchor="middle" dominant-baseline="central">点</text>
</svg>
SVG
PNG="$STAGE/icon-1024.png"
# 透明底渲染：优先 Edge / Chrome 的 headless 截图（--default-background-color
# 传 00000000 才是透明）；没有浏览器时退回 qlmanage（白底，图标四角会露白）
EDGE="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ -x "$EDGE" ]; then
  "$EDGE" --headless --disable-gpu --screenshot="$PNG" --window-size=1024,1024 \
    --default-background-color=00000000 "file://$SVG" >/dev/null 2>&1 || true
elif [ -x "$CHROME" ]; then
  "$CHROME" --headless --disable-gpu --screenshot="$PNG" --window-size=1024,1024 \
    --default-background-color=00000000 "file://$SVG" >/dev/null 2>&1 || true
fi
[ -f "$PNG" ] || qlmanage -t -s 1024 -o "$STAGE" "$SVG" >/dev/null 2>&1 && [ -f "$PNG" ] || cp "$STAGE/icon.svg.png" "$PNG" 2>/dev/null || true
if [ -f "$PNG" ]; then
  ICONSET="$STAGE/icon.iconset"; mkdir -p "$ICONSET"
  for sz in 16 32 128 256 512; do
    sips -z "$sz" "$sz" "$PNG" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
    sips -z $((sz * 2)) $((sz * 2)) "$PNG" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$CONTENT/Resources/${APP_NAME}.icns"
else
  echo "  （图标渲染失败，使用系统默认图标）"
fi

echo "④ 写入 Info.plist 与启动器"
cat > "$CONTENT/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>点墨 · 作文批改台</string>
  <key>CFBundleIdentifier</key><string>com.teatony.dianmo</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIconFile</key><string>${APP_NAME}</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cat > "$CONTENT/MacOS/${APP_NAME}" <<LAUNCHER
#!/bin/bash
# 点墨启动器：双击启动服务并自动打开浏览器；服务在跑时再双击一次 = 停止。
BUNDLE="\$(cd "\$(dirname "\$0")/.." && pwd)"
NODE="\$BUNDLE/MacOS/node"
APPDIR="\$BUNDLE/Resources/app"
DATA="\$HOME/Documents/${DATA_DIR_NAME}"
PIDFILE="\$DATA/服务.pid"
LOG="\$DATA/点墨日志.log"
mkdir -p "\$DATA"

notify() { osascript -e "display notification \"\$1\" with title \"点墨\"" >/dev/null 2>&1 || true; }

# 开关式：pid 里有活着的进程 → 这次双击是「停止」
if [ -f "\$PIDFILE" ] && kill -0 "\$(cat "\$PIDFILE")" 2>/dev/null; then
  kill "\$(cat "\$PIDFILE")" 2>/dev/null || true
  rm -f "\$PIDFILE"
  notify "点墨已停止"
  exit 0
fi
rm -f "\$PIDFILE"

cd "\$APPDIR"
DIANMO_DATA_DIR="\$DATA" nohup "\$NODE" server.js >> "\$LOG" 2>&1 &
echo \$! > "\$PIDFILE"
notify "点墨已启动，浏览器马上打开"
LAUNCHER
chmod +x "$CONTENT/MacOS/${APP_NAME}"

echo "⑤ 组装 App、ad-hoc 签名"
rm -rf "$OUT_APP"
mv "$STAGE/app" "$OUT_APP"
codesign --force --deep --sign - "$OUT_APP" >/dev/null 2>&1 || echo "  （codesign 不可用，跳过签名；本机 arm64 可能拒绝运行未签名程序）"
touch "$OUT_APP"

echo "⑥ 生成分发 zip（ditto 保留签名与可执行权限）"
rm -f "$OUT_ZIP"
ditto -c -k --keepParent "$OUT_APP" "$OUT_ZIP"

echo ""
echo "✓ 完成：$OUT_APP"
echo "✓ 分发包：$OUT_ZIP"
echo ""
echo "  首次运行前，把现有数据拷到 ~/Documents/${DATA_DIR_NAME} ："
echo "    mkdir -p ~/Documents/${DATA_DIR_NAME} && cp -R data/. ~/Documents/${DATA_DIR_NAME}/"
echo "  数据目录里的 db.json / students.json / rosters.json / settings.json / uploads / prompt.txt 都会原样生效。"
