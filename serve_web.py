#!/usr/bin/env python3
"""
Simple HTTP server to serve the Flutter web build.
This serves the web version while keeping the mobile app unaffected.
"""
import http.server
import socketserver
import os
import sys
from threading import Thread
import webbrowser
import time

# Configuration
WEB_PORT = 3000
WEB_DIR = "build/web"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)
    
    def end_headers(self):
        # Add CORS headers for development
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

def open_browser():
    """Open the web browser after a short delay"""
    time.sleep(2)
    webbrowser.open(f'http://localhost:{WEB_PORT}')

def main():
    # Check if web build exists
    if not os.path.exists(WEB_DIR):
        print(f"Error: {WEB_DIR} directory not found!")
        print("Please run 'flutter build web' first.")
        sys.exit(1)
    
    # Start HTTP server
    with socketserver.TCPServer(("", WEB_PORT), Handler) as httpd:
        print(f"✅ Gelidonia Web Interface başlatıldı!")
        print(f"🌐 Web adresi: http://localhost:{WEB_PORT}")
        print(f"📱 Mobil uygulama etkilenmez (port 8000'de API çalışıyor)")
        print(f"🛑 Durdurmak için Ctrl+C basın")
        print()
        
        # Open browser in background
        browser_thread = Thread(target=open_browser, daemon=True)
        browser_thread.start()
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Web server kapatılıyor...")
            httpd.shutdown()

if __name__ == "__main__":
    main()
