# SDD ledger — plan: docs/superpowers/plans/2026-10-29-meeting-action.md
Spec: challenge/CHALLENGE.md (+ SUBMISSION.md, fixtures/evaluation-cases.json)
Ruling: no git commits per task — system rule says commit only when the user asks; repo is initialised on branch main with no commits — cost if wrong: user commits once at the end, task commit ranges unavailable
Ruling: execution method Native chosen by builder — session is autonomous, user cannot answer mid-run — cost if wrong: no per-task reviewer, mitigated by final review
Pre-flight: T1 produces auth/current_organization/error envelope → T3,T4 consume (consistent). T2 provider contract extract(title:,notes:)->String → T3 SuggestionGenerator, T5 runner (consistent). T3 generator/validator → T5 (consistent). T1-T4 HTTP contract → T6 ApiClient (consistent: accept body key action_item, completed via PATCH action_item.completed).
Task 1: complete (no commits per ruling; tests: bin/rails test → 8 runs, 21 assertions, 0 failures)
Task 2: complete (tests: bin/rails test → 26 runs, 0 failures). Ruling: fake mode file made configurable per test worker — parallel test processes shared tmp/fake_ai_mode — cost if wrong: none (dev default unchanged)
Task 3: complete (tests: bin/rails test → 63 runs, 207 assertions, 0 failures). Ruling: invalid_ai_response returns 502 not 422 — the upstream provider produced the bad payload, the client request was valid — cost if wrong: one status code + one client mapping. Ruling: added stale-mid-flight guard + test (persist! re-checks generation is still running) — closes a race the plan did not cover — cost if wrong: none
Task 4: complete (tests: bin/rails test → 83 runs, 0 failures, twice). Debug: concurrency test initially passed under a no-lock/no-rescue mutation — root cause: lazy autoloading serialized threads in test env; fix: eager_load! + test-only InsertGate barrier before INSERT; verified real=3/3 pass, no-lock=3/3 pass (index+rescue), no-lock+no-rescue=3/3 fail with PG::UniqueViolation. Ruling: missing action_item body on accept means accept-as-proposed — explicit accept is the POST itself — cost if wrong: client must always send fields
Task 5: complete (tests: bin/rails test → 87 runs, 0 failures; eval:run[fake] 7/7 pass; eval:run[anthropic] 5 blocked, no key). Ruling: Organization association order swapped (meetings before users) so org.destroy satisfies FKs — found while writing eval cleanup — cost if wrong: none
Task 6: complete (flutter test → 6 passed; flutter analyze → no issues). Ruling: models split into lib/models/{app_user,generation,suggestion,action_item,meeting}.dart; widgets source_quote/account_menu added — focused files — cost if wrong: none
Task 7: complete (docs written; live UI→API journey passed; iOS simulator build blocked by Xcode first-launch requiring sudo — disclosed)
Final review: fresh Opus reviewer subagent, whole project
Final: Ruling: Critical "no simulator run/demo" — environment (sudo xcodebuild -runFirstLaunch needs the user's password), disclosed in README/EVALUATION/ARCHITECTURE — cost if wrong: live review step 1 cannot run until the user fixes Xcode
Final: fixed failed generation shown as "All suggestions reviewed" — meeting_detail_screen_test "a meeting whose last generation failed…" RED→GREEN, flutter 8/8
Final: fixed loose grounding (quote "a" accepted; owner/date anywhere in notes) — 3 validator tests RED→GREEN, suite 90/90; prompt VERSION 2026-10-29.2
Final: Ruling: regraded minor #10 (unreadable payload → endless spinner) to Important — older-client-after-API-change case — api_client_test "a payload the app cannot read…" RED→GREEN
Final: Ruling: regraded minor #9 (README -b 0.0.0.0 exposes dev sign-in to LAN) to Important — doc-only warning added, no test applicable — cost if wrong: none
Final: Ruling: runner test "invented owner" replaced by "discussion turned into an action" — validator now clears the invented owner before grading — cost if wrong: grader owner-mismatch path less directly tested
Final: minor (deferred): accepted action can vanish from meeting screen if accepted mid-regeneration (server data fine)
Final: minor (deferred): failed reload after 409 is silent once a meeting is loaded
Final: minor (deferred): stored source_quote is model text, not the exact notes span, when matched after whitespace normalisation
Final: minor (deferred): real adapter latency budget unmeasured (25s x 2 attempts)
Final: minor (deferred): abandoned running row shows "still being generated" until someone regenerates
Final: minor (deferred): one dev token per user (signing in elsewhere signs the app out) — documented in README
Final: minor (deferred): date picker asserts for due dates outside now-5y..now+10y
Final: minor (deferred): unknown AI_PROVIDER / unexpected generator error returns plain 500 without the error envelope
Follow-up (user request): fixed deferred minor 'failed reload after 409 is silent' — meeting_detail_screen_test 'a failed reload after a stale accept…' RED→GREEN, flutter 9/9
Follow-up (user request): fixed deferred minor 'plain 500 without envelope' — 3 tests RED→GREEN (unknown AI_PROVIDER → 502 provider_misconfigured; unexpected generation error → 500 internal_error retryable; global rescue_from StandardError → JSON envelope), suite 93/93. Ruling: factory now raises Ai::ProviderError(provider_misconfigured) instead of ArgumentError — consistent client code with the missing-key case — cost if wrong: eval rake shows a ProviderError for a typo'd provider name. Ruling: also map invalid JSON request bodies to 400 bad_request — needed once StandardError is caught globally, else they would become 500 — cost if wrong: none
Follow-up: added test 'a request body that is not valid JSON is a 400…' — fails (500) with the ParseError handler removed, passes with it; suite 94/94
