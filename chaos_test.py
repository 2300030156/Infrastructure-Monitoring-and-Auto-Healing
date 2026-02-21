import random
import sys
import time

import requests


def healthcheck(base_url: str, timeout: int = 3) -> bool:
    try:
        response = requests.get(f"{base_url}/health", timeout=timeout)
        return response.status_code == 200
    except requests.RequestException:
        return False


def wait_for_recovery(base_url: str, interval: int = 3) -> None:
    print("[INFO] Waiting for healing and replacement...")
    while True:
        if healthcheck(base_url):
            print("[SUCCESS] Instance recovered!")
            return
        print("[WAIT] Instance still unhealthy. Rechecking...")
        time.sleep(interval)


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python chaos_test.py <LOAD_BALANCER_IP>")
        sys.exit(1)

    ip = sys.argv[1]
    base_url = f"http://{ip}"

    print(f"[START] Chaos test started for {base_url}")

    while True:
        if not healthcheck(base_url):
            print("[WARN] /health is currently unreachable. Waiting for recovery before next crash.")
            wait_for_recovery(base_url)

        sleep_seconds = random.randint(10, 30)
        print(f"[INFO] Healthy. Next crash in {sleep_seconds} seconds...")
        time.sleep(sleep_seconds)

        print("[ACTION] Crashing instance via /crash...")
        try:
            requests.post(f"{base_url}/crash", timeout=3)
        except requests.RequestException:
            pass

        wait_for_recovery(base_url)


if __name__ == "__main__":
    main()
