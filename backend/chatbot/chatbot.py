#!/usr/bin/env python3
# backend/chatbot_api/chatbot.py
# A simple CLI client for the VocaTwin Flask chatbot with a deep-blue bouncing-dots loader.
# Requires: pip install requests python-dotenv colorama

import sys
import time
import threading
import requests
import os
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

# Try to enable ANSI colors on Windows
try:
    import colorama
    colorama.init()
except ImportError:
    pass

class BouncingDots:
    """
    Displays three deep-blue dots bouncing (highlighting one at a time) in the terminal.
    """
    def __init__(self, interval: float = 0.4):
        self._stop_event = threading.Event()
        self.interval = interval
        self.thread = threading.Thread(target=self._animate, daemon=True)
        # ANSI escape for deep blue (RGB 0,0,139)
        self.color = '\033[38;2;0;0;139m'
        self.reset = '\033[0m'

    def start(self):
        self.thread.start()

    def stop(self):
        self._stop_event.set()
        self.thread.join()
        # Clear the line
        sys.stdout.write('\r' + ' ' * 10 + '\r')
        sys.stdout.flush()

    def _animate(self):
        idx = 0
        while not self._stop_event.is_set():
            # Build three-dot string, coloring the active one
            parts = []
            for i in range(3):
                dot = '●'
                if i == idx:
                    dot = f"{self.color}●{self.reset}"
                parts.append(dot)
            sys.stdout.write('\r' + ' '.join(parts))
            sys.stdout.flush()
            idx = (idx + 1) % 3
            time.sleep(self.interval)

class VocaTwinChatCLI:
    """CLI wrapper for interacting with the VocaTwin Flask chatbot."""
    def __init__(self):
        # Endpoint URL, default to localhost if not set
        base = os.getenv('VOCATWIN_API_URL', 'http://localhost:5001')
        self.endpoint = base.rstrip('/') + '/chat'
        self.history = []

    def send(self, message: str) -> str:
        payload = {'text': message}
        resp = requests.post(self.endpoint, json=payload, timeout=30)
        if resp.status_code == 200:
            data = resp.json()
            return data.get('message', '')
        return f"⚠️ API Error {resp.status_code}: {resp.text}"

    def clear_history(self):
        self.history.clear()
        print("🗑️ Conversation history cleared.")

    def show_stats(self):
        user_msgs = sum(1 for m in self.history if m['role']=='user')
        bot_msgs  = sum(1 for m in self.history if m['role']=='assistant')
        print(f"📊 Conversation Stats: {user_msgs} user, {bot_msgs} bot")

    def run(self):
        print("🤖 VocaTwin CLI Chatbot")
        print("Endpoint:", self.endpoint)
        print("Commands: 'exit', 'clear', 'stats', 'help'\n")
        while True:
            try:
                prompt = input("You: ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\n👋 Goodbye!")
                break
            if not prompt:
                continue
            cmd = prompt.lower()
            if cmd in ('exit','quit','bye'):
                print("👋 Goodbye!")
                break
            if cmd == 'clear':
                self.clear_history()
                continue
            if cmd == 'stats':
                self.show_stats()
                continue
            if cmd == 'help':
                print("Commands:\n - 'exit' or 'quit' or 'bye' to exit\n - 'clear' to clear history\n - 'stats' to show stats\n - 'help' to show this message")
                continue
            # Send and display reply
            self.history.append({'role':'user','content':prompt})
            loader = BouncingDots()
            loader.start()
            try:
                reply = self.send(prompt)
            finally:
                loader.stop()
            self.history.append({'role':'assistant','content':reply})
            print(f"VocaTwin: {reply}")

if __name__ == '__main__':
    VocaTwinChatCLI().run() 