#!/data/data/com.termux/files/usr/bin/bash

clear
echo "===================================="
echo " 🚀 MediaMatrix Installer"
echo "===================================="

# =========================
# CONFIG
# =========================
REPO="https://raw.githubusercontent.com/e2phreaker/myrepo/main"
WORKDIR="$HOME/MediaMatrix"
LICENSE_URL="$REPO/licenses.json"
LICENSE_FILE="$HOME/.mediamatrix_license"

# =========================
# LICENSE CHECK
# =========================
echo ""
echo "🔐 License Required"

if [ ! -f "$LICENSE_FILE" ]; then
    read -p "Masukkan license key: " USER_KEY
    echo "$USER_KEY" > "$LICENSE_FILE"
else
    USER_KEY=$(cat "$LICENSE_FILE")
fi

echo "🔍 Validating license..."

DATA=$(curl -s "$LICENSE_URL")
KEY_DATA=$(echo "$DATA" | grep -A5 "\"$USER_KEY\""

if [ -z "$KEY_DATA" ]; then
    echo "❌ License tidak valid"
    rm -f "$LICENSE_FILE"
    exit 1
fi

STATUS=$(echo "$KEY_DATA" | grep status | cut -d '"' -f4)
EXPIRY=$(echo "$KEY_DATA" | grep expiry | cut -d '"' -f4)

TODAY=$(date +%Y-%m-%d)

[ "$STATUS" != "active" ] && echo "🚫 License revoked" && exit 1

if [[ "$TODAY" > "$EXPIRY" ]]; then
    echo "⛔ License expired ($EXPIRY)"
    exit 1
fi

echo "✅ License valid"

# =========================
# STORAGE PERMISSION
# =========================
if [ ! -d "$HOME/storage" ]; then
    echo "📂 Setup storage permission..."
    termux-setup-storage
fi

# =========================
# UPDATE SYSTEM
# =========================
echo ""
echo "📦 Updating system..."
apt update -y && apt upgrade -y

# =========================
# INSTALL DEPENDENCIES
# =========================
echo ""
echo "📦 Installing dependencies..."
apt install -y python ffmpeg curl

# =========================
# INSTALL YT-DLP
# =========================
if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "⬇️ Installing yt-dlp..."
    pip install -U yt-dlp
else
    echo "✅ yt-dlp already installed"
fi

# =========================
# CREATE WORKDIR
# =========================
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit

# =========================
# DOWNLOAD SCRIPT
# =========================
echo ""
echo "⬇️ Downloading MediaMatrix tools..."

curl -fLO "$REPO/prompt-aio-audio.sh" || { echo "❌ Gagal download audio"; exit 1; }
curl -fLO "$REPO/prompt-aio-video.sh" || { echo "❌ Gagal download video"; exit 1; }
curl -fLO "$REPO/prompt-aio-yt-dlp.sh" || { echo "❌ Gagal download yt-dlp"; exit 1; }
curl -fLO "$REPO/prompt-aio-loop.sh" || { echo "❌ Gagal download loop"; exit 1; }
curl -fLO "$REPO/mediamatrix.sh" || { echo "❌ Gagal download launcher"; exit 1; }

# =========================
# FIX FORMAT
# =========================
echo ""
echo "🔧 Fixing script format..."
sed -i 's/\r$//' *.sh

# =========================
# PERMISSION
# =========================
chmod +x *.sh

# =========================
# INIT SYSTEM FILES
# =========================

# version awal
echo "1.0" > "$WORKDIR/.version"

# hash awal
sha256sum "$WORKDIR/mediamatrix.sh" | cut -d ' ' -f1 > "$WORKDIR/.hash"

# =========================
# SET ALIAS
# =========================
echo ""
echo "⚙️ Setting alias..."

BASHRC="$HOME/.bashrc"

sed -i '/alias matrix=/d' "$BASHRC"

echo "alias matrix='$WORKDIR/mediamatrix.sh'" >> "$BASHRC"

source "$BASHRC"

# =========================
# DONE
# =========================
clear
echo "===================================="
echo " ✅ INSTALLATION COMPLETE"
echo "===================================="
echo ""
echo "📦 MediaMatrix berhasil diinstall!"
echo ""
echo "👉 Jalankan dengan perintah:"
echo ""
echo "   matrix"
echo ""
echo "===================================="