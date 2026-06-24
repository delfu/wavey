#!/usr/bin/env bash
# Demucs guitar-separation spike (DEL-199).
#
# Isolates the guitar stem from a song using htdemucs_6s (the 6-source Demucs,
# which has a dedicated `guitar` stem) so we can JUDGE guitar-stem quality before
# committing to the on-device Core ML conversion. This runs the model in Python/
# PyTorch — the quality is the same as the eventual on-device model; only the
# runtime differs.
#
# Usage:  tools/demucs_separate.sh "path/to/song.mp3" [output_dir]
# Needs a Python with torch wheels (3.10–3.13). Creates a venv at /tmp/demucs-venv.
set -euo pipefail

INPUT="${1:?usage: demucs_separate.sh <audio file> [output dir]}"
OUT="${2:-/tmp/demucs-out}"
PYBASE="${PYBASE:-/Users/delfu/.pyenv/versions/3.12.13/bin/python}"
VENV=/tmp/demucs-venv

if [ ! -x "$VENV/bin/demucs" ]; then
  "$PYBASE" -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet demucs
fi

# 6-stem: vocals / drums / bass / other / guitar / piano
"$VENV/bin/python" -m demucs -n htdemucs_6s -o "$OUT" "$INPUT"

echo "Stems written under: $OUT/htdemucs_6s/"
