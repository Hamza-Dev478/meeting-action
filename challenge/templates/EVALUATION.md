# Evaluation results

## Environment

- Provider/model and configuration:
- Prompt location/version or commit:
- Execution date:
- Fake-provider command:
- Real-provider command:
- Real-provider runs completed or blocked, with reason:

## Cases

Use semantic acceptance criteria from the supplied fixture. Label the mode for each result; do not count fake outputs as real extraction quality.

| Case | Mode: real/fake | Expected behavior | Observed result or artifact | Pass/fail/blocked |
| --- | --- | --- | --- | --- |
| explicit_commitment | | | | |
| missing_details | | | | |
| no_actions | | | | |
| conflicting_details | | | | |
| instruction_in_notes | | | | |
| provider_failures: malformed output | fake | | | |
| provider_failures: timeout | fake | | | |

## Application checks

Record actual commands/results for access isolation, repeated acceptance, persistence, provider failures, and Flutter behavior. Distinguish automated tests from manual observations.

## Findings

- Failures and limitations:
- One change made after evaluation, if any:
- What these few cases cannot establish:
