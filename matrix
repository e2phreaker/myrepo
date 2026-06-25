#!/data/data/com.termux/files/usr/bin/bash

clear
echo "===================================="
echo " 🚀 MediaMatrix Installer"
echo "===================================="

# =========================
# CONFIG
# =========================
ENC_REPO="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2UycGhyZWFrZXIvbXlyZXBvL21haW4="
REPO=$(printf '%s' "$ENC_REPO" | base64 -d 2>/dev/null)
[ -z "$REPO" ] && echo "❌ Repo decode gagal" && exit 1

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

    KEY_DATA=$(echo "$DATA" | awk "/\"$USER_KEY\"/,/}/")

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

    echo ""
    echo "===================================="
    echo "      LICENSE EXPIRED"
    echo "===================================="
    echo ""
    echo "⛔ License expired ($EXPIRY)"
    echo ""
    echo "1. Hapus license"
    echo "2. Keluar"
    echo ""

    read -p "Pilih [1-2]: " MENU

    case "$MENU" in

        1)
            rm -f "$LICENSE_FILE"
            echo "✅ License berhasil dihapus."
            ;;
        2)
            ;;
        *)
            echo "❌ Pilihan tidak valid."
            ;;
    esac

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
apt install -y python ffmpeg curl bc

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

curl -fLo matrix "$REPO/matrix" || { echo "❌ Gagal download launcher"; exit 1; }

# =========================
# FIX LINE ENDING
# =========================
sed -i 's/\r$//' matrix

# cek apakah download berhasil
for f in matrix; do
    [ ! -f "$f" ] && echo "❌ Gagal download $f" && exit 1
done

# kasih permission execute
chmod +x matrix

echo "✅ Permission berhasil di-set"

# version awal
curl -fsSL "$REPO/version.txt" > "$WORKDIR/.version"

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
