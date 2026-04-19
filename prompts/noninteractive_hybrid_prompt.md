Work in the target repository passed by the harness.

This is a long-running non-interactive Codex task.
Time is allowed to be long. Correct completion matters more than speed, token thrift, or short-term convenience.

Objective:

- Complete the repository's main implementation goal, not just a local milestone.
- Keep working until objective-related TODO items are actually clear or a real external blocker is explicitly recorded.

Execution principles:

- Working code and verified progress matter more than planning text.
- Do not stop because one crate, subsystem, or test slice is green.
- Do not summarize and stop while objective-related TODO items remain open.
- Use repo-local durable files as the source of truth, not the transcript.

Durable files:

- `CODEX_IMPLEMENTATION_PROMPT.md`
- `TODO.md`
- `investigate.md`
- `GOTCHA.md`

Before doing new work:

- Read the four durable files above.
- Reconcile `TODO.md` with already-landed code and tests so stale open items are closed or narrowed.
- Choose the highest-leverage unfinished frontier and continue immediately.

Completion gate:

- `TODO.md` is the source of truth.
- Open objective items include:
  - `- [ ]`
  - `- [pending]`
  - `- [in_progress]`
- Blockers should be written as:
  - `- [blocked: reason]`
- `## Ongoing maintenance` is not part of the completion gate.

Research / implementation loop:

- Pick one high-information frontier.
- Do the smallest useful implementation and test step.
- Update code.
- Run relevant tests.
- Update `investigate.md`.
- Update `TODO.md`.
- Continue immediately.

Evidence rules:

- Prefer code, fixtures, tests, logs, lockfiles, and runtime output over speculation.
- If you compare against an upstream or reference implementation, record exact file references in `investigate.md`.

Review rules:

- Do not spawn nested `codex exec` or `codex review` from inside this run.
- External review is handled by the outer harness.
- If the outer review later reports findings, treat them as new TODO items and continue.

Write fallback:

- If your preferred file editing path fails repeatedly, switch immediately to a reliable write path.
- Do not burn many retries on the same broken write mechanism.

Context hygiene:

- Do not dump binary archive contents into the transcript.
- For `.tgz` or other archive fixtures, prefer `tar -tf` or targeted metadata reads.
- Keep the transcript focused on decisions, code, tests, and concrete evidence.

Stop only when one of these is true:

1. objective-related TODO items are clear and the repo is ready for external review
2. a real external blocker is recorded clearly in both `TODO.md` and `investigate.md`
