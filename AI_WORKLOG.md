# AI work log

**At a glance** (all re-run on 2026-10-30 unless noted):

| Check | Result |
| --- | --- |
| Backend tests | `bin/rails test`: 94 runs, 341 assertions, 0 failures |
| Flutter tests | `flutter test`: 13 passed, 1 live test skipped by default; `flutter analyze` clean |
| Live journey (real Flutter UI → Rails → PostgreSQL over HTTP) | Passed: sign-in, create, generate, edit + accept, complete, restart |
| Evaluation | Fake provider 7/7. Real provider (`claude-opus-5-5`) 5/5 extraction cases; the 2 failure cases pass too, injected through the fake provider by design |
| iOS simulator | Builds, installs and launches on iPhone 18 Pro (iOS 27.0) and iPhone Duo (iOS 27.1) |

Details and commands: [EVALUATION.md](EVALUATION.md). Code: commits `eee3578` (API), `f0d5f8b` (app), `44a7092` (docs).

## Tools and time

- **Tools and models:** Claude Code in VS Code.
  - Core build: started on Claude Fable 5.1 (brief, plan, toolchain, Rails API). The developer then switched to Claude Opus 5.5 with `/model opus` (evaluation runner, Flutter app, docs).
  - Review: a separate Claude Opus reviewer agent, given the code but not the build conversation, reviewed the whole project.
  - Process: a written plan, test-first execution with a task-by-task [progress ledger](.superpowers/sdd/2026-10-29-meeting-action/progress.md), and systematic debugging. On day 2, scope questions were put to the developer as multiple-choice decisions before any code changed.
- **Active work time:**
  - Core build: about 80 minutes of agent time on 2026-10-29, 19:30–20:50 PKT. That excludes about 10 minutes stopped on a full disk.
  - Post-core work on 2026-10-30: about 3 h 50 min of agent time, including the second-machine setup, itemised [below](#post-core-work-disclosed-separately).
  - **Developer's own review and testing time:** about 1 hour (the developer's estimate). That covers checking the plan and results, testing the app in the simulator, and the steps only the developer could do: Homebrew, Xcode setup, the API key and the GitHub login.
- **Setup time:** about 15 minutes on the first machine (Flutter SDK, Rails 8.1.4 on Ruby 3.3.6) plus about 10 minutes freeing disk space. About 40 minutes on the second machine, counted in the post-core time.
- **Provider usage and cost:** no real-provider calls during the core build (no key). On 2026-10-30: 6 Opus calls (one evaluation run with 5 real cases, one rolled-back check on loosely written notes). Cost not measured. Claude Code session usage: unavailable.
- **Scaffolds and reused code:**
  - Generators: `rails new --api -d postgresql`, `flutter create --empty`.
  - Runtime dependencies: `anthropic` 2.3.0 and `dotenv-rails` (MIT); `http` and `shared_preferences` (BSD-3).
  - Build-time only, not shipped in the app: `flutter_launcher_icons` 0.14.4 and `flutter_native_splash` 2.4.8 (MIT).
  - No third-party code was copied. Exercise materials are under `challenge/` (CC0).
- **How context and change boundaries were supplied:**
  - Core build: one developer prompt pointing at the exercise folder. The agent read the brief, rubric, submission guide, templates and fixtures. It then wrote [a 7-task plan](docs/superpowers/plans/2026-10-29-meeting-action.md), each task naming its files, interfaces and proving tests, and executed it task by task: failing test, code, full suite.
  - Day 2: the developer steered with bounded requests, usually a simulator screenshot of one defect (filter labels off-centre, a snack bar that never closed, odd meeting names). Before the UI redesign, the agent copied the app's source as a rollback point.
- **One task handled personally, and why:** credentials. The agent asked the developer not to paste the Anthropic key into the chat. The developer wrote it into the git-ignored `backend/.env`; the agent only checked its length and prefix, and confirmed that no committable file contains it. The developer also ran everything that needed their password or account: Homebrew's installer, Xcode's first-launch setup, and the GitHub login. They also decided what to delete when the first machine's disk filled.

## 1. Understanding or planning

- **Prompt excerpt (developer):**
  > "Read the /Users/mac/Documents/Projects/ai-fullstack-builder-challenge and see what we have to impplement in this project. mmake sure to follow the instruction and build aa fully functional and profesional project … download all required dependency or tools"

  *In short (paraphrase, not a quote):* build the whole exercise as the brief specifies, and install whatever tooling it needs.
- **Context gathered:** the exercise documents and fixtures. The toolchain: Ruby 3.0.5 default with 3.3.6 available, PostgreSQL 14 running, Flutter missing, an iOS 18.4 simulator. No `ANTHROPIC_API_KEY`. About 15 GB of free disk.
- **Response excerpt (plan, "Decisions"):**
  > "Single in-flight run: partial unique index on `suggestion_generations(meeting_id) WHERE status = 'running'` … A concurrent request gets `409 generation_in_progress`."
  > "Validation policy: structural/type violations reject the whole response … Grounding failures act per item."
- **Decision made and why:** enforce both duplicate rules in PostgreSQL, not only in application code: one action per suggestion, and one running generation per meeting. The brief asks for the invariant "at the persistence boundary", including concurrent attempts, which application-level checks alone can't guarantee. Generation stays synchronous, and each attempt is recorded as a row, so a client that times out can recover by refreshing.
- **Related files:** [the plan](docs/superpowers/plans/2026-10-29-meeting-action.md), [create_suggestion_generations](backend/db/migrate/20261029150003_create_suggestion_generations.rb), [create_action_items](backend/db/migrate/20261029150005_create_action_items.rb). Commits `eee3578` (migrations) and `44a7092` (plan).
- **Evidence used to check the decision:** `ActionItemTest` "the database refuses a second action for the same suggestion" raises `ActiveRecord::RecordNotUnique`. `GenerationApiTest` "a second request while one is running gets a conflict" returns 409.

## 2. Implementation or debugging

- **Context:** after writing `ConcurrentAcceptanceTest` (four threads accepting one suggestion), the agent checked that the test *could* fail, by temporarily removing the row lock and then the duplicate-key rescue from `SuggestionAcceptance`.
- **What happened:** with both protections removed, the test still passed three times. The agent treated that as a broken test, not a pass:
  - A probe showed four separate PostgreSQL connections with overlapping `pg_sleep` calls, so the threads were real.
  - Timestamps showed thread 0 finishing at about 150 ms and the others only after its commit. Lazy autoloading in the test environment was serialising the threads.
  - With `Rails.application.eager_load!` the race appeared (three `RecordNotUnique` in one run), but not every time.
- **Change:** the test eager-loads and uses a test-only `InsertGate` that holds every thread just before its insert (0.5 s timeout). With the lock, only one thread reaches the gate. Without it, all four race. Production code unchanged. [concurrent_acceptance_test.rb](backend/test/integration/concurrent_acceptance_test.rb), commit `eee3578`.
- **Verification and actual results:** `bin/rails test test/integration/concurrent_acceptance_test.rb`, three runs per variant:

  | Variant | Result |
  | --- | --- |
  | Real code | 3/3 pass |
  | Lock removed | 3/3 pass: the unique index and rescue are enough |
  | Lock and rescue removed | 3/3 fail with `PG::UniqueViolation … index_action_items_on_suggestion_id` |

- **What the check does not establish:** behaviour across several Puma workers or servers (the unique index holds across processes, but that wasn't exercised), higher thread counts, or concurrency through the HTTP layer rather than the service object.

## 3. Critical review

- **AI work challenged:** the building agent's own validator and review screen. A separate reviewer agent, without the build conversation, was told to break the riskiest areas and give a concrete failure scenario for each finding. Each claimed issue was re-checked by writing a failing test before any fix.
- **Reviewer excerpts:**
  > "`{"description":"Fire everyone","source_quote":"a"}` is stored as a pending suggestion … conflicts with the spec's 'Reject unsupported source excerpts'."
  > "`conflicting_details` fixture: owner 'Priya' and due 2027-02-18 attached to the quote 'Decision: prepare the budget summary.' both survive validation."
  > "A failed generation looks like success in the app … The screen says 'All suggestions reviewed', shows no error."
- **Why they mattered:** without an API key, the validator was the only measured guard for the conflict and missing-owner cases. The agent's own plan had said "owner not found in notes is cleared", which checks the whole notes and is weaker than the brief's "leave conflicting or ambiguous values empty". The UI bug sat on the client-timeout path the live review asks about.
- **Accepted, with evidence (each RED → GREEN):**
  - Quotes must be whole-word excerpts of at least 3 words, and owner and date must appear in the item's own quote (prompt bumped to `2026-10-29.2`). Tests: "a quote that is not a whole-word excerpt is dropped", "a quote shorter than three words is dropped", "an owner or date stated elsewhere in the notes but not in the item's quote is cleared".
  - A failed last generation shows its error and **Try again**; an unreadable payload becomes a `bad_response` error instead of an endless spinner. Flutter tests for both.
- **Not changed, and why:** eight minor findings were recorded but not fixed, for example a stale `running` row reading as "still generating" until regenerated, and one dev token per user. They are listed as known gaps.
- **Later independent check:** once the developer supplied a key, the real provider passed the same `conflicting_details` and prompt-injection cases (EVALUATION.md). The validator was not relaxed for it.

### Defects in AI-generated work found after it looked done

Each was found by the developer reviewing the running app, or by an end-to-end check, not by the code author's unit tests.

| Found by | Defect | Fix and evidence |
| --- | --- | --- |
| Live journey test | New UI: the floating New meeting button sat under the tab bar, so taps landed on Actions | Button lifted by the tab bar's reserved inset; live journey passes |
| Live journey test | The narrow-screen layout overflowed after content centring used the window width instead of the available width | Centring uses layout constraints; four rows made to wrap or truncate |
| Developer, simulator | Filter labels sat above centre in the Open/Completed/All control | Row fills the control's height; `glass_tab_bar_test.dart` failed (10 px off) then passed |
| Developer, simulator | The Undo snack bar never closed. Flutter keeps snack bars with an action open by default | 5 s timeout, still persistent with a screen reader; test failed then passed |
| Developer, simulator | Meeting list full of "Live journey 1793…" rows created by the agent's own live test runs | Realistic seed data, readable live-test names, `db:seed:replant` documented |
| Agent, own diagnosis | A wrong guess that the white launch screen came from image size; the real cause was the simulator's launch-screen cache | Restart confirmed it; the misleading code comment was corrected |

The developer's reports, word for word, each sent with a simulator screenshot:

> "fix top navbar, open, completed and All should be in centered vertically"

> "That marked open notification is not going away, until I click at undo, it that expected behaviour or what?"

> "Update meetings names and content properly, currently meeting names are really odd, these should be meangfull, also add a bit more seed data"

## Post-core work (disclosed separately)

On 2026-10-30, after the core build. Times are approximate, from file and log timestamps.

| Work | Why | Evidence | Time |
| --- | --- | --- | --- |
| Moved to a second machine (Apple Silicon, Xcode 27.1); toolchain and first simulator run | The first Mac's disk and memory were exhausted | All checks re-run; app launches on two simulators | ~40 min |
| Liquid Glass UI redesign (developer request) | The agent first pointed out that the brief doesn't score polish; the developer chose to proceed for the live review | 2 new failing-first tests; live journey passes; existing tests unchanged | ~2 h |
| Fixes from the developer's simulator review | See the table above | 13 Flutter tests passing | ~15 min |
| Seed data and live-test naming | Demo data was polluted by the agent's own test runs | Fake-provider dry run on every fresh meeting; backend 94/0 | ~15 min |
| App icon and native launch screen | Default Flutter icon; white flash at launch | Checked on the iPhone 18 Pro simulator | ~20 min |
| First real-provider run | Key supplied by the developer | Real provider 5/5; rolled-back check on loosely written notes | ~10 min |
| Private GitHub repository and commits | Submission requires a repository URL | 4 commits; `.env` and `master.key` confirmed untracked | ~10 min |
