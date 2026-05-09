import os
import subprocess
import time
import uuid

import numpy as np
import pyaudio
import requests
from openwakeword.model import Model
from openwakeword.utils import download_models

SERVER_URL = os.getenv("SERVER_URL", "http://192.168.1.40:8000/voice")
WAKEWORD_THRESHOLD = float(os.getenv("WAKEWORD_THRESHOLD", "0.5"))
OWW_INFERENCE_FRAMEWORK = os.getenv("OWW_INFERENCE_FRAMEWORK", "tflite")
WAKEWORD_MODEL_PATH = os.getenv("WAKEWORD_MODEL_PATH", "alexa_v0.1.tflite")
SAMPLE_RATE = 16000
CHUNK_SIZE = 1280
WAKEWORD_COOLDOWN_SEC = float(os.getenv("WAKEWORD_COOLDOWN_SEC", "1.0"))


def ensure_wakeword_models():
    print("openwakeword モデルを確認中...")
    download_models()

def record(filename="input.wav", duration=3):
    subprocess.run([
        "arecord",
        "-f", "S16_LE",
        "-r", "16000",
        "-d", str(duration),
        filename
    ], check=True)

def send_audio(filename):
    with open(filename, "rb") as f:
        files = {"file": f}
        r = requests.post(SERVER_URL, files=files)
        r.raise_for_status()
        return r.content

def play_audio(data):
    tmp = f"/tmp/{uuid.uuid4()}.wav"
    with open(tmp, "wb") as f:
        f.write(data)

    subprocess.run(["aplay", tmp], check=True)


def wait_for_wakeword(threshold=WAKEWORD_THRESHOLD):
    print(f"openwakeword 推論バックエンド: {OWW_INFERENCE_FRAMEWORK}")
    print(f"openwakeword モデル: {WAKEWORD_MODEL_PATH}")
    model = Model(
        wakeword_models=[WAKEWORD_MODEL_PATH],
        inference_framework=OWW_INFERENCE_FRAMEWORK,
    )

    audio = pyaudio.PyAudio()
    stream = audio.open(
        format=pyaudio.paInt16,
        channels=1,
        rate=SAMPLE_RATE,
        input=True,
        frames_per_buffer=CHUNK_SIZE,
    )

    print("ウェイクワード待機中...")

    try:
        while True:
            frame = np.frombuffer(stream.read(CHUNK_SIZE, exception_on_overflow=False), dtype=np.int16)
            prediction = model.predict(frame)

            if any(score >= threshold for score in prediction.values()):
                return
    finally:
        stream.stop_stream()
        stream.close()
        audio.terminate()


def run_wakeword_loop(threshold=WAKEWORD_THRESHOLD):
    print(f"openwakeword 推論バックエンド: {OWW_INFERENCE_FRAMEWORK}")
    print(f"openwakeword モデル: {WAKEWORD_MODEL_PATH}")
    model = Model(
        wakeword_models=[WAKEWORD_MODEL_PATH],
        inference_framework=OWW_INFERENCE_FRAMEWORK,
    )

    audio = None
    stream = None

    def open_input_stream():
        nonlocal audio, stream
        audio = pyaudio.PyAudio()
        stream = audio.open(
            format=pyaudio.paInt16,
            channels=1,
            rate=SAMPLE_RATE,
            input=True,
            frames_per_buffer=CHUNK_SIZE,
        )

    def close_input_stream():
        nonlocal audio, stream
        if stream is not None:
            stream.stop_stream()
            stream.close()
            stream = None
        if audio is not None:
            audio.terminate()
            audio = None

    open_input_stream()

    print("ウェイクワード待機中...")
    try:
        while True:
            frame = np.frombuffer(stream.read(CHUNK_SIZE, exception_on_overflow=False), dtype=np.int16)
            prediction = model.predict(frame)

            if any(score >= threshold for score in prediction.values()):
                close_input_stream()
                yield
                time.sleep(WAKEWORD_COOLDOWN_SEC)
                open_input_stream()
                print("ウェイクワード待機中...")
    finally:
        close_input_stream()

def main():
    ensure_wakeword_models()

    for _ in run_wakeword_loop():

        print("ウェイクワード検知: 録音開始")
        record()

        print("送信")
        response_audio = send_audio("input.wav")

        print("再生")
        play_audio(response_audio)

if __name__ == "__main__":
    main()
