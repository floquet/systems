#!/usr/bin/env bash
set -euo pipefail

# Inline hint: locate GVFS SMB mounts on isomer and destination paths on mirovia
GVFS_BASE="/run/user/$(id -u)/gvfs"
DOCS_SRC="$GVFS_BASE/smb-share:server=10.11.26.37,share=documents"
MUSIC_SRC="$GVFS_BASE/smb-share:server=10.11.26.37,share=music"

DOCS_DST="/mnt/mirovia/Documents"
MUSIC_DST="/mnt/mirovia/nas-music-staging"
OUT_DIR="$HOME/repos-isomer/github/systems"
LOG="$OUT_DIR/nas-verify.log"

# Inline hint: ensure both SMB shares are mounted
gio mount smb://10.11.26.37/Documents 2>/dev/null || true
gio mount smb://10.11.26.37/Music 2>/dev/null || true

{
  echo "=== Started: $(date) ==="

  echo "--- Step 1: Finish transferring remaining Documents ---"
  rsync -ah --info=progress2 --modify-window=1 \
    --exclude='.AppleDB' --exclude='.DS_Store' --exclude='._*' \
    "$DOCS_SRC/" "$DOCS_DST/"

  echo "--- Step 2: Byte-for-byte checksum verification (Documents) ---"
  # Inline hint: -r recursive, -c full file checksum, -n dry-run (read-only), -i itemize mismatches
  rsync -rcni --exclude='.AppleDB' --exclude='.DS_Store' --exclude='._*' \
    "$DOCS_SRC/" "$DOCS_DST/" > "$OUT_DIR/docs-mismatches.txt"
  echo "Documents mismatched/missing files: $(wc -l < "$OUT_DIR/docs-mismatches.txt")"

  echo "--- Step 3: Byte-for-byte checksum verification (Music) ---"
  rsync -rcni --exclude='.AppleDB' --exclude='.DS_Store' --exclude='._*' \
    "$MUSIC_SRC/" "$MUSIC_DST/" > "$OUT_DIR/music-mismatches.txt"
  echo "Music mismatched/missing files: $(wc -l < "$OUT_DIR/music-mismatches.txt")"

  echo "--- Step 4: Final disk usage on /mnt/mirovia ---"
  du -sh "$DOCS_DST" "$MUSIC_DST"
  echo "=== Finished: $(date) ==="
} | tee "$LOG"
