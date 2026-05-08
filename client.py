import subprocess
import requests
import uuid

SERVER_URL = "http://192.168.1.40:8000/voice" 

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

def main():
    print("録音開始")
    record()

    print("送信")
    response_audio = send_audio("input.wav")

    print("再生")
    play_audio(response_audio)

if __name__ == "__main__":
    main()
