import requests

# Define API endpoint (localhost for now)
url = "http://127.0.0.1:5000/synthesize"

# Path to a local .wav file to use as the speaker
speaker_file = "2.wav"  # Replace with an actual .wav path

# Text you want to synthesize
text = "Hello, this is a test of voice cloning using Coqui TTS."

# Create the POST request
with open(speaker_file, "rb") as f:
    files = {"speaker": f}
    data = {"text": text}
    response = requests.post(url, files=files, data=data)

# Save the received audio if successful
if response.status_code == 200:
    with open("result.wav", "wb") as out:
        out.write(response.content)
    print("✅ Synthesis complete. Saved as result.wav.")
else:
    print(f"❌ Error: {response.status_code}")
    print(response.text)
