#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="${VENV_DIR:-venv}"
MIC_CARD="${MIC_CARD:-ArrayUAC10}"
SPEAKER_CARD="${SPEAKER_CARD:-Speaker}"
ASOUNDRC_PATH="${ASOUNDRC_PATH:-$HOME/.asoundrc}"
VOSK_MODEL_PATH="${VOSK_MODEL_PATH:-vosk-model-ja-0.22}"
VOSK_MODEL_ZIP_URL="${VOSK_MODEL_ZIP_URL:-https://alphacephei.com/vosk/models/vosk-model-ja-0.22.zip}"
UV_BIN=""

run_as_root() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  echo "この処理には root 権限が必要です。root で実行するか sudo をインストールしてください。" >&2
  exit 1
}

ensure_apt_packages() {
  local packages=("$@")
  local failed_packages=()
  local package

  echo "APT パッケージを確認し、不足分をインストールします..."
  run_as_root apt update

  for package in "${packages[@]}"; do
    echo "APT インストール: ${package}"
    if ! run_as_root env DEBIAN_FRONTEND=noninteractive apt install -y "$package"; then
      failed_packages+=("$package")
      echo "APT インストール失敗: ${package}" >&2
    fi
  done

  if [ "${#failed_packages[@]}" -gt 0 ]; then
    echo "次の APT パッケージ導入に失敗しました: ${failed_packages[*]}" >&2
    echo "ネットワークやAPTミラー状態を確認し、失敗パッケージを個別に再実行してください。" >&2
    exit 1
  fi
}

ensure_uv() {
  if command -v uv >/dev/null 2>&1; then
    UV_BIN="$(command -v uv)"
    return
  fi

  if [ -x "$HOME/.local/bin/uv" ]; then
    UV_BIN="$HOME/.local/bin/uv"
    return
  fi

  echo "uv が見つからないためインストールします..."
  if command -v curl >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://astral.sh/uv/install.sh | sh
  else
    echo "uv のインストールに curl または wget が必要です。" >&2
    exit 1
  fi

  if [ -x "$HOME/.local/bin/uv" ]; then
    UV_BIN="$HOME/.local/bin/uv"
  elif command -v uv >/dev/null 2>&1; then
    UV_BIN="$(command -v uv)"
  else
    echo "uv のインストールに失敗しました。" >&2
    exit 1
  fi
}

ensure_portaudio_build_env() {
  if ! pkg-config --exists portaudio-2.0; then
    echo "portaudio-2.0 が見つかりません。APT インストールに失敗している可能性があります。" >&2
    echo 'sudo apt update && sudo apt install -y portaudio19-dev pkg-config を確認してください。' >&2
    exit 1
  fi

  local cflags
  local libs
  cflags="$(pkg-config --cflags portaudio-2.0)"
  libs="$(pkg-config --libs portaudio-2.0)"

  if [ ! -f /usr/include/portaudio.h ] && [ ! -f /usr/local/include/portaudio.h ] && [ ! -f /usr/include/aarch64-linux-gnu/portaudio.h ]; then
    echo "portaudio.h が見つかりません。portaudio19-dev が正しく導入されていない可能性があります。" >&2
    exit 1
  fi

  echo "PyAudio ビルド用 CFLAGS: ${cflags:-<none>}"
  echo "PyAudio ビルド用 LDFLAGS: ${libs:-<none>}"

  export CFLAGS="${CFLAGS:-} ${cflags}"
  export CPPFLAGS="${CPPFLAGS:-} ${cflags}"
  export LDFLAGS="${LDFLAGS:-} ${libs}"
}

ensure_apt_packages build-essential pkg-config portaudio19-dev curl
ensure_uv
ensure_portaudio_build_env

echo "[1/5] Python 仮想環境を準備します..."
"$UV_BIN" python install 3.11
"$UV_BIN" venv --python 3.11 --seed "$VENV_DIR"

echo "[2/5] 依存パッケージをインストールします..."
VENV_PYTHON="$VENV_DIR/bin/python"
if [ ! -x "$VENV_PYTHON" ]; then
  echo "仮想環境の Python が見つかりません: $VENV_PYTHON" >&2
  exit 1
fi

if ! "$VENV_PYTHON" -m pip --version >/dev/null 2>&1; then
  echo "仮想環境内の pip が見つかりません。venv を作り直してください。" >&2
  echo "  rm -rf ${VENV_DIR} && bash setup.sh" >&2
  exit 1
fi

PIP_VERSION_OUTPUT="$($VENV_PYTHON -m pip --version 2>/dev/null || true)"
echo "pip バージョン情報: $PIP_VERSION_OUTPUT"

"$VENV_PYTHON" -m pip install --upgrade pip
PIP_EXTRA_INDEX_URL="${PIP_EXTRA_INDEX_URL:-https://www.piwheels.org/simple}"
TMPDIR="${TMPDIR:-/var/tmp}"
if [ ! -d "$TMPDIR" ]; then
  echo "TMPDIR が存在しないため作成します: $TMPDIR"
  mkdir -p "$TMPDIR"
fi
echo "pip 一時ディレクトリ: $TMPDIR"
TMPDIR="$TMPDIR" "$VENV_PYTHON" -m pip install --no-cache-dir --prefer-binary --extra-index-url "$PIP_EXTRA_INDEX_URL" -r requirements.txt

echo "[3/5] Vosk 日本語モデルを確認します..."
if [ -d "$VOSK_MODEL_PATH" ]; then
  echo "Vosk モデルは既に存在します: $VOSK_MODEL_PATH"
else
  echo "Vosk モデルをダウンロードします: $VOSK_MODEL_ZIP_URL"
  "$VENV_PYTHON" - "$VOSK_MODEL_ZIP_URL" <<'PY'
import pathlib
import sys
import tempfile
import urllib.request
import zipfile

url = sys.argv[1]
with tempfile.TemporaryDirectory() as tmpdir:
    zip_path = pathlib.Path(tmpdir) / "vosk_model.zip"
    urllib.request.urlretrieve(url, zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(pathlib.Path.cwd())
PY

  if [ ! -d "$VOSK_MODEL_PATH" ]; then
    echo "Vosk モデル展開後にディレクトリが見つかりません: $VOSK_MODEL_PATH" >&2
    exit 1
  fi
fi

echo "[4/5] 音声デバイス設定（~/.asoundrc）を作成/更新します..."
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

echo "[5/5] 完了"
echo
echo "セットアップが完了しました。"
echo "実行方法: source ${VENV_DIR}/bin/activate && python main.py"
echo "デバイス名確認: aplay -L / arecord -l"
echo "必要に応じて MIC_CARD / SPEAKER_CARD を環境変数で指定して再実行してください。"
