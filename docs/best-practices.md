# Best Practices

## Goal

Make Codex keep working until the real objective is done, instead of:

- stopping after a local green test
- stopping after one crate or subsystem lands
- stopping because the wrapper gave up first
- claiming completion while `TODO.md` still says otherwise

## Best Current Architecture

Use:

- one long-running coding worker
- one outer watchdog/review harness
- repo-local durable state
- external review after the objective gate is clear

Avoid:

- many simultaneous long-running coding workers
- nested review from inside the main worker
- relying on chat transcript memory
- relying on prompt wording alone

The winning shape is:

1. `CODEX_IMPLEMENTATION_PROMPT.md` tells the worker to use durable files.
2. `TODO.md` is the completion gate.
3. `investigate.md` is the research log.
4. `GOTCHA.md` records repeat traps.
5. `run_codex_watchdog.sh` resumes the same session.
6. `run_codex_watchdog_with_review.sh` skips review until TODO is really clear.
7. `run_codex_campaign.sh` keeps batches going until completion or a true blocker.
8. `continue_until_complete.sh` can attach to an already-running finite campaign and chain it into an unlimited one.

## Why Agents Stop Early

### 1. Prompt-only persistence is not enough

Even a strong prompt does not reliably prevent:

- local milestone self-stop
- “I made progress so I should report back now” behavior
- incomplete TODO reconciliation

You need an outer loop that says:

- if the repo still has objective-open TODO items, continue

### 2. Flat TODO counting is wrong

Counting only `- [ ]` is too weak if the repo uses:

- `[pending]`
- `[in_progress]`
- `[blocked]`

Counting every unchecked line is also wrong if the repo keeps a permanent section like:

- `## Ongoing maintenance`

The completion gate must be:

- status-aware
- section-aware

### 3. Wrapper stop policy matters as much as prompt quality

Even a productive worker can still stop for the wrong reason if the outer harness has:

- finite batch ceilings
- stale status files
- broken resume behavior

The real stop condition should be:

- objective-open TODO items are zero and blocked items are zero
- external review has no actionable findings

### 4. Nested review is unreliable

If the main worker spawns its own review worker, you create extra failure modes:

- path/sandbox/cache mismatches
- session confusion
- duplicated control loops

Review should be external.

### 5. Binary dumps poison the transcript

Inspecting `.tgz` or other binary archives with `cat` or `sed` can dump garbage into the context and waste tokens.

Prefer:

- `tar -tf`
- targeted metadata reads
- reading `package.json`, `.yarnrc`, lockfiles, manifests

### 6. Too much parallelism hurts

If you run many Codex processes at once, you can hit:

- file descriptor exhaustion
- session sprawl
- stale state confusion

The sweet spot is:

- one main coding worker
- short-lived sidecar investigations only when needed

## Durable State Rules

The target repo should keep:

- `TODO.md`
- `investigate.md`
- `GOTCHA.md`

### `TODO.md`

Use it as the source of truth for completion.

Recommended statuses:

- `[x]` done
- `[ ]` open
- `[pending]` open
- `[in_progress]` open
- `[blocked: ...]` blocker

Permanent sections like `## Ongoing maintenance` should not block completion.

### `investigate.md`

This is where you record:

- hypothesis
- action
- evidence
- verdict
- next step

If the run is compacted or resumed, this file should be enough to continue.

### `GOTCHA.md`

This is where you record:

- repeated traps
- wrapper quirks
- upstream compatibility edge cases
- tooling landmines

## Recommended Prompt Characteristics

The best long-running prompt is:

- short
- non-interactive
- explicit about durable files
- explicit about stop conditions
- explicit about TODO reconciliation
- explicit about not doing nested review

What it should say:

- read `CODEX_IMPLEMENTATION_PROMPT.md`, `TODO.md`, `investigate.md`, `GOTCHA.md`
- keep working while objective-related TODO items remain
- reconcile TODO after landing real code/tests
- prefer repo-local evidence over speculation
- use the smallest useful test first, then broaden
- do not stop for a local milestone
- do not dump binary archives into the transcript

## Recommended Harness Behavior

The harness should always:

- sync the selected prompt into the target repo before each run
- persist `session_id.txt`
- append iterations under `iter-*`
- resume the same session
- write `watchdog_status.txt`, `review_gate_status.txt`, `campaign_status.txt`
- overwrite stale status files at launch
- parse TODO state after every iteration
- skip review while objective-open TODO items remain
- run review externally when TODO is clear

## Truth Sources During a Live Run

When the run is active, the truth comes from:

1. process tree
2. latest `iter-*` directory
3. latest `run.jsonl`
4. latest `last_message.txt`
5. current `TODO.md` parsed through `todo_state.py`

Do not over-trust stale status files without checking processes and latest iter output.

## When to Use Sidecar Agents

Use short-lived sidecars for:

- stale TODO audits
- upstream code comparisons
- picking the next 2-3 highest-leverage frontiers

Do not use them for:

- parallel long-running implementation on the same write surface
- nested review inside the main worker

## Practical Rule of Thumb

If you want Codex to keep going to the real end:

- make the repo legible
- make completion machine-checkable
- keep one main worker alive
- let an outer harness decide whether work is actually done

That matters more than making the prompt longer.
