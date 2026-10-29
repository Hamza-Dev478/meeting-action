# AI work log

## Tools and time

- **Tools and models:**
  - Claude Code in the VS Code extension, starting with Claude Fable 5.1. It handled reading the brief, the plan, the toolchain installs and the whole Rails API.
  - Partway through, the developer switched the session to Claude Opus 5.5 with `/model opus`. That model wrote the evaluation runner, the Flutter app and these docs.
  - A separate Claude Opus reviewer agent, which saw the code but not the build conversation, did the final whole-project review.
  - Process skills: planning, test-first execution with a progress ledger, and systematic debugging.
- **Active work time:** about 80 minutes of agent wall-clock time on 2026-10-29, from 19:30 to 20:50 PKT. That excludes a stop of about 10 minutes when the disk filled up. *The developer's own review time: to be added by the developer.*
- **Post-core work, 2026-10-30 (outside the core time above, disclosed separately):**
  - About 40 minutes setting up a second machine (Apple Silicon, Xcode 27.1) after the project was moved: Homebrew, rbenv/Ruby 3.3.6, PostgreSQL 14, Flutter 3.47.8, then re-running every check.
  - About 2 hours (00:33–02:30 PKT) of agent time on a Liquid Glass redesign of the Flutter UI; see [section 4](#4-post-core-ui-redesign-liquid-glass).
- **Setup time:** about 15 minutes, mostly overlapping with planning. That covered the Flutter SDK (Homebrew cask, iOS artifacts), Rails 8.1.4 for Ruby 3.3.6, and about 10 minutes freeing disk space.
- **Provider usage and cost:** during the core build the app's Anthropic adapter made no calls, because there was no key. On 2026-10-30 the developer added a key to `backend/.env` (never shown in the session); the agent then made 6 Opus calls: one evaluation run (5 cases) and one rolled-back check on loosely written notes. Exact cost: not measured. Claude Code session usage and cost: unavailable.
- **Scaffolds and reused code:** `rails new --api -d postgresql` and `flutter create --empty` generator output. Gems: `anthropic` 2.3.0 and `dotenv-rails` (both MIT). Dart packages: `http` and `shared_preferences` (both BSD-3). No other third-party code was copied. Exercise materials are under `challenge/` (CC0).
- **How context and change boundaries were supplied:**
  - The developer's single prompt pointed at the exercise folder. The agent read `CHALLENGE.md`, `RUBRIC.md`, `SUBMISSION.md`, the templates and the fixtures, and checked the local toolchain.
  - It then wrote [a plan](docs/superpowers/plans/2026-10-29-meeting-action.md) with seven tasks, each listing its files, interfaces and the tests that prove it.
  - Execution went task by task: failing test first, then code, then the whole suite, with deviations recorded as rulings in a ledger.
- **One task handled personally, and why:** the developer decided what to delete when the disk filled. The agent's bulk cache deletion was blocked by a safety check, and only the owner should choose what to remove from their machine. The one-time `sudo xcodebuild -runFirstLaunch` also has to be run by the developer, because it needs an admin password.

## 1. Understanding or planning

- **Prompt excerpt (developer):**
  > "Read the /Users/mac/Documents/Projects/ai-fullstack-builder-challenge and see what we have to impplement in this project. mmake sure to follow the instruction and build aa fully functional and profesional project … download all required dependency or tools"
- **Context gathered by the agent:**
  - The exercise documents and fixtures.
  - The toolchain: Ruby 3.0.5 default with 3.3.6 available, PostgreSQL 14 running, Flutter missing, an iOS 18.4 simulator present, and no `ANTHROPIC_API_KEY`.
  - About 15 GB of free disk.
- **Response excerpt (plan, "Decisions"):**
  > "Single in-flight run: partial unique index on `suggestion_generations(meeting_id) WHERE status = 'running'` … A concurrent request gets `409 generation_in_progress`."
  > "Validation policy: structural/type violations reject the whole response … Grounding failures act per item."
- **Decision made and why:** enforce both duplicate rules in PostgreSQL rather than in application code. Those rules are one action per suggestion and one running generation per meeting. The brief asks for the invariant "at the persistence boundary" and mentions concurrent attempts, which application-level checks alone can't guarantee. Synchronous generation was kept, and the generation row records every attempt, so a client timeout can be recovered by refreshing.
- **Related files:**
  - [docs/superpowers/plans/2026-10-29-meeting-action.md](docs/superpowers/plans/2026-10-29-meeting-action.md)
  - [backend/db/migrate/20261029150003_create_suggestion_generations.rb](backend/db/migrate/20261029150003_create_suggestion_generations.rb)
  - [backend/db/migrate/20261029150005_create_action_items.rb](backend/db/migrate/20261029150005_create_action_items.rb)
- **Evidence used to check the decision:**
  - `ActionItemTest` "the database refuses a second action for the same suggestion" raises `ActiveRecord::RecordNotUnique`.
  - `GenerationApiTest` "a second request while one is running gets a conflict" returns 409.

## 2. Implementation or debugging

- **Context:** after writing `ConcurrentAcceptanceTest` (four threads accepting one suggestion), the agent checked that the test could fail. It temporarily removed the row lock and then the duplicate-key rescue from `SuggestionAcceptance`.
- **What happened:** with both protections removed, the test still passed three times. The agent treated that as a bug in the test, not as a pass, and investigated:
  - A probe showed four distinct PostgreSQL backend PIDs with overlapping `pg_sleep` calls, so the threads did have separate connections.
  - Timestamps inside the real test showed thread 0 finishing at about 150 ms, with the other three finishing only after its commit, then finding its row. The cause was lazy autoloading in the test environment, which serialized the threads.
  - Calling `Rails.application.eager_load!` made the race appear: three `RecordNotUnique` errors in one run. It wasn't deterministic, though.
- **Change:** the test now eager-loads. A test-only gate, `InsertGate`, makes every thread wait just before building the action, with a 0.5 s timeout. With the lock present, only one thread can reach the gate, so it times out and the test passes. Without the lock, all four threads reach it and race to insert. Production code was not changed. File: [backend/test/integration/concurrent_acceptance_test.rb](backend/test/integration/concurrent_acceptance_test.rb).
- **Verification commands and actual results:** `bin/rails test test/integration/concurrent_acceptance_test.rb`, run three times per variant:

  | Variant | Result |
  | --- | --- |
  | Real code | 3/3 pass |
  | Lock removed | 3/3 pass, because the unique index and rescue are enough |
  | Lock and rescue removed | 3/3 fail with `PG::UniqueViolation … index_action_items_on_suggestion_id` |

  The full suite was green afterwards: 87 runs, 0 failures.
- **What the check does not establish:** behaviour across multiple Puma workers or app servers. That still relies on the same database unique index, which holds across processes, but it wasn't exercised. It also doesn't establish behaviour at higher thread counts, or concurrency through the HTTP layer rather than the service object.

## 3. Critical review

- **AI work challenged:** the building agent's own validator and review screen. A separate Claude Opus reviewer agent read the code without the build conversation. It was told to try to break the riskiest areas and to give a concrete failure scenario for each finding. Every claimed issue was then re-checked by writing a failing test before any fix.
- **Relevant excerpts from the reviewer:**
  > "`{"description":"Fire everyone","source_quote":"a"}` is stored as a pending suggestion … conflicts with the spec's 'Reject unsupported source excerpts'."
  > "`conflicting_details` fixture: owner 'Priya' and due 2027-02-18 attached to the quote 'Decision: prepare the budget summary.' both survive validation."
  > "A failed generation looks like success in the app … The screen says 'All suggestions reviewed', shows no error."
- **Why these mattered:**
  - With no API key, the validator is the only measured guard for the conflict and missing-owner cases.
  - The original plan (written by the same agent) said "owner not found in notes is cleared". That checks presence anywhere in the notes, which is weaker than the spec's "leave conflicting or ambiguous values empty".
  - The UI bug sits on exactly the client-timeout path the live review asks about.
- **What was accepted:**
  - Grounding: quotes must be whole-word excerpts of at least 3 words, and owner and due date must appear in the item's own quote. The prompt was bumped to version `2026-10-29.2` to ask for that.
  - App: a failed last generation now shows its error and **Try again**.
  - Client: an unreadable payload becomes a `bad_response` error rather than an endless spinner. The reviewer rated this minor; it was raised to important because it is the older-app-after-API-change case.
  - README: a warning that binding Rails to `0.0.0.0` exposes the dev sign-in to the network.
- **What was not changed, and why:**
  - The "missing simulator run" is a real gap, but it's an environment problem: Xcode needs `sudo xcodebuild -runFirstLaunch`, which only the developer can run. It's disclosed rather than worked around.
  - Eight other minor findings were recorded but not fixed in this pass. Examples: a stale `running` row reads as "still generating" until regenerated; the stored quote is the model's whitespace-normalised text; one dev token per user; the date picker range.
- **Resulting changes and evidence:**
  - Validator: new failing tests "a quote that is not a whole-word excerpt is dropped", "a quote shorter than three words is dropped" and "an owner or date stated elsewhere in the notes but not in the item's quote is cleared" went from RED to GREEN.
  - Flutter: "a meeting whose last generation failed shows the failure and a retry" and "a payload the app cannot read becomes a bad_response error" went from RED to GREEN.
  - Final state: `bin/rails test` gives 90 runs, 0 failures. `flutter test` gives 8 passed. `eval:run[fake]` still gives 7 of 7. The live journey passed again.
  - One evaluation-runner test had to change. Its "invented owner" example is now cleared by the validator before grading, so it was replaced with a case the grader must still catch: turning a discussion into an action.

## 4. Post-core UI redesign (Liquid Glass)

- **Prompt excerpt (developer):**
  > "UI is literally totally basic, let's take user experience and UI of the Application to next level … give it a theme of liquid glass recently used by Apple"
- **Context and decisions:**
  - The agent pointed out first that the brief does not score visual polish and asks to keep the UI small. The developer chose to go ahead to make the live review stronger, with the work disclosed here and no change to behaviour or tests.
  - Scope chosen by the developer: the glass visual system on every screen, navigation and motion, the generation experience, and the actions list. The review flow kept its layout.
  - Approach chosen by the developer: hand-built glass in pure Flutter, with no new dependencies. A shader package (true refraction) and native iOS glass views were rejected as riskier and untestable in widget tests.
  - The developer asked the agent to implement without further design approvals, so the remaining design sections were decided by the agent.
- **What changed (mobile only; the API is untouched):**
  - `lib/theme/`: a `GlassTheme` palette, an app theme, and an `AmbientBackdrop` of slowly drifting colour fields driven by one clock at the app root. Screens pumped on their own in tests get a still backdrop, so `pumpAndSettle` stays finite. Reduce Motion stops the drift; Increase Contrast makes surfaces solid.
  - `lib/widgets/glass.dart`: `GlassSurface` (backdrop blur, tint, rim light, sheen), `GlassCard`, `GlassButton`, `GlassBadge`. List cards share one blur pass through `BackdropGroup`.
  - `GlassPage`: a large title that collapses into a glass navigation bar, and a hero transition of the meeting title from the list into the meeting screen.
  - A floating glass tab bar and segmented control with a sliding lens; staggered entrances; haptics on tab change, accept and complete.
  - Generation: an animated status card whose steps name the real server pipeline, plus shimmering placeholder cards.
  - Actions: a progress ring ("3 of 5 done"), groups by urgency (Overdue, Due this week, Later, No due date, Done), and a completed row that lingers 650 ms before it slides out. The screen now loads `status=all` once and filters locally, so switching filters makes no request.
- **Evidence:**
  - New failing-first tests: `test/actions_screen_test.dart` (one request, progress text, groups, filtering without refetching, completion) and `test/dates_test.dart` (due-date grouping). Both failed before the change for the expected reasons, then passed.
  - `flutter test`: 11 passed, 1 skipped. `flutter analyze`: clean. Existing tests unchanged.
  - The live journey caught two real layout bugs the widget tests missed: the New meeting button sat under the floating tab bar (taps hit the Actions tab), and the segmented control overflowed at 430 px. Both fixed; the live journey then passed with no layout errors.
  - The app builds and runs on the iOS 27.1 simulator; the sign-in screen was checked visually, including centring on the unfolded large display.
- **Not verified:** the signed-in screens on the simulator (they need taps), dark mode, Android, and frame times with many blurred surfaces.
- **App icon and launch screen (follow-up, about 20 minutes):** the icon was still Flutter's default and every launch flashed white. `mobile/tool/generate_brand_assets.dart` renders the orb, and the launch background from the app's own `AmbientBackdrop`, to `mobile/assets/branding/`. The dev-only generators `flutter_launcher_icons` 0.14.4 and `flutter_native_splash` 2.4.8 (both MIT, not shipped in the app) then build the icon sizes and the native launch screen (light and dark). There is no added delay; the first Flutter frame replaces it. Checked on the iPhone 18 Pro simulator: icon on the home screen, launch screen at startup. The simulator kept showing a cached white launch screen until it was restarted, which is an iOS caching quirk, not an app issue.
