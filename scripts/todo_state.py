#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

OPEN_CHECKBOX_RE = re.compile(r"^\s*-\s+\[\s\]\s+")
STATUS_RE = re.compile(r"^\s*-\s+\[(?P<status>[^\]]+)\]\s+")
HEADING_RE = re.compile(r"^##\s+(?P<section>.+?)\s*$")

IGNORED_SECTIONS = {
    "Ongoing maintenance",
}

OBJECTIVE_OPEN_STATUSES = {
    "pending",
    "in_progress",
}

BLOCKED_PREFIXES = (
    "blocked",
    "external_blocker",
)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: todo_state.py <todo-file>", file=sys.stderr)
        return 1

    todo_path = Path(sys.argv[1])
    if not todo_path.is_file():
        print(
            json.dumps(
                {
                    "objective_open": 0,
                    "blocked": 0,
                    "maintenance_open": 0,
                    "raw_open": 0,
                }
            )
        )
        return 0

    current_section = ""
    objective_open = 0
    blocked = 0
    maintenance_open = 0
    raw_open = 0

    for raw_line in todo_path.read_text(encoding="utf-8").splitlines():
        heading_match = HEADING_RE.match(raw_line)
        if heading_match:
            current_section = heading_match.group("section")
            continue

        is_open = False
        is_blocked = False

        if OPEN_CHECKBOX_RE.match(raw_line):
            is_open = True
        else:
            status_match = STATUS_RE.match(raw_line)
            if status_match:
                status = status_match.group("status").strip().lower()
                if status in OBJECTIVE_OPEN_STATUSES:
                    is_open = True
                elif any(status.startswith(prefix) for prefix in BLOCKED_PREFIXES):
                    is_blocked = True

        if not is_open and not is_blocked:
            continue

        if current_section in IGNORED_SECTIONS:
            maintenance_open += 1
            continue

        if is_blocked:
            blocked += 1
            raw_open += 1
            continue

        objective_open += 1
        raw_open += 1

    print(
        json.dumps(
            {
                "objective_open": objective_open,
                "blocked": blocked,
                "maintenance_open": maintenance_open,
                "raw_open": raw_open,
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
