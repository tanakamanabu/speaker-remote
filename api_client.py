import os

import requests

VOICE_API_URL = os.getenv("SERVER_URL", "http://192.168.1.40:8000/voice")


def send_audio_to_voice_api(filename):
    with open(filename, "rb") as f:
        files = {"file": f}
        response = requests.post(VOICE_API_URL, files=files)
        response.raise_for_status()
        return response.content