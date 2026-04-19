# investigate

## How to use this file

Record durable, restart-safe evidence here.

Suggested loop format:

- Hypothesis:
- Action:
- Evidence:
- Verdict:
- Next:
- Refs:

## Example entry

### 2026-04-20 initial frontier

- Hypothesis:
  - The current stop cause is a wrapper issue, not a product implementation limit.
- Action:
  - Read the latest completed run iteration and compare `TODO.md` against landed code.
- Evidence:
  - `iter-07/last_message.txt` shows code landed and tests passed.
  - `TODO.md` still marks that slice open.
- Verdict:
  - Keep
- Next:
  - Reconcile TODO, then continue with the next frontier.
- Refs:
  - `TODO.md`
  - `iter-07/last_message.txt`
