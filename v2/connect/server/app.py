import os
from http.server import BaseHTTPRequestHandler, HTTPServer


MESSAGE = os.environ.get("GREETING", "Hello from the server container!")


class DemoHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = f"{MESSAGE}\n".encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        # Keep container logs tidy
        print(f"[SERVER] {self.address_string()} - {format % args}")


def run():
    port = int(os.environ.get("PORT", "8080"))
    server = HTTPServer(("0.0.0.0", port), DemoHandler)
    print(f"[SERVER] Listening on 0.0.0.0:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        print("[SERVER] Shutdown")


if __name__ == "__main__":
    run()
