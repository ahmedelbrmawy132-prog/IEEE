import time
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class MockAIServiceHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        # Read incoming request body
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        correlation_id = self.headers.get('X-Correlation-ID', 'mock-uuid-0000')

        # Scenario 1: Simulating full service failure / crash
        if self.path == "/predict/fail":
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {"error": "AI inference engine crashed", "correlation_id": correlation_id}
            self.wfile.write(json.dumps(response).encode())
            return

        # Scenario 2: Simulating SLA breach (latency > 1.5s)
        if self.path == "/predict/timeout":
            time.sleep(2.0)

        # Scenario 3: Healthy AI Response
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("X-Correlation-ID", correlation_id)
        self.end_headers()

        response = {
            "status": "success",
            "risk_score": 0.35,
            "latency_ms": 120,
            "correlation_id": correlation_id,
            "is_fallback": False
        }
        self.wfile.write(json.dumps(response).encode())

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    server = HTTPServer(("0.0.0.0", port), MockAIServiceHandler)
    print(f"Mock AI Service listening on port {port}...")
    server.serve_forever()