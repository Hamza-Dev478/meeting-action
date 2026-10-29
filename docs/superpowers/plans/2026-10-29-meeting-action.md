# Meeting → Action Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Rails + PostgreSQL API and a Flutter (iOS simulator) client that turn meeting notes into AI-proposed, human-reviewed action items, with org isolation and duplicate-safe acceptance.

**Architecture:** Rails 8.1 API-only app in `backend/` exposes `/api/v1` JSON endpoints behind a dev-only bearer-token login. A provider adapter boundary (`Ai::Providers::Fake` / `Ai::Providers::Anthropic`) returns raw text; `Ai::ResponseValidator` is the only path from raw text to stored suggestions. Generation is synchronous with a DB-enforced single in-flight run per meeting; acceptance is idempotent via a row lock plus a unique index. Flutter app in `mobile/` uses `http` + `shared_preferences`, plain `StatefulWidget`s, and an injected `ApiClient`.

**Tech Stack:** Ruby 3.3.6, Rails 8.1.4, PostgreSQL 14 (Homebrew), Minitest, `anthropic` Ruby SDK, Flutter stable (3.x via Homebrew cask), Dart `http`, `shared_preferences`, iOS 18.4 simulator.

**Spec:** [`challenge/CHALLENGE.md`](../../../challenge/CHALLENGE.md) plus [`challenge/SUBMISSION.md`](../../../challenge/SUBMISSION.md) and [`challenge/fixtures/evaluation-cases.json`](../../../challenge/fixtures/evaluation-cases.json). Design calls not fixed by the spec are listed under "Decisions" below and are the builder's (Claude's) calls, not the user's.

## Global Constraints

- Stack: Rails, PostgreSQL, Flutter; Flutter runs on one simulator and talks to the Rails API (no fixture-only UI).
- Suggestion = description, optional owner (free text), optional due date (date-only, `YYYY-MM-DD`), exact supporting excerpt from notes.
- Never resolve relative dates; leave missing / conflicting / ambiguous owner or date empty.
- Edited items keep the original supporting excerpt as provenance.
- Two fictional orgs with users; cross-org reads and writes are impossible, including guessed IDs. Org is derived from the authenticated user on the server.
- Dev-only seeded auth shortcut; no registration or password reset.
- Validate AI structure and field types before storing; reject unsupported excerpts.
- Notes are untrusted input, never instructions.
- Provider errors are retryable by the user; accepting twice (including concurrently) creates one action, enforced in the DB.
- Provider credentials live only in server env, never in git (`.env` ignored, `.env.example` committed).
- One real adapter (Anthropic, model `claude-opus-5-5`) and one deterministic fake; record whether the real adapter ran.
- Out of scope: web UI, deployment, push, calendar, transcription, offline sync, production auth.

## Decisions (builder's calls)

- **IDs:** bigint primary keys; isolation comes from scoping every lookup through `current_organization`, proven by tests. Cross-org lookups return 404 (no existence leak).
- **Auth:** `POST /api/v1/dev/session {email}` issues a random token, stores its SHA-256 digest on `users.api_token_digest`; requests send `Authorization: Bearer <token>`. Dev routes exist only when `Rails.env.local?`.
- **Regeneration:** a successful run marks the meeting's older `pending` suggestions `superseded`; accepted/dismissed ones stay. A failed run changes nothing.
- **Single in-flight run:** partial unique index on `suggestion_generations(meeting_id) WHERE status = 'running'`; runs older than 2 minutes are marked failed (`stale`) before a new one starts. A concurrent request gets `409 generation_in_progress`.
- **Validation policy:** structural/type violations reject the whole response (`422 invalid_ai_response`, retryable). Grounding failures act per item: unsupported quote or blank description drops the item; owner not found in notes or date not explicitly present clears that field. Counts and reasons are stored on the generation.
- **First acceptance wins:** a repeated accept returns the existing action with `200` and ignores new edits.
- **Timeouts:** Anthropic SDK `timeout: 25s`, `max_retries: 1`; Flutter generation request timeout 75s, other requests 15s. If the client times out, the server keeps going and stores the result; the app shows a timeout message and refreshes the meeting to pick up results.
- **Fake provider modes** (for demo and evaluation): `heuristic` (default), `malformed`, `timeout`, `error`, `slow`; `*_once` variants auto-clear. Set by `bin/rails ai:fake_mode[mode]` (writes `tmp/fake_ai_mode`) or `FAKE_AI_MODE`.

## Review Focus

1. **Accepting a suggestion that was superseded by a newer generation** → `409 suggestion_not_pending`, app refreshes the meeting. Test in Task 4.
2. **Quote that differs from the notes only by whitespace/newlines** → accepted (whitespace-normalised match), whereas a paraphrased quote is dropped. Test in Task 3.
3. **Double-tapping "Generate" / client retry while a run is in flight** → second request `409 generation_in_progress`, no duplicate suggestions. Test in Task 3.
4. **Invalid edited due date at accept time (e.g. `2027-02-30`, `next Friday`)** → `422` with field error, no action created, suggestion stays pending. Test in Task 4.
5. **Expired/invalid token after app restart** → API `401`, app clears the stored session and returns to sign-in. Flutter test in Task 6 covers the 401 path through `ApiClient`.

---

### Task 1: Rails app, schema, seeds, dev auth

**Files:**
- Create: `backend/` via `rails new backend --api -d postgresql --skip-git --skip-docker --skip-kamal --skip-thruster --skip-solid --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-active-storage --skip-action-cable --skip-jbuilder --skip-ci`
- Create: migrations for `organizations`, `users`, `meetings`, `suggestion_generations`, `suggestions`, `action_items`
- Create: `app/models/{organization,user,meeting,suggestion_generation,suggestion,action_item,current}.rb`
- Create: `app/controllers/application_controller.rb` (auth + error envelope), `app/controllers/api/v1/dev/sessions_controller.rb`, `app/controllers/api/v1/me_controller.rb`
- Create: `db/seeds.rb`, `.env.example`, `.ruby-version` (3.3.6)
- Test: `test/integration/auth_test.rb`, `test/models/action_item_test.rb`

**Interfaces:**
- Produces: `ApplicationController#current_user -> User`, `#current_organization -> Organization`; `render_error(status:, code:, message:, retryable: false, details: nil)` → `{"error": {"code", "message", "retryable", "details"}}`.
- Produces: `User.authenticate_token(token) -> User | nil`, `User#issue_token! -> String`.
- Produces associations: `Organization has_many :meetings, :suggestions (through meetings), :action_items (through meetings)`.
- Schema essentials: `action_items.suggestion_id` NOT NULL + unique index; check constraints on status columns (`suggestions.status IN ('pending','accepted','dismissed','superseded')`, `suggestion_generations.status IN ('running','succeeded','failed')`).

- [ ] Write `auth_test.rb`: no header → 401 `unauthorized`; bad token → 401; `POST /api/v1/dev/session` with seeded email → 200 with `token`, then `GET /api/v1/me` → user + organization names; unknown email → 404.
- [ ] Write `action_item_test.rb`: inserting a second `ActionItem` for the same `suggestion_id` via `insert_all`/`save(validate: false)` raises `ActiveRecord::RecordNotUnique`.
- [ ] Run `bin/rails test` → FAIL (missing models/routes).
- [ ] Implement schema, models, auth, seeds (Acme Robotics: Maya Chen, Leo Park; Globex Studios: Nina Patel; one synthetic meeting per org).
- [ ] `bin/rails db:prepare db:seed && bin/rails test` → PASS.

### Task 2: AI provider boundary (prompt, fake, Anthropic)

**Files:**
- Create: `app/services/ai/errors.rb`, `app/services/ai/prompt.rb`, `app/services/ai/providers/fake.rb`, `app/services/ai/providers/anthropic.rb`, `app/services/ai/provider_factory.rb`, `lib/tasks/ai.rake`
- Test: `test/services/ai/providers/fake_test.rb`, `test/services/ai/providers/anthropic_test.rb`

**Interfaces:**
- Produces: `Ai::ProviderError < StandardError` (`#code`, `#retryable?`), `Ai::ProviderTimeout < Ai::ProviderError`, `Ai::InvalidResponse < StandardError` (`#reason`).
- Produces: provider contract `#extract(title: String, notes: String) -> String` (raw model text), `#name -> String`, `#model -> String | nil`.
- Produces: `Ai::ProviderFactory.build -> provider` reading `AI_PROVIDER` (`fake` default, `anthropic`).
- Produces: `Ai::Prompt::VERSION`, `Ai::Prompt::SYSTEM`, `Ai::Prompt::SCHEMA`, `Ai::Prompt.user_content(title:, notes:) -> String` (notes wrapped in `<meeting_notes>` delimiters, labelled untrusted).

- [ ] Fake tests: heuristic on fixture `explicit_commitment` notes returns JSON with 2 items (Maya/2027-02-12, Leo/2027-02-15); `Fake.new(raw_response: "{this is not valid JSON").extract` returns that string; `Fake.new(error: :timeout)` raises `Ai::ProviderTimeout`; `Fake.new(error: :error)` raises `Ai::ProviderError`; `_once` mode file is deleted after one use.
- [ ] Anthropic tests with an injected client double: request uses model `claude-opus-5-5`, `output_config.format.type == "json_schema"`, system prompt mentions untrusted notes; text block returned as string; SDK `APITimeoutError`/`APIConnectionError` → `Ai::ProviderTimeout`/`Ai::ProviderError`; `RateLimitError`/`InternalServerError` → retryable `Ai::ProviderError`; `AuthenticationError` → non-retryable `Ai::ProviderError` (`provider_misconfigured`); `stop_reason == :refusal` → `Ai::ProviderError` (`provider_refused`); missing `ANTHROPIC_API_KEY` → `provider_misconfigured` without a network call.
- [ ] Run → FAIL; implement; run → PASS.

### Task 3: Validation + generation service + generation endpoint

**Files:**
- Create: `app/services/ai/response_validator.rb`, `app/services/ai/explicit_dates.rb`, `app/services/suggestion_generator.rb`
- Create: `app/controllers/api/v1/meetings_controller.rb` (index, create, show), `app/controllers/api/v1/suggestion_generations_controller.rb` (create)
- Test: `test/services/ai/response_validator_test.rb`, `test/services/suggestion_generator_test.rb`, `test/integration/meetings_api_test.rb`, `test/integration/generation_api_test.rb`

**Interfaces:**
- Produces: `Ai::ResponseValidator.call(raw:, notes:) -> Ai::ResponseValidator::Result(items: [{description:, owner:, due_date: Date|nil, source_quote:}], rejections: [{index:, reason:}], warnings: [{index:, field:, reason:}])`; raises `Ai::InvalidResponse`.
- Produces: `SuggestionGenerator.new(provider:).call(meeting:, user:) -> SuggestionGeneration` (succeeded); raises `SuggestionGenerator::InProgress`, re-raises `Ai::ProviderError` / `Ai::InvalidResponse` after marking the generation failed.
- HTTP: `POST /api/v1/meetings/:meeting_id/suggestion_generations` → 201 `{generation, suggestions}`; 409 `generation_in_progress`; 422 `invalid_ai_response` (retryable); 502 `provider_error`; 504 `provider_timeout`.
- `GET /api/v1/meetings/:id` → `{meeting: {..., notes}, latest_generation, suggestions: [pending], action_items: [accepted for this meeting]}`.

- [ ] Validator tests: non-JSON → `InvalidResponse(:not_json)`; top level not an object / missing `action_items` / not an array → invalid; item with extra key or non-string description / numeric owner / numeric due_date → invalid; more than 25 items → invalid; quote not in notes → item rejected `unsupported_source_quote`; quote matching only after whitespace normalisation → kept; blank description → rejected; owner absent from notes → cleared with warning; `due_date: "next Friday"` or `"2027-02-30"` → cleared; ISO date not present in notes → cleared; "February 12, 2027" in notes supports `2027-02-12`; duplicate items collapse to one; `{"action_items": []}` → zero items.
- [ ] Generator tests: success stores suggestions + generation `succeeded` with counts; malformed → generation `failed`/`invalid_ai_response`, zero suggestions, and a following successful call works; timeout → `failed`/`provider_timeout`, then success works; a `running` generation blocks a second call (`InProgress`); a `running` generation older than 2 minutes is marked `stale` and a new run proceeds; successful rerun supersedes old pending suggestions but keeps accepted ones.
- [ ] Request tests: list/create meetings (422 on blank title/notes, notes > 20 000 chars); generation endpoint status codes above with fake provider injected via `Rails.application.config.x.ai_provider_override`.
- [ ] Run → FAIL; implement; run → PASS.

### Task 4: Accept, dismiss, action list, completion, isolation

**Files:**
- Create: `app/services/suggestion_acceptance.rb`, `app/controllers/api/v1/suggestions_controller.rb` (accept, dismiss), `app/controllers/api/v1/action_items_controller.rb` (index, update)
- Test: `test/integration/suggestion_acceptance_test.rb`, `test/integration/concurrent_acceptance_test.rb`, `test/integration/action_items_test.rb`, `test/integration/access_isolation_test.rb`

**Interfaces:**
- Produces: `SuggestionAcceptance.new(suggestion:, user:, attrs:).call -> [ActionItem, created: Boolean]`; raises `SuggestionAcceptance::NotPending`, `ActiveRecord::RecordInvalid`.
- HTTP: `POST /api/v1/suggestions/:id/accept {action_item: {description, owner, due_date}}` → 201 new / 200 existing / 409 `suggestion_not_pending` / 422 `validation_failed`; `POST /api/v1/suggestions/:id/dismiss` → 200 / 409; `GET /api/v1/action_items?status=open|completed|all`; `PATCH /api/v1/action_items/:id {action_item: {completed: bool}}`.
- Action JSON includes `source_quote`, `original: {description, owner, due_date}`, `edited: bool`, `completed`, `completed_at`, `meeting: {id, title}`.

- [ ] Acceptance tests: accept with edits → 201, action stores edited fields + original quote, `edited: true`; second accept with different edits → 200 same id, fields unchanged, `ActionItem.count` +1 total; superseded/dismissed → 409; invalid due date → 422 and suggestion still pending.
- [ ] Concurrency test (`self.use_transactional_tests = false`, explicit cleanup): 5 threads accept the same suggestion simultaneously → exactly 1 action row, every thread gets 200/201 with the same id.
- [ ] Persistence test: accept, mark complete, issue a fresh token (simulated app restart), list `status=completed` → item present with `completed: true`; mark incomplete → back in open.
- [ ] Isolation test: Globex user against every Acme meeting/suggestion/action endpoint (show, generate, accept, dismiss, update) → 404 and DB unchanged; Acme lists contain no Globex records.
- [ ] Run → FAIL; implement; run → PASS.

### Task 5: Evaluation runner

**Files:**
- Create: `lib/evaluation/runner.rb`, `lib/tasks/eval.rake`
- Output: `backend/tmp/evaluation/<mode>-<timestamp>.md` (copied into `EVALUATION.md`)

**Interfaces:**
- Consumes: `Ai::ProviderFactory`, `Ai::ResponseValidator`, `SuggestionGenerator`.
- Produces: `bin/rails "eval:run[fake]"` / `bin/rails "eval:run[anthropic]"` printing a Markdown table: case, mode, expected, observed, pass/fail/blocked. Cases 1–5 run provider + validator against `challenge/fixtures/evaluation-cases.json`; case 6 variants run the full generator inside a rolled-back transaction with injected fake failures. Anthropic mode without a key reports every case as `blocked`.

- [ ] Run fake mode and record output; run anthropic mode (blocked unless a key exists).

### Task 6: Flutter app

**Files:**
- Create: `mobile/` via `flutter create --org com.example.meetingaction --project-name meeting_action --platforms ios,android mobile`
- Create: `lib/config.dart`, `lib/api/api_client.dart`, `lib/api/api_exception.dart`, `lib/models/*.dart`, `lib/session/session_store.dart`, `lib/app.dart`, `lib/screens/{sign_in,home_shell,meetings,create_meeting,meeting_detail,actions}_screen.dart`, `lib/widgets/{state_views,suggestion_card}.dart`
- Test: `test/api_client_test.dart`, `test/meeting_detail_screen_test.dart`

**Interfaces:**
- Consumes: HTTP contract from Tasks 1–4.
- Produces: `ApiClient({required Uri baseUrl, http.Client? httpClient, String? token})` with `devUsers()`, `signIn(email)`, `me()`, `meetings()`, `createMeeting(title, notes)`, `meeting(id)`, `generateSuggestions(meetingId)`, `acceptSuggestion(id, {description, owner, dueDate})`, `dismissSuggestion(id)`, `actionItems(status)`, `setCompleted(id, bool)`; throws `ApiException(code, message, retryable, statusCode)`; `ApiException.code == 'timeout'` on client timeout.
- `API_BASE_URL` from `--dart-define`, default `http://localhost:3000` (iOS simulator) / `http://10.0.2.2:3000` (Android emulator).

- [ ] `api_client_test.dart`: error envelope parsed into `ApiException`; 401 → `code == 'unauthorized'`; `TimeoutException` → `code == 'timeout'`, retryable.
- [ ] `meeting_detail_screen_test.dart` (http `MockClient`): first generate returns 422 `invalid_ai_response` → error text and "Try again" shown, no suggestion cards; tap "Try again" → 201 → suggestion card with description, owner, due date and quote; edit description and tap Accept → request body carries edited description.
- [ ] Run `flutter test` → FAIL; implement screens; run → PASS; `flutter analyze` clean.

### Task 7: End-to-end run + docs

**Files:**
- Create: `README.md`, `ARCHITECTURE.md`, `AI_WORKLOG.md`, `EVALUATION.md`, `.gitignore`

- [ ] Boot Rails on `0.0.0.0:3000`, boot iPhone 16 simulator, `flutter run`, walk: sign in → create meeting → generate → edit + accept → mark complete → restart app → completed item still there. Capture screenshots under `docs/screenshots/`.
- [ ] Fill docs from actual command output; mark real-provider status honestly.
