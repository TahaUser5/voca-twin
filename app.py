# app.py
from flask import Flask, request, jsonify, send_file
from TTS.api import TTS
import uuid
import os

app = Flask(__name__)

# Load model
tts = TTS(model_name="tts_models/en/vctk/vits")

@app.route('/speak', methods=['POST'])
def speak():
    text = request.json.get("text")
    if not text:
        return jsonify({"error": "Text is required"}), 400

    output_path = f"output/{uuid.uuid4().hex}.wav"
    os.makedirs("output", exist_ok=True)

    tts.tts_to_file(text=text, file_path=output_path)
    return send_file(output_path, mimetype="audio/wav")

@app.route('/clone_and_tts', methods=['POST'])
def clone_and_tts():
    text = request.form.get("text")
    audio = request.files.get("audio")

    if not text or not audio:
        return jsonify({"error": "Text and audio are required"}), 400

    # Save the uploaded audio file
    input_audio_path = f"input/{uuid.uuid4().hex}.wav"
    os.makedirs("input", exist_ok=True)
    audio.save(input_audio_path)

    # Generate cloned TTS audio
    output_path = f"output/{uuid.uuid4().hex}.wav"
    os.makedirs("output", exist_ok=True)
    tts.tts_to_file(text=text, speaker_wav=input_audio_path, file_path=output_path)

    return send_file(output_path, mimetype="audio/wav")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
