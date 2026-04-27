#!/data/data/com.termux/files/usr/bin/bash

# hanya boleh dijalankan dari launcher
if [ -z "$MM_LAUNCHER" ]; then
    echo "❌ Jalankan dari MediaMatrix launcher"
    exit 1
fi

# =========================
# WORKDIR
# =========================
WORKDIR="/sdcard/MediaMatrix"

# buat folder kalau belum ada
mkdir -p "$WORKDIR"

# =========================
# VALIDATION
# =========================
is_number() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

fix_decimal() {
  echo "$1" | sed 's/^\./0./'
}

# =========================
# SELECT FILE
# =========================
select_file() {
  while true; do
    echo ""
    echo "📂 Pilih file video:"
    echo ""

    mapfile -t FILE_LIST < <(find "$WORKDIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" -o -iname "*.avi" \))

    if [ ${#FILE_LIST[@]} -eq 0 ]; then
      echo "❌ Tidak ada file!"
      read -p "ENTER..."
      return 1
    fi

    for i in "${!FILE_LIST[@]}"; do
      echo "$((i+1))) $(basename "${FILE_LIST[$i]}")"
    done

    echo ""
    read -p "Pilih nomor: " num

    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
      echo "❌ Harus angka"
      continue
    fi

    if [ "$num" -lt 1 ] || [ "$num" -gt "${#FILE_LIST[@]}" ]; then
      echo "❌ Nomor tidak tersedia"
      continue
    fi

    INPUT="${FILE_LIST[$((num-1))]}"

    if [ ! -f "$INPUT" ]; then
      echo "❌ File tidak valid"
      continue
    fi

    echo "✅ Dipilih: $(basename "$INPUT")"
    break
  done
}

# =========================
# MAIN LOOP
# =========================
while true; do

clear
echo "======================================"
echo " 🎬 LoopMatrix Pro"
echo "======================================"
echo "📁 Workdir: $WORKDIR"
echo "1) 🎞️ Loop Engine"
echo "2) ⚡ Quality Encoder (CRF)"
echo "3) 🎚️ Bitrate Control (VBR / CBR)"
echo "4) 🎨 Color FX (Grading & Look)"
echo "0) ❌ Keluar"
echo ""

read -p "Pilih menu: " menu

# =========================
# MODE 1 — LOOP SYSTEM
# =========================
if [ "$menu" = "1" ]; then

select_file || continue

# =========================
# GET DURATION
# =========================
DURATION=$(ffprobe -v error -show_entries format=duration \
-of default=noprint_wrappers=1:nokey=1 "$INPUT")

if ! is_number "$DURATION"; then
  echo "❌ Gagal membaca durasi"
  read -p "ENTER..."
  continue
fi

echo ""
echo "Mode:"
echo "1) Manual"
echo "2) Auto"
echo "3) Style"
echo "4) Scene-Based"
read -p "Pilih: " mode

# =========================
# MODE 1 — MANUAL
# =========================
if [ "$mode" = "1" ]; then

  read -p "Cut (detik): " CUT
  read -p "Fade (detik): " FADE

  CUT=$(echo "$CUT" | tr -d '[:space:]')
  FADE=$(echo "$FADE" | tr -d '[:space:]')

  if ! is_number "$CUT"; then
    echo "❌ CUT invalid → default 1.5"
    CUT=1.5
  fi

  if ! is_number "$FADE"; then
    echo "❌ FADE invalid → default 1"
    FADE=1
  fi
fi

# =========================
# MODE 2 — AUTO
# =========================
if [ "$mode" = "2" ]; then

  if (( $(echo "$DURATION < 5" | bc -l) )); then
    CUT=$(echo "$DURATION * 0.3" | bc -l)
  elif (( $(echo "$DURATION < 10" | bc -l) )); then
    CUT=$(echo "$DURATION * 0.2" | bc -l)
  elif (( $(echo "$DURATION < 20" | bc -l) )); then
    CUT=$(echo "$DURATION * 0.15" | bc -l)
  elif (( $(echo "$DURATION < 40" | bc -l) )); then
    CUT=$(echo "$DURATION * 0.12" | bc -l)
  else
    CUT=$(echo "$DURATION * 0.1" | bc -l)
  fi

  FADE=$(echo "$CUT * 0.75" | bc -l)

  echo ""
  echo "🤖 Auto:"
  printf "CUT=%.2f FADE=%.2f\n" "$CUT" "$FADE"
fi

# =========================
# MODE 3 — STYLE
# =========================
if [ "$mode" = "3" ]; then

  echo ""
  echo "Style:"
  echo "1) Soft"
  echo "2) Balanced"
  echo "3) Sharp"
  read -p "Pilih: " style

  case $style in
    1) CUT_RATIO=0.22; FADE_RATIO=0.9 ;;
    2) CUT_RATIO=0.15; FADE_RATIO=0.75 ;;
    3) CUT_RATIO=0.1;  FADE_RATIO=0.6 ;;
    *) CUT_RATIO=0.15; FADE_RATIO=0.75 ;;
  esac

  CUT=$(echo "$DURATION * $CUT_RATIO" | bc -l)
  FADE=$(echo "$CUT * $FADE_RATIO" | bc -l)

  echo ""
  echo "🎚️ Style:"
  printf "CUT=%.2f FADE=%.2f\n" "$CUT" "$FADE"
fi

# =========================
# MODE 4 — SCENE BASED
# =========================
if [ "$mode" = "4" ]; then

  echo ""
  echo "🔍 Detecting scene..."

  SCENE_CUT=$(ffmpeg -i "$INPUT" \
  -filter:v "select='gt(scene,0.3)',metadata=print" \
  -f null - 2>&1 | grep pts_time | head -n 1 | sed 's/.*pts_time://')

  if ! is_number "$SCENE_CUT"; then
    SCENE_CUT=$(echo "$DURATION * 0.15" | bc -l)
  fi

  CUT=$SCENE_CUT
  FADE=$(echo "$CUT * 0.7" | bc -l)

  echo ""
  echo "🎯 Scene:"
  printf "CUT=%.2f FADE=%.2f\n" "$CUT" "$FADE"
fi

# =========================
# SAFETY
# =========================
MIN_CUT=0.3

if ! is_number "$CUT"; then CUT=1.5; fi
if ! is_number "$FADE"; then FADE=$(echo "$CUT * 0.7" | bc -l); fi

if (( $(echo "$CUT < $MIN_CUT" | bc -l) )); then
  CUT=$MIN_CUT
fi

if (( $(echo "$FADE > $CUT" | bc -l) )); then
  FADE=$CUT
fi

OUT_DURATION=$(echo "$DURATION - $CUT" | bc -l)

# FIX FORMAT ANGKA
CUT=$(fix_decimal "$CUT")
FADE=$(fix_decimal "$FADE")
OUT_DURATION=$(fix_decimal "$OUT_DURATION")

# =========================
# OUTPUT NAMING SYSTEM
# =========================

DATE=$(date +%Y%m%d)
TIME=$(date +%H%M%S)

# berdasarkan mode
case $mode in
  1)
    OUT="$WORKDIR/loop_manual_${DATE}_${TIME}.mp4"
    ;;
  2)
    OUT="$WORKDIR/loop_auto_${DATE}_${TIME}.mp4"
    ;;
  3)
    # style detail
    case $style in
      1) OUT="$WORKDIR/loop_soft_${DATE}_${TIME}.mp4" ;;
      2) OUT="$WORKDIR/loop_balanced_${DATE}_${TIME}.mp4" ;;
      3) OUT="$WORKDIR/loop_sharp_${DATE}_${TIME}.mp4" ;;
      *) OUT="$WORKDIR/loop_style_${DATE}_${TIME}.mp4" ;;
    esac
    ;;
  4)
    OUT="$WORKDIR/loop_scene_${DATE}_${TIME}.mp4"
    ;;
esac

# VALIDASI MODE
if [ -z "$OUT" ]; then
  echo "❌ Mode tidak valid"
  read -p "ENTER..."
  continue
fi

echo ""
echo "🎬 Processing..."
echo "CUT=$CUT | FADE=$FADE | DURATION=$OUT_DURATION"

# =========================
# FFMPEG CORE
# =========================
ffmpeg -y -i "$INPUT" -filter_complex "\
[0:v]split[main][overlay]; \
[main]trim=start=${CUT},setpts=PTS-STARTPTS[base]; \
[overlay]trim=0:${CUT},setpts=PTS-STARTPTS,format=rgba,\
fade=t=in:st=0:d=${FADE}:alpha=1,\
setpts=PTS+(${OUT_DURATION}-${CUT})/TB[ol]; \
[base][ol]overlay=x=0:y=0:shortest=0,format=yuv420p[out]" \
-map "[out]" \
-c:v libx264 -crf 20 -preset veryfast -an "$OUT"

# =========================
# RESULT CHECK
# =========================
if [ -f "$OUT" ]; then
  echo "✅ Sukses"
  echo "📁 Output: $OUT"
else
  echo "❌ Gagal membuat file"
fi

# =========================
# LOOP PREVIEW (INPUT MANUAL)
# =========================
echo ""
echo "🔁 Loop preview?"
echo "1) Ya"
echo "2) Tidak"
read -p "Pilih: " lp

if [ "$lp" = "1" ]; then

  echo ""
  read -p "Masukkan jumlah loop (contoh: 5): " LOOP_INPUT

  if ! [[ "$LOOP_INPUT" =~ ^[0-9]+$ ]]; then
    echo "❌ Input tidak valid"
    read -p "ENTER..."
    continue
  fi

  LOOP=$((LOOP_INPUT - 1))
  [ "$LOOP" -lt 0 ] && LOOP=0

  echo ""
  echo "🚀 Membuat preview..."

  PREVIEW_OUT="$WORKDIR/$(basename "${OUT%.mp4}_preview.mp4")"

  ffmpeg -y -stream_loop $LOOP -i "$OUT" \
-c copy "$PREVIEW_OUT"

  echo "🎬 Preview: $PREVIEW_OUT"
fi

read -p "ENTER..."
fi

# =========================
# MODE 2 — ENCODE ONLY
# =========================
if [ "$menu" = "2" ]; then

select_file || continue

echo ""
echo "1) High Quality (CRF 18)"
echo "2) Balanced (CRF 20)"
echo "3) Small Size (CRF 23)"
read -p "Pilih: " q

case $q in
  1) CRF=18 ;;
  2) CRF=20 ;;
  3) CRF=23 ;;
  *) CRF=20 ;;
esac

echo ""
echo "⚡ Speed:"
echo "1) Fast"
echo "2) Medium"
echo "3) Slow"
read -p "Pilih: " p

case $p in
  1) PRESET="fast" ;;
  2) PRESET="medium" ;;
  3) PRESET="slow" ;;
  *) PRESET="fast" ;;
esac

DATE=$(date +%Y%m%d)
TIME=$(date +%H%M%S)

OUT="$WORKDIR/crf${CRF}_${DATE}_${TIME}.mp4"

ffmpeg -y -i "$INPUT" \
-c:v libx264 -crf $CRF -preset $PRESET -an "$OUT"

# =========================
# RESULT CHECK
# =========================
if [ -f "$OUT" ]; then
  echo "✅ Sukses"
  echo "📁 Output: $OUT"
else
  echo "❌ Gagal membuat file"
fi

read -p "ENTER..."
fi

# =========================
# MODE 3 — BITRATE ENCODE
# =========================
if [ "$menu" = "3" ]; then

select_file || continue

# =========================
# GET RESOLUTION
# =========================
WIDTH=$(ffprobe -v error -select_streams v:0 \
-show_entries stream=width -of csv=p=0 "$INPUT")

HEIGHT=$(ffprobe -v error -select_streams v:0 \
-show_entries stream=height -of csv=p=0 "$INPUT")

echo ""
echo "Mode Bitrate:"
echo "1) VBR (Variable Bitrate)"
echo "2) CBR (Constant Bitrate)"
read -p "Pilih: " br_mode

echo ""
echo "Bitrate:"
echo "1) Recommended"
echo "2) Custom"
read -p "Pilih: " br_type

# =========================
# RECOMMENDED BITRATE
# =========================
if [ "$br_type" = "1" ]; then

  if [ "$HEIGHT" -le 480 ]; then
    BITRATE="1000k"
  elif [ "$HEIGHT" -le 720 ]; then
    BITRATE="2500k"
  elif [ "$HEIGHT" -le 1080 ]; then
    BITRATE="5000k"
  else
    BITRATE="8000k"
  fi

  echo "📊 Recommended bitrate: $BITRATE"

else
  while true; do

    echo ""
    echo "📊 Rekomendasi bitrate (kbps):"
    echo "720p  : 3000–4500"
    echo "1080p : 5000–8000"
    echo "2K    : 8000–12000"
    echo "4K    : 15000–30000"
    echo ""

    read -p "Masukkan bitrate (contoh: 4000k): " BITRATE

    # bersihkan spasi
    BITRATE=$(echo "$BITRATE" | tr -d '[:space:]')

    # validasi format wajib pakai k
    if [[ "$BITRATE" =~ ^[0-9]+k$ ]]; then
      break
    else
      echo "❌ Format salah! Gunakan contoh: 4000k"
    fi

  done
fi

# =========================
# CBR EXTRA OPTION
# =========================
if [ "$br_mode" = "2" ]; then
  echo ""
  echo "CBR Mode:"
  echo "1) Normal"
  echo "2) Grain (detail lebih tajam)"
  read -p "Pilih: " grain_mode
fi

# =========================
# OUTPUT NAME
# =========================
DATE=$(date +%Y%m%d)
TIME=$(date +%H%M%S)

# tentukan tipe bitrate
if [ "$br_mode" = "1" ]; then
  MODE_NAME="vbr"
else
  MODE_NAME="cbr"
fi

# tambahan grain label
if [ "$br_mode" = "2" ] && [ "$grain_mode" = "2" ]; then
  MODE_NAME="cbr_grain"
fi

# bersihin bitrate
BITRATE_LABEL=$(echo "$BITRATE" | tr -d '[:space:]')

OUT="$WORKDIR/bitrate_${MODE_NAME}_${BITRATE_LABEL}_${DATE}_${TIME}.mp4"

echo ""
echo "🎬 Encoding..."

# =========================
# VBR
# =========================
if [ "$br_mode" = "1" ]; then

  ffmpeg -y -i "$INPUT" \
  -c:v libx264 -preset medium -crf 20 \
  -maxrate $BITRATE -bufsize $BITRATE \
  -an "$OUT"

fi

# =========================
# CBR
# =========================
if [ "$br_mode" = "2" ]; then

  if [ "$grain_mode" = "2" ]; then
    TUNE="-tune grain"
  else
    TUNE=""
  fi

  ffmpeg -y -i "$INPUT" \
  -c:v libx264 -b:v $BITRATE -minrate $BITRATE -maxrate $BITRATE \
  -bufsize $BITRATE \
  $TUNE -preset medium -an "$OUT"

fi

# =========================
# RESULT CHECK
# =========================
if [ -f "$OUT" ]; then
  echo "✅ Sukses"
  echo "📁 Output: $OUT"
else
  echo "❌ Gagal membuat file"
fi

read -p "ENTER..."
fi

# =========================
# MODE 4 — COLOR FX
# =========================
if [ "$menu" = "4" ]; then

select_file || continue

echo ""
echo "🎨 Color Cinematic Style:"
echo "1) 🌲 Forest Rain Cinematic (Main)"
echo "2) 🌧️ Deep Rain (Dark Moody)"
echo "3) 🌤️ Soft Rain Natural"
echo "4) 🧊 Cold Rain Teal"
echo "5) 🌿 Ultra Natural Green"
echo "6) 🌲 HD Forest Boost"
echo "7) 🌧️ Clean Rain Cinematic"
echo "8) 🎥 Clean Video"
echo "9) 🎞️ Soft Cinematic"
echo "10) 📱 Social Pop"
echo "11) 🌸 Spring Bright"
echo "12) 🔊 Warm Audio Glow "
echo "13) ☕ Cozy Cafe Rain"
echo "14) 🎧 Jazz Portrait Cinematic"
echo "15) 🌧️ Dark Jazz Rain"
read -p "Pilih: " fx

# =========================
# FILTER PRESET
# =========================
case $fx in

  # 🌲 MAIN LOOK (DEFAULT TERBAIK)
  1)
  FILTER="colorbalance=rs=-0.08:rm=0.12:rh=0.08:\
bs=0.25:bm=0.15:bh=0.05:\
gs=0.18:gm=0.1:gh=0.05,\
eq=contrast=1.18:brightness=-0.06:saturation=0.88,\
curves=all='0/0 0.2/0.15 0.45/0.42 0.7/0.78 1/1',\
hue=h=-5:s=0.95,\
unsharp=5:5:0.6:3:3:0.3"
  ;;

  # 🌧️ DARK STORM LOOK
  2)
  FILTER="colorbalance=rs=-0.12:rm=0.18:\
bs=0.35:bm=0.2:\
gs=0.25:gm=0.15,\
eq=contrast=1.25:brightness=-0.1:saturation=0.82,\
curves=all='0/0 0.15/0.1 0.5/0.5 0.8/0.9 1/1'"
  ;;

  # 🌤️ NATURAL RAIN (LEBIH TERANG)
  3)
  FILTER="colorbalance=gs=0.12:gm=0.08:\
bs=0.1:bm=0.05,\
eq=contrast=1.08:brightness=-0.02:saturation=0.95,\
curves=all='0/0 0.3/0.28 0.6/0.65 1/1'"
  ;;

  # 🧊 COOL TEAL LOOK
  4)
  FILTER="colorbalance=bs=0.4:bm=0.25:\
gs=0.2:gm=0.1,\
eq=contrast=1.2:brightness=-0.07:saturation=0.85,\
hue=h=-10"
  ;;
  
  # 🌿 Ultra Natural Green (PALING REALISTIS)
  5) FILTER="colorbalance=gs=0.1:gm=0.08:\
bs=0.05:bm=0.03,\
eq=contrast=1.1:brightness=0.0:saturation=0.95,\
hue=h=-3,\
unsharp=5:5:0.7:3:3:0.4"
  ;;

  # 🌲 HD Forest Boost (DETAIL MAX)
  5) FILTER="colorbalance=gs=0.1:gm=0.08:\
bs=0.05:bm=0.03,\
eq=contrast=1.1:brightness=0.0:saturation=0.95,\
hue=h=-3,\
unsharp=5:5:0.7:3:3:0.4"
  ;;
  
  #🌲 HD Forest Boost (DETAIL MAX)
  6) FILTER="colorbalance=gs=0.12:gm=0.1:\
bs=0.08:bm=0.05,\
eq=contrast=1.15:brightness=-0.02:saturation=0.92,\
curves=all='0/0 0.3/0.28 0.6/0.7 1/1',\
unsharp=7:7:0.8:5:5:0.5"
  ;;
  
  # 🌧️ Clean Rain Cinematic (IMPROVED)
  7) FILTER="colorbalance=rs=-0.05:rm=0.1:\
bs=0.2:bm=0.12:\
gs=0.15:gm=0.08,\
eq=contrast=1.15:brightness=-0.04:saturation=0.9,\
curves=all='0/0 0.25/0.22 0.5/0.5 0.75/0.82 1/1',\
unsharp=5:5:0.6"
  ;;
  
  # 🎥 Clean Video (YouTube / Daily)
  8) FILTER="eq=contrast=1.08:brightness=0.02:saturation=1.02,\
unsharp=5:5:0.5"
  ;;
  
  # 🎞️ Soft Cinematic Universal
  9) FILTER="eq=contrast=1.12:brightness=-0.02:saturation=0.95,\
curves=all='0/0 0.3/0.28 0.6/0.7 1/1'"
  ;;
  
  # 📱 Social Media Pop
  10) FILTER="eq=contrast=1.2:brightness=0.03:saturation=1.1,\
unsharp=5:5:0.6"
  ;;

  # 🌸 Spring Bright
  11) FILTER="eq=contrast=1.08:brightness=0.05:saturation=1.1,\
colorbalance=rs=0.1:rm=0.08:gs=0.05:gm=0.05,\
curves=all='0/0 0.3/0.32 0.6/0.7 1/1'"
  ;;

  # 🔊 Warm Audio Glow 
  12) FILTER="eq=contrast=1.15:brightness=-0.02:saturation=1.05,\
colorbalance=rs=0.2:rm=0.15:bs=-0.05,\
curves=all='0/0 0.25/0.22 0.5/0.5 0.8/0.9 1/1',\
unsharp=5:5:0.5"
  ;;

  # ☕ Cozy Cafe Rain
  13) FILTER="colorbalance=rs=0.15:rm=0.12:\
bs=0.15:bm=0.1,\
eq=contrast=1.12:brightness=-0.03:saturation=0.95,\
curves=all='0/0 0.2/0.18 0.5/0.5 0.8/0.85 1/1'"
  ;;

  # 🎧 Jazz Portrait Cinematic
  14) FILTER="colorbalance=rs=0.18:rm=0.12:\
bs=0.2:bm=0.15,\
eq=contrast=1.18:brightness=-0.04:saturation=0.92,\
hue=h=-5,\
curves=all='0/0 0.25/0.2 0.5/0.5 0.75/0.85 1/1',\
unsharp=5:5:0.6"
  ;;

  # 🌧️ Dark Jazz Rain
  15) FILTER="colorbalance=rs=0.25:rm=0.18:\
bs=0.25:bm=0.2,\
eq=contrast=1.25:brightness=-0.1:saturation=0.85,\
curves=all='0/0 0.15/0.1 0.5/0.5 0.85/0.95 1/1'"
  ;;

  *)
  echo "❌ Mode tidak valid"
  read -p "ENTER..."
  continue
  ;;
esac

# =========================
# OUTPUT NAME
# =========================
DATE=$(date +%Y%m%d)
TIME=$(date +%H%M%S)

case $fx in
  1) NAME="forest_main" ;;
  2) NAME="deep_rain" ;;
  3) NAME="soft_rain" ;;
  4) NAME="cold_rain" ;;
  5) NAME="ultra_natural" ;;
  6) NAME="hd_forest" ;;
  7) NAME="clean_rain" ;;
  8) NAME="clean_video" ;;
  9) NAME="soft_cinematic" ;;
  10) NAME="social_pop" ;;
  11) NAME="spring_bright" ;;
  12) NAME="warm_audio" ;;
  13) NAME="cozy_cafe_rain" ;;
  14) NAME="jazz_portrait" ;;
  15) NAME="dark_jazz_rain" ;;
esac

OUT="$WORKDIR/fx_${NAME}_${DATE}_${TIME}.mp4"

echo ""
echo "🎬 Applying Color Cinematic FX..."

ffmpeg -y -i "$INPUT" \
-vf "$FILTER" \
-c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -an "$OUT"

# =========================
# RESULT CHECK
# =========================
if [ -f "$OUT" ]; then
  echo "✅ Sukses"
  echo "📁 Output: $OUT"
else
  echo "❌ Gagal membuat file"
fi

read -p "ENTER..."
fi

# =========================
# EXIT
# =========================
if [ "$menu" = "0" ]; then
break
fi

done