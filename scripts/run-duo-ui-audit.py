#!/usr/bin/env python3
"""Run built Duo UI tests with native Device Hub pose/rotation and live captures.

Requires macOS Accessibility access for the terminal/Codex, the selected Duo
visible in Device Hub, and a built WaterQuestBottleUI .xctestrun. No simulator
data is erased or seeded here.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import time

RUNNER = "com.waterquest.hydration.bottleuitests.xctrunner"
HUB = "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def hub_button(help_text, device_name):
    # Names come from simctl and the fixed controls below, never shell expansion.
    expected = json.dumps(device_name)
    help_literal = json.dumps(help_text)
    script = f'''tell application "System Events" to tell process "DeviceHub"
        set frontmost to true
        set targetWindow to first window whose name contains {expected}
        perform action "AXRaise" of targetWindow
        set controls to group 1 of splitter group 1 of group 1 of splitter group 1 of group 1 of targetWindow
        click (first button of controls whose help is {help_literal})
    end tell'''
    # Xcode may briefly focus another simulator while installing a UI runner.
    # Reacquire the intended device instead of acting on whichever is frontmost.
    for attempt in range(10):
        try:
            run("osascript", "-e", script)
            return
        except subprocess.CalledProcessError:
            if attempt == 9:
                raise
            time.sleep(0.5)


def display_orientation(device, display):
    ports = run("xcrun", "simctl", "io", device, "enumerate")
    match = re.search(rf"Screen ID: {display}\b.*?UI Orientation: ([^\n]+)", ports, re.S)
    if not match:
        raise RuntimeError("Cannot read native display orientation")
    return match[1].strip().replace(" ", "").lower()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--xctestrun", type=Path, required=True)
    parser.add_argument("--result", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--pose", choices=["open", "partial", "closed"], default="open")
    parser.add_argument("--appearance", choices=["light", "dark"])
    parser.add_argument("--tests", nargs="+", required=True,
                        help="DuoLayoutTests/testTabsFlat, etc.")
    args = parser.parse_args()
    devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json"))
    device = next(d for group in devices["devices"].values() for d in group if d["udid"] == args.device)
    if device.get("deviceTypeIdentifier") != "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo":
        raise ValueError("This coordinator requires an explicitly selected Duo simulator")
    if args.result.exists():
        raise ValueError("Use a fresh result bundle path")
    run("open", "-a", HUB, "--args", "-CurrentDeviceUDID", args.device)
    hub_button({"open": "Open", "partial": "Partially Open", "closed": "Closed"}[args.pose], device["name"])
    display = 1 if args.pose == "closed" else 3
    original_appearance = run("xcrun", "simctl", "ui", args.device, "appearance")
    if args.appearance:
        run("xcrun", "simctl", "ui", args.device, "appearance", args.appearance)

    spec = plistlib.loads(args.xctestrun.read_bytes())
    target = spec["WaterQuestBottleUITests"]
    target.setdefault("EnvironmentVariables", {})["SIPLI_NATIVE_ROTATION"] = "1"
    target.setdefault("TestingEnvironmentVariables", {})["SIPLI_NATIVE_ROTATION"] = "1"
    for key in ("EnvironmentVariables", "TestingEnvironmentVariables"):
        target[key]["SIPLI_NATIVE_COVER_LOCKED"] = "1" if args.pose == "closed" else "0"
    native_spec = args.xctestrun.with_name(f"SipliNativeAudit-{args.device}-{args.pose}.xctestrun")
    native_spec.write_bytes(plistlib.dumps(spec))
    command = ["xcodebuild", "-xctestrun", str(native_spec), "-destination",
               f"platform=iOS Simulator,id={args.device}", "-parallel-testing-enabled", "NO",
               "-resultBundlePath", str(args.result)]
    command += [f"-only-testing:WaterQuestBottleUITests/{test}" for test in args.tests]
    command += ["test-without-building"]
    args.log.parent.mkdir(parents=True, exist_ok=True)
    handled = set()
    folder = None
    last_container_lookup = 0
    process = None
    try:
        with args.log.open("w") as log:
            started_wall = time.time()
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            while process.poll() is None:
                if folder is None or time.monotonic() - last_container_lookup > 5:
                    last_container_lookup = time.monotonic()
                    try:
                        container = run("xcrun", "simctl", "get_app_container", args.device, RUNNER, "data")
                        folder = Path(container) / "tmp/SipliUIAudit"
                    except subprocess.CalledProcessError:
                        time.sleep(0.2)
                        continue
                request = folder / "rotation-request.txt"
                try:
                    fresh_request = request.exists() and request.stat().st_mtime >= started_wall
                    lines = request.read_text().splitlines() if fresh_request else []
                except FileNotFoundError:
                    folder = None
                    continue
                if lines:
                    if len(lines) == 2 and lines[0] not in handled:
                        nonce, orientation = lines
                        desired = {"upsideDown": "portraitupsidedown"}.get(orientation, orientation.lower())
                        # A closed cover display is orientation-locked by iOS.
                        if args.pose != "closed":
                            for _ in range(4):
                                if display_orientation(args.device, display) == desired:
                                    break
                                previous = display_orientation(args.device, display)
                                hub_button("Rotate Right", device["name"])
                                deadline = time.monotonic() + 3
                                while time.monotonic() < deadline:
                                    time.sleep(0.2)
                                    if display_orientation(args.device, display) != previous:
                                        break
                                time.sleep(0.4)
                            if display_orientation(args.device, display) != desired:
                                raise RuntimeError(f"Native display did not rotate to {orientation}")
                        try:
                            (folder / "rotation-ack.txt").write_text(nonce)
                        except FileNotFoundError:
                            folder = None
                            continue
                        handled.add(nonce)
                        print(f"Acknowledged {args.pose}/{orientation}", flush=True)
                time.sleep(0.1)
            print(f"UI test exit: {process.returncode}; log: {args.log}", flush=True)
            return process.returncode
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=20)
        if original_appearance in ("light", "dark"):
            run("xcrun", "simctl", "ui", args.device, "appearance", original_appearance)


if __name__ == "__main__":
    raise SystemExit(main())
