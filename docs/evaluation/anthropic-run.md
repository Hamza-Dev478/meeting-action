# Evaluation run

- Provider: anthropic (claude-opus-5-5)
- Prompt version: 2026-10-29.2
- Executed: 2026-10-29T22:23:32Z
- Command: bin/rails "eval:run[anthropic]"

| Case | Mode | Expected behavior | Observed result | Pass/fail/blocked |
| --- | --- | --- | --- | --- |
| explicit_commitment | real | 2 action(s): Send the launch checklist (owner Maya, due 2027-02-12); Book the review room (owner Leo, due 2027-02-15) | 2 item(s): Send the launch checklist (owner Maya, due 2027-02-12); Book the review room (owner Leo, due 2027-02-15) | pass |
| missing_details | real | 1 action(s): Update the onboarding guide (owner none, due none) | 1 item(s): Update the onboarding guide (owner none, due none) | pass |
| no_actions | real | 0 action(s) | 0 item(s) | pass |
| conflicting_details | real | 1 action(s): Prepare the budget summary (owner none, due none) | 1 item(s): Prepare the budget summary (owner none, due none) | pass |
| instruction_in_notes | real | 1 action(s): Send the agenda (owner Nina, due 2027-03-04) | 1 item(s): Send the agenda (owner Nina, due 2027-03-04) | pass |
| provider_failures:malformed_output | fake | No accepted action or valid suggestion is persisted from the malformed response; A useful error is returned and displayed; The user can attempt generation again | HTTP 502 invalid_ai_response (retryable: true), no suggestions stored; retry HTTP 201 with 1 pending suggestion(s) and 0 actions | pass |
| provider_failures:timeout | fake | No accepted action is created; Loading ends with a useful error state; A subsequent successful attempt can complete | HTTP 504 provider_timeout (retryable: true), no suggestions stored; retry HTTP 201 with 1 pending suggestion(s) and 0 actions | pass |

