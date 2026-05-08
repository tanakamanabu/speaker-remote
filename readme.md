# Raspberry Pi 音声クライアント

ラズパイ上で動作する、シンプルな音声クライアントです。
`openwakeword` でウェイクワードを検知したら録音を開始し、サーバーへ送信して応答音声を再生します。

---

## 構成

```
voice/
├── client.py          # メインスクリプト
├── venv/              # Python仮想環境
└── README.md
```

---

## 前提環境

* Raspberry Pi OS（Debian系）
* USBマイク / USBスピーカーが認識済み
* `arecord` / `aplay` が使用可能

---

## セットアップ

### 0. 1コマンドで実行（推奨）

```bash
bash setup.sh
```

依存関係は `requirements.txt` からインストールされます。
`setup.sh` は `--prefer-binary` で wheel を優先し、既定で `piwheels` を参照して `numpy` のビルド失敗を起きにくくしています。

`piwheels` を使いたくない場合は、環境変数で上書きできます。

```bash
PIP_EXTRA_INDEX_URL="" bash setup.sh
```

必要に応じてデバイス名を環境変数で指定できます。

```bash
MIC_CARD=ArrayUAC10 SPEAKER_CARD=Speaker bash setup.sh
```

## 実行方法

```bash
source venv/bin/activate
python client.py
```

必要に応じて環境変数で挙動を調整できます。

```bash
SERVER_URL=http://192.168.1.40:8000/voice WAKEWORD_THRESHOLD=0.6 python client.py
```

推論バックエンドは既定で `tflite` を使います（安定動作用）。
必要な場合のみ `onnx` へ切り替えてください。

```bash
OWW_INFERENCE_FRAMEWORK=onnx python client.py
```

---

## 動作フロー

1. `openwakeword` でウェイクワードを待機
2. ウェイクワード検知後に音声を録音（arecord）
3. サーバーへHTTP POST
4. サーバーから音声（wav）を受信
5. スピーカーで再生（aplay）

---

## サーバー側仕様

* エンドポイント: `POST /voice`
* リクエスト: `multipart/form-data`（wavファイル）
* レスポンス: `audio/wav`

---

## 音声デバイス設定（重要）

USBデバイスを固定するため、`~/.asoundrc` を設定してください。

`setup.sh` 実行時に `~/.asoundrc` は自動生成・更新されます。
手動で設定する場合は以下を利用してください。

```conf
pcm.!default {
  type asym
  playback.pcm "speaker"
  capture.pcm "mic"
}

pcm.speaker {
  type plug
  slave.pcm "plughw:CARD=Speaker,DEV=0"
}

pcm.mic {
  type plug
  slave.pcm "plughw:CARD=ArrayUAC10,DEV=0"
}

ctl.!default {
  type hw
  card "Speaker"
}
```

※ `aplay -L` / `arecord -l` でデバイス名は確認できます。

---

## 注意点

### PEP 668 による pip 制限

Raspberry Pi OS ではグローバルな `pip install` が制限されています。
必ず仮想環境（venv）を使用してください。

`source venv/bin/activate` 後でも同じエラーが出る場合は、`pip` が仮想環境のものを見ていない可能性があります。
その場合は必ず次のように実行してください。

```bash
venv/bin/python -m pip install -r requirements.txt
```

それでも `externally-managed-environment` が出る場合は、壊れた仮想環境を掴んでいる可能性があります。
`setup.sh` は `python3-venv` / `python3-full` を自動インストールするため、次で作り直してください。

```bash
rm -rf venv
bash setup.sh
```

確認コマンド:

```bash
which python
which pip
python -m pip --version
```

`.../venv/bin/...` を指していればOKです。

### `numpy` のインストールで失敗する場合

`requirements.txt` では `numpy<2` を指定しています。
さらに `setup.sh` は binary wheel を優先し、既定で `piwheels` を使うため、ソースビルド由来の失敗を回避しやすくなっています。

### `PyAudio` のインストールで `portaudio.h` エラーが出る場合

`setup.sh` は `build-essential`（gcc など）/ `portaudio19-dev` / `pkg-config` を事前に自動インストールしてから Python 依存を入れます。
さらに `pkg-config` から取得した `CFLAGS` / `LDFLAGS` を使って `PyAudio` をビルドするため、ヘッダ探索パス差異がある環境でも失敗しにくくしています。
APT パッケージは1件ずつ導入し、失敗したパッケージ名を表示して停止します。
このため通常は手動対応不要です。`sudo` が使えない環境では root で `setup.sh` を実行してください。

```bash
bash setup.sh
```

### `No space left on device` が出る場合

`df -h` で `/` に空きがあっても、`/tmp` が小さい（tmpfs）環境だと `pip` の一時展開で容量不足になることがあります。
`setup.sh` は `TMPDIR` を使って一時ディレクトリを切り替えられるので、次を実行してください。

```bash
TMPDIR=/var/tmp bash setup.sh
```

`/tmp` を使いたい場合は、キャッシュ削減のため `--no-cache-dir`（`setup.sh` に設定済み）を利用してください。

---

### デバイス番号の変動

USBの抜き差しで card 番号が変わるため、
**CARD名で指定する構成を推奨**します。

---

### Wi-Fi

* 2.4GHz推奨（安定性）
* mDNSは環境依存のため、固定IP推奨

---

## 今後の拡張

* Whisperによる音声認識
* VOICEVOXによる音声応答
* systemdでの常駐化

---

## トラブルシュート

### 音が出ない

* `alsamixer` でミュート確認
* HDMI出力になっていないか確認

---

### マイクが動かない

* `arecord -l` でデバイス確認
* 入力ゲイン調整


