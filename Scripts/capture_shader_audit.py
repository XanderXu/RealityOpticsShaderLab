#!/usr/bin/env python3
"""Run the opt-in DEBUG simulator smoke audit and capture each default material.

Build/install the Debug app first. This uses the app's audit hook, not UI gestures.
The log proves loading/binding; screenshots still require visual inspection.
"""
import argparse
import os
from pathlib import Path
import subprocess
import threading


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", default="booted")
    parser.add_argument("--effect", choices=["thinFilm", "grating", "nacre", "opal", "birefringence", "speckle", "morpho", "beetle", "feather", "hologram", "lcd", "newton", "pearl", "dragonfly", "chameleon", "scarab"])
    parser.add_argument("--output", type=Path, default=Path("artifacts/shader-audit"))
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--performance", action="store_true", help="Check lazy caches and instances instead of screenshots")
    mode.add_argument("--preview", action="store_true", help="Check paired shapes and base colors; capture five comparison views")
    args = parser.parse_args()
    if (args.performance or args.preview) and args.effect:
        parser.error("--performance/--preview starts with thinFilm; omit --effect")
    args.output.mkdir(parents=True, exist_ok=True)
    bundle = "com.reality.RealityOpticsShaderLab"
    env = dict(os.environ)
    flag = "SIMCTL_CHILD_OPTICS_PREVIEW_AUDIT" if args.preview else ("SIMCTL_CHILD_OPTICS_PERF_AUDIT" if args.performance else "SIMCTL_CHILD_OPTICS_AUDIT")
    env[flag] = "1"
    marker = "OPTICS_PREVIEW_AUDIT" if args.preview else ("OPTICS_PERF_AUDIT" if args.performance else "OPTICS_AUDIT")
    if args.effect:
        env.update(SIMCTL_CHILD_OPTICS_EFFECT=args.effect, SIMCTL_CHILD_OPTICS_AUDIT_ONLY_SELECTED="1")
    command = ["xcrun", "simctl", "launch", "--console", "--terminate-running-process", args.device, bundle]
    process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    watchdog = threading.Timer(360, process.terminate)
    watchdog.start()
    passed = False
    captured = set()
    try:
        with (args.output / "runtime.log").open("w") as log:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if "OPTICS_AUDIT" in line or "OPTICS_PERF" in line or "OPTICS_PREVIEW_AUDIT" in line:
                    print(line.strip(), flush=True)
                if line.startswith("OPTICS_AUDIT FAIL:"):
                    raise RuntimeError(line.strip())
                if line.startswith(("OPTICS_AUDIT DEFAULT ", "OPTICS_PREVIEW_AUDIT CAPTURE ")):
                    effect = line.split()[2]
                    subprocess.run(["xcrun", "simctl", "io", args.device, "screenshot", "--type=jpeg",
                                    str(args.output / f"{effect}.jpg")], check=True, capture_output=True)
                    captured.add(effect)
                if line.startswith(marker + " PASS:"):
                    passed = True
                    break
    finally:
        watchdog.cancel()
        subprocess.run(["xcrun", "simctl", "terminate", args.device, bundle], capture_output=True)
        process.terminate()
        process.wait(timeout=10)
    expected = 5 if args.preview else (0 if args.performance else (1 if args.effect else 16))
    if not passed or len(captured) != expected:
        raise SystemExit(f"Incomplete audit: passed={passed}, screenshots={len(captured)}; inspect runtime.log")
    print(f"PASS: {expected} screenshots and runtime.log saved to {args.output}")


if __name__ == "__main__":
    main()
