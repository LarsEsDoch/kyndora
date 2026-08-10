import json
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
JSON_PATH = os.path.join(BASE_DIR, "zones.json")

try:
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        TZ_DATABASE = json.load(f)
except FileNotFoundError:
    print(f"WARNUNG: {JSON_PATH} wurde nicht gefunden!")
    TZ_DATABASE = {}


def get_posix_tz(iana_name: str) -> str:
    posix_str = TZ_DATABASE.get(iana_name)

    if posix_str:
        return posix_str

    print(f"Zeitzone '{iana_name}' nicht in zones.json gefunden. Nutze Fallback.")
    return "CET-1CEST,M3.5.0,M10.5.0/3"
