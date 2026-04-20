# Runbook

## 1. Prepare the Target Repo

Copy the durable files and prompt into the target repo:

```bash
bash scripts/bootstrap_repo_state.sh /path/to/target-repo
```

This creates, when missing:

- `CODEX_IMPLEMENTATION_PROMPT.md`
- `TODO.md`
- `investigate.md`
- `GOTCHA.md`

## 2. Start a Mainline Campaign

Use the supervised launcher for a fresh long-running job:

```bash
bash scripts/run_codex_campaign_supervised.sh \
  /path/to/target-repo \
  prompts/noninteractive_hybrid_prompt.md \
  /path/to/run-root \
  30 gpt-5.4 3600 12
```

Arguments:

- repo path
- prompt file
- run root
- `poll_seconds`
- model
- `stall_seconds`
- `max_iterations_per_batch`

What it does:

- starts an unlimited campaign
- attaches a supervisor
- watches for a live iteration that stops updating output
- kills and relaunches the campaign when that happens

If you want the lower-level primitives, you can still call:

```bash
bash scripts/run_codex_campaign.sh \
  /path/to/target-repo \
  prompts/noninteractive_hybrid_prompt.md \
  /path/to/run-root \
  0 12 3 gpt-5.4
```

## 3. Understand the Process Tree

You will usually see several processes, but they represent only a few roles:

- campaign
- watchdog-with-review
- watchdog
- actual `codex exec resume`
- optional continue supervisor

The important distinction is:

- one real coding worker
- one outer control loop

## 4. Inspect Progress

Parse live TODO state:

```bash
python3 scripts/todo_state.py /path/to/target-repo/TODO.md
```

Inspect latest iterations:

```bash
find /path/to/run-root -maxdepth 1 -type d -name 'iter-*' | sort
```

Inspect latest completed assistant message:

```bash
python3 - <<'PY'
from pathlib import Path
run_root = Path("/path/to/run-root")
iters = sorted([p.name for p in run_root.glob("iter-*")])
for name in reversed(iters):
    p = run_root / name / "last_message.txt"
    if p.exists():
        print(name)
        print(p.read_text(errors="replace"))
        break
PY
```

Inspect latest run tail:

```bash
python3 - <<'PY'
from pathlib import Path
run_root = Path("/path/to/run-root")
iters = sorted([p.name for p in run_root.glob("iter-*")])
latest = run_root / iters[-1] / "run.jsonl"
lines = latest.read_text(errors="replace").splitlines()
print("\n".join(lines[-10:]))
PY
```

## 5. If a Finite Campaign Is Already Running

Do not kill it just to switch to a better harness.

Attach a supervisor:

```bash
bash scripts/continue_until_complete.sh \
  <campaign-pid> \
  /path/to/target-repo \
  prompts/noninteractive_hybrid_prompt.md \
  /path/to/run-root
```

This waits for the current campaign to end, then relaunches an unlimited campaign if:

- objective-open TODO items remain
- there are no blocked TODOs

It also kills and relaunches the campaign if:

- the latest live `iter-*` has `run.jsonl`
- `last_message.txt` is still missing
- and `run.jsonl` has not changed for longer than the configured stall threshold

## 6. Review Gate Behavior

Review runs only after:

- `objective_open == 0`
- `blocked == 0`

The external review script writes structured JSON to:

- `review-round-XX/review.json`

If findings are present, the same session resumes with those findings added back into the main loop.

## 7. Common Failure Modes

### The repo looks complete, but `objective_open` stays high

Usually means:

- `TODO.md` is stale

Action:

- inspect the latest completed iter
- audit stale TODO items
- narrow old TODO wording to remaining real work

### `campaign_status.txt` says exhausted, but processes still run

Usually means:

- stale status file

Action:

- trust process tree and latest iter first

### The run keeps talking but not landing code

Usually means:

- the prompt is too report-heavy
- the session is bloated
- the frontier is too vague

Action:

- tighten the prompt
- make the next frontier concrete
- let the watchdog resume with a sharper prompt

### Review never runs

Usually means:

- TODO gate never cleared

Action:

- inspect `TODO.md`
- reconcile landed work
- check ignored sections like `Ongoing maintenance`

### The run gets slow over time

Usually means:

- repeated resume on a very long thread

Action:

- accept that persistence costs speed
- avoid unnecessary sidecars
- only restart intentionally if the current thread stops being productive

### The process is alive but the latest iteration never finishes

Usually means:

- the worker is wedged
- the process is alive but no longer making progress

Action:

- use the supervised launcher so this is handled automatically
- or attach `continue_until_complete.sh` with a stall threshold

You can inspect the live run state directly:

```bash
python3 scripts/check_run_state.py /path/to/run-root 3600
```

## 8. Minimal Operating Checklist

- bootstrap durable repo files
- start supervised unlimited campaign
- watch TODO gate, not feelings
- use sidecars only for focused investigation
- never let inner worker run its own review
- only call the run done after external review passes
