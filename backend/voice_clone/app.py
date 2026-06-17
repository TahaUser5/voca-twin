from flask import Flask, request, send_file
import subprocess
import os
import sys
from werkzeug.utils import secure_filename

app = Flask(__name__)
UPLOAD_FOLDER = "uploads"
OUTPUT_PATH = "static/output.wav"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs("static", exist_ok=True)

@app.route("/synthesize", methods=["POST"])
def synthesize():
    print("Received /synthesize request")  # Debug log
    if 'speaker' not in request.files or 'text' not in request.form:
        print("Error: Missing speaker or text")  # Debug log
        return {"error": "Missing speaker or text"}, 400

    speaker_file = request.files["speaker"]
    text = request.form["text"]
    
    filename = secure_filename(speaker_file.filename)
    speaker_path = os.path.join(UPLOAD_FOLDER, filename)
    speaker_file.save(speaker_path)
    print(f"Saved speaker file to: {speaker_path}")  # Debug log

    try:
        # Run TTS
        result = subprocess.run([
            "tts",
            "--model_name", "tts_models/multilingual/multi-dataset/your_tts",
            "--speaker_wav", speaker_path,
            "--text", text,
            "--out_path", OUTPUT_PATH,
            "--language_idx", "en"
        ], capture_output=True, text=True, check=True)
        print(f"TTS subprocess completed: {result.stdout}")  # Debug log
    except subprocess.CalledProcessError as e:
        print(f"TTS subprocess failed: {e.stderr}")  # Debug log
        return {"error": f"TTS process failed: {e.stderr}"}, 500
    except FileNotFoundError:
        print("Error: 'tts' command not found")  # Debug log
        return {"error": "TTS command not found. Is Coqui TTS installed?"}, 500

    if not os.path.exists(OUTPUT_PATH):
        print(f"Error: Output file not created at {OUTPUT_PATH}")  # Debug log
        return {"error": "Output audio file not created"}, 500

    print(f"Sending output file: {OUTPUT_PATH}")  # Debug log
    # Auto-open the generated audio file on the server
    try:
        if os.name == "nt":
            os.startfile(OUTPUT_PATH)
        elif sys.platform == "darwin":
            subprocess.run(["open", OUTPUT_PATH])
        else:
            subprocess.run(["xdg-open", OUTPUT_PATH])
    except Exception as e:
        print(f"Failed to auto-open audio file: {e}")

    return send_file(OUTPUT_PATH, mimetype="audio/wav")

@app.route('/', methods=['GET'])
def index():
    return 'Voice Clone API is running', 200

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)