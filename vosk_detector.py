import json
import os
import wave

from vosk import KaldiRecognizer, Model

VOSK_MODEL_PATH = os.getenv("VOSK_MODEL_PATH", "vosk-model-ja-0.22")
FIXED_COMMANDS = [
    "ライトオン",
    "ライトオフ",
    "冷房オン",
    "暖房オン",
    "エアコンオフ",
    "学習開始",
    "パソコンつけて",
]


def detect_word_with_vosk(filename="input.wav"):
    print(f"Vosk モデル: {VOSK_MODEL_PATH}")
    model = Model(VOSK_MODEL_PATH)

    with wave.open(filename, "rb") as wav_file:
        recognizer = KaldiRecognizer(model, wav_file.getframerate())
        recognized_texts = []

        while True:
            data = wav_file.readframes(4000)
            if len(data) == 0:
                break

            if recognizer.AcceptWaveform(data):
                result = json.loads(recognizer.Result())
                text = result.get("text", "")
                if text:
                    recognized_texts.append(text)

        final_result = json.loads(recognizer.FinalResult())
        final_text = final_result.get("text", "")
        if final_text:
            recognized_texts.append(final_text)

    recognized_text = " ".join(recognized_texts).strip()
    detected_commands = [command for command in FIXED_COMMANDS if command in recognized_text]
    found = bool(detected_commands)
    if found:
        print(f"Vosk 固定コマンド検出: {', '.join(detected_commands)}")
    else:
        print("Vosk 固定コマンド検出: 未検出")

    print(f"Vosk 認識結果: {recognized_text}")
    return found, recognized_text