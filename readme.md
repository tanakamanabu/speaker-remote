# Raspberry Pi 音声クライアント

ラズパイ上で動作する、シンプルな音声クライアントです。
マイクで録音 → サーバーへHTTP送信 → 応答音声を再生、という最小構成を実装しています。

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

### 1. ディレクトリ作成

```bash
mkdir ~/voice
cd ~/voice
```

---

### 2. 仮想環境の作成

```bash
python3 -m venv venv
```

有効化：

```bash
source venv/bin/activate
```

---

### 3. 依存パッケージ

```bash
pip install requests
```

---

### 4. client.py 配置

このリポジトリの `client.py` を配置してください。

---

## 実行方法

```bash
source venv/bin/activate
python client.py
```

---

## 動作フロー

1. マイクで音声を録音（arecord）
2. サーバーへHTTP POST
3. サーバーから音声（wav）を受信
4. スピーカーで再生（aplay）

---

## サーバー側仕様

* エンドポイント: `POST /voice`
* リクエスト: `multipart/form-data`（wavファイル）
* レスポンス: `audio/wav`

---

## 音声デバイス設定（重要）

USBデバイスを固定するため、`~/.asoundrc` を設定してください。

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

* ウェイクワード対応
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


