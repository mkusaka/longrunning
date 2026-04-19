# GOTCHA

## How to use this file

Record traps that are likely to recur.

## Example entries

### Binary archives should not be dumped into the transcript

- Prefer `tar -tf` or targeted reads.

### Resume and exec may accept different flags

- Verify wrapper behavior for both fresh runs and resumes.

### Stale TODO wording can look like lack of progress

- Audit TODO against landed code before concluding the worker stalled.
