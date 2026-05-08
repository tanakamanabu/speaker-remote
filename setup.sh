#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="${VENV_DIR:-venv}"
MIC_CARD="${MIC_CARD:-ArrayUAC10}"
SPEAKER_CARD="${SPEAKER_CARD:-Speaker}"
ASOUNDRC_PATH="${ASOUNDRC_PATH:-$HOME/.asoundrc}"

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

ensure_apt_packages python3-venv python3-full build-essential pkg-config portaudio19-dev
ensure_portaudio_build_env

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

if ! "$VENV_PYTHON" -m pip --version >/dev/null 2>&1; then
  echo "仮想環境内の pip が見つかりません。venv を作り直してください。" >&2
  echo "  rm -rf ${VENV_DIR} && bash setup.sh" >&2
  exit 1
fi

PIP_VERSION_OUTPUT="$($VENV_PYTHON -m pip --version 2>/dev/null || true)"
case "$PIP_VERSION_OUTPUT" in
  *"$VENV_DIR"*) ;;
  *)
    echo "仮想環境外の pip を参照している可能性があります: $PIP_VERSION_OUTPUT" >&2
    echo "次を実行してから venv を作り直してください:" >&2
    echo "  sudo apt update && sudo apt install -y python3-venv python3-full" >&2
    echo "  rm -rf ${VENV_DIR} && bash setup.sh" >&2
    exit 1
    ;;
esac

"$VENV_PYTHON" -m pip install --upgrade pip
PIP_EXTRA_INDEX_URL="${PIP_EXTRA_INDEX_URL:-https://www.piwheels.org/simple}"
TMPDIR="${TMPDIR:-/var/tmp}"
if [ ! -d "$TMPDIR" ]; then
  echo "TMPDIR が存在しないため作成します: $TMPDIR"
  mkdir -p "$TMPDIR"
fi
echo "pip 一時ディレクトリ: $TMPDIR"
TMPDIR="$TMPDIR" "$VENV_PYTHON" -m pip install --no-cache-dir --prefer-binary --extra-index-url "$PIP_EXTRA_INDEX_URL" -r requirements.txt

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
