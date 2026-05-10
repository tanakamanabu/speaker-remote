import json
import os
import wave

from vosk import KaldiRecognizer, Model

VOSK_MODEL_PATH = os.getenv("VOSK_MODEL_PATH", "vosk-model-small-ja-0.22")
COMMANDS = {
    "ライトオン": "ライト オン",
    "ライトオフ": "ライト オフ",
    "冷房オン": "冷房 オン",
    "暖房オン": "暖房 オン",
    "エアコンオフ": "エアコン オフ",
    "学習開始": "学習 開始",
    "パソコンつけて": "パソコン つけて",
}
FIXED_COMMANDS = list(COMMANDS.keys())
VOSK_GRAMMAR = json.dumps(list(COMMANDS.values()) + ["[unk]"], ensure_ascii=False)

_VOSK_MODEL = None


def get_vosk_model():
    global _VOSK_MODEL
    if _VOSK_MODEL is None:
        print(f"Vosk モデルを読み込みます: {VOSK_MODEL_PATH}")
        _VOSK_MODEL = Model(VOSK_MODEL_PATH)
    return _VOSK_MODEL


def normalize_text(text):
    return text.replace(" ", "").replace("　", "")


def detect_word_with_vosk(filename="input.wav"):
    print(f"Vosk モデル: {VOSK_MODEL_PATH}")
    model = get_vosk_model()

    with wave.open(filename, "rb") as wav_file:
        recognizer = KaldiRecognizer(model, wav_file.getframerate(), VOSK_GRAMMAR)
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
    normalized_recognized_text = normalize_text(recognized_text)

    detected_commands = []
    for command in FIXED_COMMANDS:
        grammar_command = COMMANDS.get(command, command)
        if normalize_text(command) in normalized_recognized_text or normalize_text(grammar_command) in normalized_recognized_text:
            detected_commands.append(command)

    found = bool(detected_commands)
    if found:
        print(f"Vosk 固定コマンド検出: {', '.join(detected_commands)}")
    else:
        print("Vosk 固定コマンド検出: 未検出")

    print(f"Vosk 認識結果: {recognized_text}")
    return found, recognized_text