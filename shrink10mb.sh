#!/bin/bash
# shrink10mb.sh - Shrink any MP4 to ≤10MB without cutting length
# Requirements: ffmpeg, ffprobe

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 input.mp4 [output.mp4]"
    exit 1
fi

infile="$1"
outfile="${2:-$(basename "${infile%.*}")_shrunk.mp4}"

if [ ! -f "$infile" ]; then
    echo "ERROR: File '$infile' not found."
    exit 1
fi

echo "Input: $infile"

# ─── Get duration (seconds) ────────────────────────────────
duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$infile")
duration=${duration%.*}  # strip decimal part

if [ -z "$duration" ] || [ "$duration" -le 0 ]; then
    echo "ERROR: Could not determine duration."
    exit 1
fi
echo "Duration: $duration sec"

# ─── Compute target bitrate ───────────────────────────────
# 10 MB total file size
total_bits=$((10 * 1024 * 1024 * 8))

# target bitrate (bits/sec), leave 128 kbps for audio
video_bitrate=$(((total_bits / duration) - 128000))
vbit=$((video_bitrate / 1000))  # kbps

if [ "$vbit" -le 0 ]; then
    echo "ERROR: Computed video bitrate $vbit kbps is too low."
    exit 1
fi

echo "Target video: ${vbit}k + audio: 128k"

# ─── 2-pass encoding ──────────────────────────────────────
echo "Running 2-pass encoding (with size cap 10MB)..."

# First pass
ffmpeg -y -i "$infile" \
  -c:v libx264 -b:v ${vbit}k -preset medium -pass 1 -an -f mp4 /dev/null

# Second pass with audio and size limit
ffmpeg -y -i "$infile" \
  -c:v libx264 -b:v ${vbit}k -preset medium -pass 2 \
  -c:a aac -b:a 128k -fs 10M \
  "$outfile"

# Clean up log files from 2-pass
rm -f ffmpeg2pass-0.log*

echo "Done! Output file: $outfile"
