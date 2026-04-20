#!/usr/bin/env python3
import json
import sys
import time
from pathlib import Path


def latest_iter_dir(run_root: Path) -> Path | None:
    candidates = sorted(run_root.glob("iter-*"))
    if not candidates:
        return None
    return candidates[-1]


def latest_completed_iter_name(run_root: Path) -> str | None:
    candidates = sorted(run_root.glob("iter-*"))
    for path in reversed(candidates):
        if (path / "last_message.txt").is_file():
            return path.name
    return None


def main() -> int:
    if len(sys.argv) not in {2, 3}:
        print("usage: check_run_state.py <run-root> [stall-seconds]", file=sys.stderr)
        return 1

    run_root = Path(sys.argv[1])
    stall_seconds = int(sys.argv[2]) if len(sys.argv) == 3 else 3600
    now = time.time()

    latest = latest_iter_dir(run_root)
    if latest is None:
        print(
            json.dumps(
                {
                    "status": "empty",
                    "latest_iter": None,
                    "latest_completed_iter": None,
                    "run_jsonl_exists": False,
                    "last_message_exists": False,
                    "run_jsonl_age_seconds": None,
                    "stalled": False,
                }
            )
        )
        return 0

    run_jsonl = latest / "run.jsonl"
    last_message = latest / "last_message.txt"
    run_jsonl_exists = run_jsonl.is_file()
    last_message_exists = last_message.is_file()
    age_seconds = None
    if run_jsonl_exists:
        age_seconds = int(now - run_jsonl.stat().st_mtime)

    stalled = bool(run_jsonl_exists and not last_message_exists and age_seconds is not None and age_seconds >= stall_seconds)

    print(
        json.dumps(
            {
                "status": "active" if run_jsonl_exists and not last_message_exists else "completed",
                "latest_iter": latest.name,
                "latest_completed_iter": latest_completed_iter_name(run_root),
                "run_jsonl_exists": run_jsonl_exists,
                "last_message_exists": last_message_exists,
                "run_jsonl_age_seconds": age_seconds,
                "stalled": stalled,
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
