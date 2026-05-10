import os
import time

import numpy as np
import pyaudio
from openwakeword.model import Model
from openwakeword.utils import download_models

WAKEWORD_THRESHOLD = float(os.getenv("WAKEWORD_THRESHOLD", "0.5"))
OWW_INFERENCE_FRAMEWORK = os.getenv("OWW_INFERENCE_FRAMEWORK", "tflite")
WAKEWORD_MODEL_PATH = os.getenv("WAKEWORD_MODEL_PATH", "alexa_v0.1.tflite")
SAMPLE_RATE = 16000
CHUNK_SIZE = 1280
WAKEWORD_COOLDOWN_SEC = float(os.getenv("WAKEWORD_COOLDOWN_SEC", "1.0"))
WAKEWORD_REARM_SEC = float(os.getenv("WAKEWORD_REARM_SEC", "0.8"))
WAKEWORD_REARM_LOW_FRAMES = int(os.getenv("WAKEWORD_REARM_LOW_FRAMES", "5"))


def ensure_wakeword_models():
    print("openwakeword モデルを確認中...")
    download_models()


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
    armed = True
    rearm_deadline = 0.0
    rearm_low_streak = 0

    print("ウェイクワード待機中...")
    try:
        while True:
            frame = np.frombuffer(stream.read(CHUNK_SIZE, exception_on_overflow=False), dtype=np.int16)
            prediction = model.predict(frame)
            max_score = max(prediction.values(), default=0.0)

            if not armed:
                if time.monotonic() < rearm_deadline:
                    continue

                if max_score < threshold:
                    rearm_low_streak += 1
                    if rearm_low_streak >= WAKEWORD_REARM_LOW_FRAMES:
                        armed = True
                else:
                    rearm_low_streak = 0

                continue

            if any(score >= threshold for score in prediction.values()):
                close_input_stream()
                yield
                time.sleep(WAKEWORD_COOLDOWN_SEC)
                open_input_stream()
                armed = False
                rearm_deadline = time.monotonic() + WAKEWORD_REARM_SEC
                rearm_low_streak = 0
                print("ウェイクワード待機中...")
    finally:
        close_input_stream()