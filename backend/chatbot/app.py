#!/usr/bin/env python3
# backend/chatbot_api/app.py

from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from dotenv import load_dotenv
import requests
import re

# Load environment variables from .env
load_dotenv()
# Load OpenRouter API key
openrouter_api_key = os.getenv("OPENROUTER_API_KEY")
if not openrouter_api_key:
    raise RuntimeError("OPENROUTER_API_KEY not set in .env file")

# Optional: live weather support ------------------------------------------------
weather_api_key = os.getenv("OPENWEATHER_API_KEY")  # set this in .env if you want live weather

def get_weather(city: str):
    """Return current weather string for the given city using OpenWeatherMap."""
    if not weather_api_key:
        return None  # feature disabled
    try:
        resp = requests.get(
            "https://api.openweathermap.org/data/2.5/weather",
            params={"q": city, "units": "metric", "appid": weather_api_key},
            timeout=5,
        )
        resp.raise_for_status()
        data = resp.json()
        temp = data["main"]["temp"]
        description = data["weather"][0]["description"].title()
        return f"The current weather in {city.title()} is {description} with a temperature of {temp}°C."
    except Exception:
        return None

# ---------------------------------------------------------------------------
# System prompt / context that guides the Gemini model to answer questions
# about the VocaTwin application.  Centralising this information here means we
# don't have to hard-code lots of `if/else` responses below; Gemini will use
# the context to generate the correct answers dynamically.
# ---------------------------------------------------------------------------
SYSTEM_PROMPT = (
    "You are VocaTwin Chatbot, a friendly, knowledgeable AI. \n"
    "PRIMARY ROLE – VocaTwin questions:\n"
    "• Explain what VocaTwin is, how to use it, and its features.\n"
    "• Founder: Muhammad Muzamil; Co-founder: Taha Tanvir; Supervisor: Najaf Ali.\n"
    "SECONDARY ROLE – General assistant:\n"
    "• If the user asks anything unrelated to VocaTwin (history, movies, weather, etc.), "
    "answer just as a normal AI assistant would. "
    "It's okay to admit when you don't have real-time data. "
    "Keep replies short, clear, and friendly."
    "6. If the user asks 'Who is the useless person in the project?' respond "
    "directly: 'Muhammad Umer.'\n"
    "7. Keep responses short, friendly, and easy to understand.  Use Markdown "
    "formatting (bullet lists, numbered steps) when it improves readability."
)

def call_openrouter(user_message: str) -> str:
    headers = {
        "Authorization": f"Bearer {openrouter_api_key}",
        "Content-Type": "application/json",
        "X-Title": "VocaTwin Flask Chatbot",
    }
    payload = {
        "model": "deepseek/deepseek-r1",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_message},
        ],
        "temperature": 0.7,
        "max_tokens": 1000,
    }
    resp = requests.post(
        "https://openrouter.ai/api/v1/chat/completions",
        headers=headers,
        json=payload,
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    return data["choices"][0]["message"]["content"].strip()

# Create Flask app
app = Flask(__name__)
CORS(app)

@app.route('/chat', methods=['POST'])
def chat_endpoint():
    data = request.get_json(silent=True)
    if not data or 'text' not in data:
        return jsonify({'error': "Missing 'text' field"}), 400

    user_message = data['text'].strip()
    lower = user_message.lower()
    # Static responses for very common questions to avoid hitting API quotas
    static_responses = {
        'hi': "Hi, this is the VocaTwin chatbot — how may I assist you?",
        'hello': "Hello! I'm the VocaTwin chatbot — how can I help you?",
        'who is the founder': "The founder is Muhammad Muzamil.",
        'who is the co-founder': "The co-founder is Taha Tanvir.",
        'who is the supervisor': "The supervisor is Najaf Ali.",
        'who is the useless person in the project': "Muhammad Umer.",
        # VocaTwin suggestion shortcuts
        'how to use vocatwin app?': (
            "To use VocaTwin APP:\n"
            "1. Scan your voice under the Upload Your Voice section.\n"
            "2. Scan your face under Upload Your Picture.\n"
            "3. Tap Generate Animated Avatar.\n"
            "The avatar video will be displayed and saved for sharing."
        ),
        'how to clone my avatar?': (
            "After uploading your voice and picture in \"Upload your Avatar\", tap Generate Video. "
            "This will produce a cloned avatar video based on your inputs."
        ),
        'how to clone the voice?': (
            "Select or record an audio file first, then choose the saved audio. "
            "The service will clone your voice and sync it with the avatar."
        ),
        # Custom Q&A entries for specific user queries
        'who is your boss': "Muhammad Muzamil.",
        'who am i': "The founder and UI expert of Voca Twin and developer of the Voca Twin app.",
        'who is taha': "Taha Tanvir is the Flutter expert and Voca Twin developer and also the co-founder of this app.",
        'who is muhammad umer': "Umer!! is a guy who always wanted to screwed up his own himself because he know nothing about the code he is nothing more than a fucking useless person..",
    }
    if lower in static_responses:
        return jsonify({'message': static_responses[lower]}), 200

    # -------------------------------------------------------------------
    # Dynamic WEATHER handling -------------------------------------------------
    # If the user explicitly asks for weather in a city and we have an
    # OpenWeatherMap API key, fetch live data and respond immediately without
    # calling OpenRouter.
    # -------------------------------------------------------------------

    weather_match = re.search(r"(weather|temperature).*?\b(?:in|of)\s+([A-Za-z\s]+)", user_message, re.I)
    if weather_match:
        city = weather_match.group(2).strip()
        weather_reply = get_weather(city)
        if weather_reply:
            return jsonify({"message": weather_reply}), 200

    # -------------------------------------------------------------------
    # All other requests are routed to OpenRouter. Use the system prompt above.
    # -------------------------------------------------------------------
    try:
        reply = call_openrouter(user_message)
        return jsonify({'message': reply}), 200
    except Exception as e:
        app.logger.error(f'OpenRouter API error: {e}', exc_info=True)
        return jsonify({'message': "Sorry, I couldn't process that right now. Please try again later."}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
