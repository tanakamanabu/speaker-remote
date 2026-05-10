import subprocess
import uuid


def record(filename="input.wav", duration=3):
    subprocess.run([
        "arecord",
        "-f", "S16_LE",
        "-r", "16000",
        "-d", str(duration),
        filename,
    ], check=True)


def play_audio(data):
    tmp = f"/tmp/{uuid.uuid4()}.wav"
    with open(tmp, "wb") as f:
        f.write(data)

    subprocess.run(["aplay", tmp], check=True)