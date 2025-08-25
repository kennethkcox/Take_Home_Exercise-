import requests
import sys

def run_smoke_test(base_url):
    """
    Runs smoke tests against the Juice Shop application to verify WAF rules.
    """
    print("--- Running Smoke Tests ---")

    # Test 1: Benign request to the homepage
    try:
        print(f"[*] Testing benign request to: {base_url}/")
        response = requests.get(base_url, timeout=10)
        if response.status_code == 200:
            print(f"  [+] SUCCESS: Received {response.status_code} OK")
        else:
            print(f"  [-] FAILURE: Expected 200 OK, but received {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"  [-] FAILURE: Request failed: {e}")

    print("-" * 20)

    # Test 2: Malicious SQL injection request
    malicious_url = f"{base_url}/rest/products/search?q=%27%20OR%201=1--"
    try:
        print(f"[*] Testing malicious SQLi request to: {malicious_url}")
        response = requests.get(malicious_url, timeout=10)
        if response.status_code == 403:
            print(f"  [+] SUCCESS: Received {response.status_code} Forbidden (WAF blocked the request)")
        else:
            print(f"  [-] FAILURE: Expected 403 Forbidden, but received {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"  [-] FAILURE: Request failed: {e}")

    print("--- Smoke Tests Complete ---")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python smoke_test.py <base_url>")
        sys.exit(1)

    base_url = sys.argv[1]
    run_smoke_test(base_url)
