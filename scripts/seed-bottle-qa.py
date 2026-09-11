#!/usr/bin/env python3
"""Replace Sipli data only on an explicitly named, dedicated QA simulator."""

import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import uuid


APP_ID = "com.waterquest.hydration"
DEVICE_NAME = "Sipli Bottle QA"
REPOSITORY = Path(__file__).resolve().parents[1]


def simctl(*arguments: str) -> str:
    return subprocess.run(
        ["xcrun", "simctl", *arguments], check=True, text=True, capture_output=True
    ).stdout.strip()


def intake_amount(value: str) -> float:
    amount = float(value)
    if not math.isfinite(amount) or not 0 <= amount <= 10_000:
        raise argparse.ArgumentTypeError("intake must be finite and between 0 and 10000 ml")
    return amount


def fixture(intake_ml: float, suppress_achievements: bool) -> dict:
    timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    full_chunks, remainder = divmod(intake_ml, 500)
    volumes = [500.0] * int(full_chunks)
    if remainder:
        volumes.append(remainder)
    achievements = {}
    if suppress_achievements:
        source = (REPOSITORY / "WaterQuest/Models/Achievement.swift").read_text()
        catalog = source.split("enum AchievementCatalog {", 1)[1]
        ids = re.findall(r'Achievement\s*\(\s*id:\s*"([^"]+)"', catalog)
        if not ids or len(ids) != len(set(ids)):
            raise ValueError("could not read a unique, nonempty AchievementCatalog")
        achievements = dict.fromkeys(ids, timestamp)
    return {
        "entries": [
            {
                "id": str(uuid.uuid4()).upper(), "date": timestamp,
                "volumeML": volume, "source": "manual", "fluidType": "water",
            }
            for volume in volumes
        ],
        "profile": {
            "name": "Alex", "unitSystem": "metric", "weightKg": 70,
            "activityLevel": "steady", "customGoalML": 2000,
            "remindersEnabled": False, "wakeMinutes": 420, "sleepMinutes": 1320,
            "prefersWeatherGoal": False, "prefersHealthKit": False,
            "smartRemindersEnabled": False,
        },
        "lastWeather": None,
        "lastWorkout": {"exerciseMinutes": 0, "activeEnergyKcal": 0},
        "hasPremiumAccess": False,
        "premiumUpsellState": {"dismissCount": 0},
        "goalCompletionCount": 0, "matchDayWins": 0, "streakFreezeTokens": 0,
        "streakFreezeDates": [], "unlockedAchievements": achievements,
        "counters": {"siriLogCount": 0, "widgetLogCount": 0, "undoCount": 0},
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, type=uuid.UUID, help="explicit simulator UUID")
    parser.add_argument("--intake-ml", type=intake_amount, default=0,
                        help="today's water intake, 0–10000 ml (default: 0)")
    parser.add_argument("--suppress-achievements", action="store_true",
                        help="preunlock catalog badges to suppress overlays during UI tests")
    args = parser.parse_args()
    device_id = str(args.device).upper()
    devices = json.loads(simctl("list", "devices", "available", "--json"))["devices"]
    matches = [device for group in devices.values() for device in group
               if device["udid"].upper() == device_id]
    if len(matches) != 1 or matches[0]["name"] != DEVICE_NAME:
        raise ValueError(f"refusing to seed: device must be named exactly {DEVICE_NAME!r}")
    if matches[0]["state"] != "Booted":
        raise ValueError("boot the dedicated QA simulator before seeding")

    # Signed builds may use an app group instead. This helper deliberately
    # supports the unsigned simulator build documented alongside the tests.
    container = Path(simctl("get_app_container", device_id, APP_ID, "data"))
    if not container.is_absolute() or not container.is_dir() or container.is_symlink():
        raise ValueError("simctl did not return a valid application data container")
    expected = (device_id, "data", "Containers", "Data", "Application")
    parts = container.parts
    if not any(tuple(parts[index:index + 5]) == expected for index in range(len(parts) - 5)):
        raise ValueError("application container does not belong to the requested simulator")
    payload = fixture(args.intake_ml, args.suppress_achievements)

    stopped = subprocess.run(["xcrun", "simctl", "terminate", device_id, APP_ID],
                             text=True, capture_output=True)
    if stopped.returncode:
        error = (stopped.stderr + stopped.stdout).lower()
        if not any(message in error for message in
                   ("not running", "no such process", "found nothing to terminate")):
            raise RuntimeError(f"could not stop Sipli before seeding: {stopped.stderr.strip()}")

    support = container / "Library/Application Support"
    if support.is_symlink() or (container / "Library").is_symlink():
        raise ValueError("refusing to follow a symlink outside the app container")
    support.mkdir(parents=True, exist_ok=True)
    target = support / "WaterQuestState.json"
    temporary = support / f".bottle-qa-{uuid.uuid4()}.json"
    try:
        temporary.write_text(json.dumps(payload, indent=2) + "\n")
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"Seeded {DEVICE_NAME} ({device_id}): {args.intake_ml:g}/2000 ml, "
          f"{len(payload['entries'])} entries, "
          f"{len(payload['unlockedAchievements'])} preunlocked badges. App is stopped.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, IndexError, OSError, RuntimeError,
            subprocess.CalledProcessError) as error:
        print(f"Seed failed: {error}", file=sys.stderr)
        sys.exit(1)
