#!/data/data/com.termux/files/usr/bin/bash

clear
echo "===================================="
echo " 🚀 MediaMatrix Installer"
echo "===================================="

# =========================
# CONFIG
# =========================
ENC_REPO="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL1VTRVJOQU1FL1JFUE8vbWFpbg=="
REPO=$(echo "$ENC_REPO" | base64 -d)
WORKDIR="$HOME/MediaMatrix"
LICENSE_URL="$REPO/licenses.json"
LICENSE_FILE="$HOME/.mediamatrix_license"

# =========================
# LICENSE CHECK
# =========================
echo ""
echo "🔐 License Required"

if [ ! -f "$LICENSE_FILE" ] || [ ! -s "$LICENSE_FILE" ]; then
    read -p "Masukkan license key: " USER_KEY
    echo "$USER_KEY" > "$LICENSE_FILE"
else
    USER_KEY=$(cat "$LICENSE_FILE")
fi

# validasi kosong
if [ -z "$USER_KEY" ]; then
    echo "❌ License kosong!"
    rm -f "$LICENSE_FILE"
    exit 1
fi

echo "🔍 Validating license..."

MAX_RETRY=3
COUNT=0

while true; do
    DATA=$(curl -s "$LICENSE_URL")

    [ -z "$DATA" ] && echo "❌ Tidak bisa konek ke server" && exit 1

    KEY_DATA=$(echo "$DATA" | grep -A5 "\"$USER_KEY\"")

    if [ -z "$KEY_DATA" ]; then
    echo "❌ License tidak valid"
    rm -f "$LICENSE_FILE"
    COUNT=$((COUNT+1))

    if [ "$COUNT" -ge "$MAX_RETRY" ]; then
        echo "❌ Gagal 3x. Keluar."
        exit 1
    fi

    read -p "Masukkan license key lagi: " USER_KEY

    echo "$USER_KEY" > "$LICENSE_FILE"   # ← TAMBAHKAN INI

    continue
fi

    break
done

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

curl -fLo audio "$REPO/audio" || { echo "❌ Gagal download audio"; exit 1; }
curl -fLo video "$REPO/video" || { echo "❌ Gagal download video"; exit 1; }
curl -fLo yt "$REPO/yt" || { echo "❌ Gagal download yt-dlp"; exit 1; }
curl -fLo loop "$REPO/loop" || { echo "❌ Gagal download loop"; exit 1; }
curl -fLo matrix "$REPO/matrix" || { echo "❌ Gagal download launcher"; exit 1; }

# =========================
# FIX LINE ENDING
# =========================
sed -i 's/\r$//' audio video yt loop matrix

# cek apakah download berhasil
for f in audio video yt loop matrix; do
    [ ! -f "$f" ] && echo "❌ Gagal download $f" && exit 1
done

# kasih permission execute
chmod +x audio video yt loop matrix

echo "✅ Permission berhasil di-set"

# version awal
echo "1.0" > "$WORKDIR/.version"

# =========================
# SET ALIAS
# =========================
echo ""
echo "⚙️ Setting alias..."

BASHRC="$HOME/.bashrc"

sed -i '/alias matrix=/d' "$BASHRC"

echo "alias matrix='$WORKDIR/matrix'" >> "$BASHRC"

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