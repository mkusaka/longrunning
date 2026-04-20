# longrunning

Long-running Codex harness kit for repositories that need:

- durable repo-local task state
- a watchdog that resumes unfinished sessions
- an external review gate
- a supervisor that keeps campaigns alive until the objective is actually done

This repository is based on repeated real-world runs where Codex otherwise tended to:

- stop after a local milestone instead of the main objective
- leave `TODO.md` stale relative to landed code
- confuse stale status files with live status
- lose progress when the outer wrapper stopped before the repo was actually done

Start here:

- [docs/best-practices.md](docs/best-practices.md)
- [docs/runbook.md](docs/runbook.md)
- [prompts/noninteractive_hybrid_prompt.md](prompts/noninteractive_hybrid_prompt.md)

Recommended topology:

- `1` long-running coding worker
- `1` outer watchdog/review harness
- `0-2` short-lived sidecar investigations only when needed

Repository layout expected in the target repo:

- `CODEX_IMPLEMENTATION_PROMPT.md`
- `TODO.md`
- `investigate.md`
- `GOTCHA.md`

Quick start:

```bash
bash scripts/bootstrap_repo_state.sh /path/to/target-repo

bash scripts/run_codex_campaign_supervised.sh \
  /path/to/target-repo \
  prompts/noninteractive_hybrid_prompt.md \
  /path/to/run-root \
  30 gpt-5.4 3600 12
```

If you already have a finite campaign in flight and do not want to interrupt it:

```bash
bash scripts/continue_until_complete.sh \
  <campaign-pid> \
  /path/to/target-repo \
  prompts/noninteractive_hybrid_prompt.md \
  /path/to/run-root \
  30 gpt-5.4 3600
```

Contents:

- `docs/`
  - why this works
  - failure modes
  - operating model
  - troubleshooting
- `prompts/`
  - the current best prompt shape for non-interactive long runs
- `templates/`
  - durable state file templates
- `scripts/`
  - reusable shell/python harness pieces
- `schemas/`
  - JSON schema used by the external review gate

References:

- OpenAI Harness Engineering: <https://openai.com/index/harness-engineering/>
- OpenAI Cookbook, GPT-5 Codex Prompting Guide: <https://cookbook.openai.com/examples/gpt-5-codex_prompting_guide>
- OpenAI Cookbook, Using PLANS.md for multi-hour problem solving: <https://cookbook.openai.com/articles/codex_exec_plans/>
- Karpathy autoresearch: <https://github.com/karpathy/autoresearch>
