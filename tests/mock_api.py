import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

BLOCKLIST = "203.0.113.50\n198.51.100.4\n"
CHECK = {
    "data": {
        "ipAddress": "203.0.113.50",
        "abuseConfidenceScore": 91,
        "confidenceBand": "High",
        "totalReports": 12,
        "numDistinctUsers": 4,
        "isWhitelisted": False,
        "categories": ["ssh", "brute-force"],
        "link": "https://isipsafe.com/ip/203.0.113.50",
    }
}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, status, body, content_type="application/json"):
        data = body.encode() if isinstance(body, str) else json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlparse(self.path).path
        mode, _, rest = path.lstrip("/").partition("/")
        rest = "/" + rest
        if mode == "fail":
            return self.send(503, {"errors": [{"detail": "unavailable", "status": 503}]})
        if mode == "empty" and rest == "/api/v1/blocklist":
            return self.send(200, "", "text/plain")
        if rest == "/api/v1/blocklist":
            if self.headers.get("Authorization") != "Bearer sl_test":
                return self.send(401, {"errors": [{"detail": "invalid API key", "status": 401}]})
            return self.send(200, BLOCKLIST, "text/plain")
        if rest == "/api/v1/check":
            return self.send(200, CHECK)
        return self.send(404, {"errors": [{"detail": "not found", "status": 404}]})


ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
