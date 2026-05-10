from audio import record
from wakeword import ensure_wakeword_models, run_wakeword_loop
from vosk_detector import detect_word_with_vosk


def main():
    ensure_wakeword_models()

    for _ in run_wakeword_loop():

        print("ウェイクワード検知: 録音開始")
        record()

        print("Vosk でワード検出")
        detect_word_with_vosk("input.wav")

if __name__ == "__main__":
    main()
