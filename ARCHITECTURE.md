# Architecture and tradeoffs

## Flow and data

```
Flutter app ──HTTPS/JSON, Bearer token──▶ Rails /api/v1 ──▶ SuggestionGenerator ──▶ AI provider adapter
 (iOS sim)                                    │                     │                 (Fake | Claude)
                                              │                     ▼
                                              │             Ai::ResponseValidator
                                              ▼                     │
                                         PostgreSQL ◀───────────────┘
```

| Table | Purpose and key constraints |
| --- | --- |
| `organizations`, `users` | Seeded tenants and people. `users.api_token_digest` holds a SHA-256 digest of the dev token. |
| `meetings` | Title and notes, belonging to an organization and an author. |
| `suggestion_generations` | One row per AI attempt: status, provider/model, prompt version, error code, validation report, raw response. Partial unique index: at most one `running` row per meeting. |
| `suggestions` | AI proposals: description, owner, due date, source quote. Status is checked: `pending`, `accepted`, `dismissed` or `superseded`. |
| `action_items` | Accepted work: the reviewer's edited fields, the original `source_quote` as provenance, and `completed_at`. A unique index on `suggestion_id` means one action per suggestion. |

## Boundaries

- **Authentication.** A development-only shortcut, `POST /api/v1/dev/session`, issues a random token and stores only its digest. Dev routes exist only in development and test.
- **Organization scoping.** Every lookup goes through `current_organization.meetings`, `.suggestions` or `.action_items`, so another org's ID returns the same 404 as a missing record. Clients never send an org ID; a submitted `organization_id` is ignored. `AccessIsolationTest` covers every read and write endpoint.
- **Credentials.** `ANTHROPIC_API_KEY` lives only in `backend/.env`, which git ignores, or in the server environment. The app never sees it.
- **Untrusted notes.** Notes and title are wrapped in `<meeting_notes>`/`<meeting_title>` tags, and any copy of those tags inside the text is escaped. The system prompt says the content is data, not instructions. The model has no tools, and nothing it returns is ever auto-accepted.
- **Response validation (`Ai::ResponseValidator`).** Structure and JSON types are all-or-nothing. If the response isn't JSON, has the wrong shape, extra or missing keys, wrong types, or more than 25 items, nothing is stored and the API returns `invalid_ai_response`.
- **Per-item grounding.** An item is dropped if:
  - its quote isn't a whole-word excerpt of the notes (differences in whitespace or curly quotes are tolerated);
  - its quote is shorter than 3 words;
  - its description is blank; or
  - it duplicates another item.

  An owner is cleared unless the name appears in that item's own quote. A due date is cleared unless it's a valid ISO date that the quote states explicitly, either as ISO or written out like "February 12, 2027". Relative or ambiguous dates never count. Requiring owner and date to appear in the quote is deliberately conservative: an owner named in a different sentence is dropped, and the reviewer can add it back. Drops and cleared fields are recorded on the generation.
- **Limits of semantic validation.** The validator can't tell whether a grounded quote is really a commitment rather than discussion; a quoted spam line can still become a pending suggestion. It can't tell whether the description matches the quote, or whether a name in the quote is actually the assignee. Those depend on the model, the eval cases, and the human reviewer, which is why acceptance is always explicit.

## Failure and concurrency

- **Repeated or concurrent acceptance.** `SuggestionAcceptance` locks the suggestion row (`SELECT … FOR UPDATE`), returns any existing action with 200, or creates one with 201. The unique index on `action_items.suggestion_id` is the real invariant: if the lock were removed, a duplicate insert raises and is resolved to the existing action. The concurrency test was checked by deliberately breaking the code. Without the lock, the index alone kept it to one action. Without both the lock and the duplicate-key handling, the test failed 3 of 3 runs.
- **Concurrent generation.** The partial unique index lets only one `running` generation exist per meeting. A double tap or a client retry gets `409 generation_in_progress`. A run left `running` for more than 2 minutes, for example after a server crash, is marked `stale` so it stops blocking. A stale run that later finishes discards its results instead of overwriting newer ones.
- **Provider errors.** The provider is called outside any database transaction. Timeouts return 504 `provider_timeout`. Rate limits, 5xx and connection failures return 502 and are retryable. Authentication or bad requests return 502 and are not retryable. A refusal returns `provider_refused`. An unknown `AI_PROVIDER` setting returns 502 `provider_misconfigured`, not retryable. An unexpected crash during generation marks the run failed and returns 500 `internal_error`, retryable. Any other unexpected error on any endpoint returns 500 `internal_error` in the same JSON error format, with details only in the server log. A failed run never touches existing suggestions, and the user can generate again. The SDK uses a 25 s timeout with one retry, and the app waits 75 s.
- **Client timeout while the server continues.** The server finishes and stores the result. The app shows "The server took too long… refresh before trying again" with a **Refresh** button, which loads `GET /meetings/:id`. If the run succeeded, the stored suggestions appear. If it failed, the latest generation's error is shown with **Try again**. A retry while the run is still going gets 409 and is told to refresh. No duplicate actions can appear, because nothing is auto-accepted.
- **Synchronous by choice.** One request with no job infrastructure keeps the exercise small. The cost is a long-held request and a Puma thread per generation. The generation row already works like a job record, so moving to a background job is mostly a transport change.

## Production evolution

- **Monitoring.** `suggestion_generations` already records status, error code, provider/model, prompt version and timestamps. Add token usage and latency columns and dashboards for failure rate by `error_code`, p95 latency and cost per org. Alert on spikes in `invalid_ai_response` and `provider_refused`, which point to prompt or model drift.
- **Higher usage.** Move generation to Active Job (Solid Queue). Add per-user and per-org rate limits and a daily cost budget. Deduplicate identical notes by content hash, and paginate list endpoints.
- **Older mobile clients.** The API is versioned under `/api/v1`, and JSON fields are only ever added, never renamed or removed. The client ignores unknown fields and status values. The app sends `X-Client: meeting-action-flutter/1`, which could later drive a `426 Upgrade Required` minimum-version check. Breaking changes would go to `/api/v2`, with v1 kept until old installs fall off.
- **Migrations.** Use expand-then-contract (add a column, backfill, switch readers, drop later) so old app and server versions keep working during deploys. Restore is a PostgreSQL backup; generations and suggestions can be regenerated, but accepted actions are the record to protect.
- **Production auth.** Replace the dev token with real sign-in (OIDC or SSO), short-lived tokens, and Keychain/Keystore storage on the device.

## Current state

- **Implemented:**
  - Every endpoint and screen in the required flow.
  - Org isolation, duplicate-safe acceptance, validation and grounding, and the fake provider with injectable failures.
  - The Claude adapter, the evaluation runner, 94 backend tests, 9 Flutter tests, and a live headless UI-to-API journey test.
- **Incomplete or unverified:**
  - The real Anthropic adapter has been run against the live API only for the 5 evaluation cases and one extra note (2026-10-30); all passed.
  - The app hasn't run on an iOS simulator on this machine yet, because Xcode needs `sudo xcodebuild -runFirstLaunch`.
  - No demo video yet.
- **Next three improvements, ordered by importance:**
  1. Run the real-provider evaluation and tune the prompt.
  2. Move generation to a background job and have the app poll.
  3. Add rate limits and cost/latency metrics.
