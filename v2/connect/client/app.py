import os
import time
import urllib.request
import urllib.error


def fetch_message(host: str, port: int, retries: int = 10, delay: float = 1.0) -> str:
    url = f"http://{host}:{port}/"
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(url, timeout=5) as response:
                return response.read().decode("utf-8")
        except (urllib.error.URLError, TimeoutError) as exc:
            print(f"[CLIENT] Attempt {attempt} failed: {exc}")
            time.sleep(delay)
    raise RuntimeError(f"Failed to reach {url} after {retries} attempts")


def main():
    host = os.environ.get("SERVER_HOST", "server")
    port = int(os.environ.get("SERVER_PORT", "8080"))
    message = fetch_message(host, port)
    print("[CLIENT] Received:")
    print(message, end="")


if __name__ == "__main__":
    main()
