from audio import play_audio, record
from api_client import send_audio_to_voice_api
from wakeword import ensure_wakeword_models, run_wakeword_loop


def main():
    ensure_wakeword_models()

    for _ in run_wakeword_loop():

        print("ウェイクワード検知: 録音開始")
        record()

        print("送信")
        response_audio = send_audio_to_voice_api("input.wav")

        print("再生")
        play_audio(response_audio)

if __name__ == "__main__":
    main()
