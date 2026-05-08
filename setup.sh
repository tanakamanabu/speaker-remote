#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="${VENV_DIR:-venv}"
MIC_CARD="${MIC_CARD:-ArrayUAC10}"
SPEAKER_CARD="${SPEAKER_CARD:-Speaker}"
ASOUNDRC_PATH="${ASOUNDRC_PATH:-$HOME/.asoundrc}"

echo "[1/4] Python 仮想環境を準備します..."
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

echo "[2/4] 依存パッケージをインストールします..."
VENV_PYTHON="$VENV_DIR/bin/python"
if [ ! -x "$VENV_PYTHON" ]; then
  echo "仮想環境の Python が見つかりません: $VENV_PYTHON" >&2
  exit 1
fi

"$VENV_PYTHON" -m pip install --upgrade pip
PIP_EXTRA_INDEX_URL="${PIP_EXTRA_INDEX_URL:-https://www.piwheels.org/simple}"
"$VENV_PYTHON" -m pip install --prefer-binary --extra-index-url "$PIP_EXTRA_INDEX_URL" -r requirements.txt

echo "[3/4] 音声デバイス設定（~/.asoundrc）を作成/更新します..."
cat > "$ASOUNDRC_PATH" <<EOF
pcm.!default {
  type asym
  playback.pcm "speaker"
  capture.pcm "mic"
}

pcm.speaker {
  type plug
  slave.pcm "plughw:CARD=${SPEAKER_CARD},DEV=0"
}

pcm.mic {
  type plug
  slave.pcm "plughw:CARD=${MIC_CARD},DEV=0"
}

ctl.!default {
  type hw
  card "${SPEAKER_CARD}"
}
EOF

echo "[4/4] 完了"
echo
echo "セットアップが完了しました。"
echo "実行方法: source ${VENV_DIR}/bin/activate && python client.py"
echo "デバイス名確認: aplay -L / arecord -l"
echo "必要に応じて MIC_CARD / SPEAKER_CARD を環境変数で指定して再実行してください。"
