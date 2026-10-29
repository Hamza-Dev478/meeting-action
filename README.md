# Meeting → Action

A team member pastes meeting notes into a Flutter app. A Rails API asks an AI provider for action items grounded in those notes. The person reviews and edits each suggestion, accepts the ones they want, and tracks them to completion. Every org's data stays in that org.

| Part | Path | Stack |
| --- | --- | --- |
| API | [`backend/`](backend/) | Ruby 3.3.6, Rails 8.1.4 (API only), PostgreSQL 14, Minitest |
| Mobile app | [`mobile/`](mobile/) | Flutter 3.47.8 / Dart 3.13.7, `http`, `shared_preferences` |
| Exercise brief | [`challenge/`](challenge/) | The original exercise materials (CC0) |
| Evidence | [`ARCHITECTURE.md`](ARCHITECTURE.md), [`EVALUATION.md`](EVALUATION.md), [`AI_WORKLOG.md`](AI_WORKLOG.md) | |

## Status

| Check | Result |
| --- | --- |
| Backend tests (`bin/rails test`) | 94 runs, 0 failures |
| Flutter tests (`flutter test`) | 11 passed, 1 live test skipped by default |
| Live Flutter UI → Rails → PostgreSQL journey (headless, real HTTP) | Passed |
| Evaluation fixtures, fake provider | 7/7 pass (pipeline only, not extraction quality) |
| Evaluation fixtures, real provider (Anthropic) | 5/5 real cases pass with `claude-opus-5-5`, about 3–4 s per call (2026-10-30) |
| App running on the iOS simulator | Builds, installs and launches on the iOS 27.1 simulator (Xcode 27.1); the sign-in screen loads the seeded users from the live API. A full tap-through of the demo journey on the simulator is not yet recorded |
| RuboCop, Brakeman, `flutter analyze` | Clean |

## Requirements

Versions used to build and test this project:

- macOS with Xcode and an iOS simulator runtime. Built first with Xcode 26.3 / iOS 18.4; re-verified on an Apple Silicon Mac with Xcode 27.1 on the iPhone 18 Pro (iOS 27.0) and iPhone Duo (iOS 27.1) simulators. In Xcode 27 the simulator window is opened from Xcode → Open Developer Tool → Device Hub.
- Ruby 3.3.6 (via rbenv; `backend/.ruby-version`), Bundler 2.x.
- PostgreSQL 14+ running locally (Homebrew `postgresql@14`, local socket, current OS user as superuser).
- Flutter 3.47.8 stable (`brew install --cask flutter`, or `git clone --depth 1 --branch 3.47.8 https://github.com/flutter/flutter.git` to pin the exact version).
- Android emulator alternative: Android Studio with an emulator image.

## 1. Run the API

```bash
cd backend
rbenv install -s 3.3.6            # if Ruby 3.3.6 is missing
bundle install
cp .env.example .env              # fake AI provider by default, no secrets needed
bin/rails db:prepare              # creates meeting_action_development, runs migrations
bin/rails db:seed                 # two fictional organizations, their users, and 8 demo meetings
bin/rails server -p 3000          # http://localhost:3000, health check at /up
```

To reset the demo data (for example after running the live test, which adds a meeting), run `bin/rails db:seed:replant`. It empties every table, signs out the app, and seeds again.

Set `DATABASE_URL` in `backend/.env` if your PostgreSQL isn't on the default local socket.

### Seeded users and development sign-in

| Organization | User | Email |
| --- | --- | --- |
| Acme Robotics | Maya Chen | maya@acme.test |
| Acme Robotics | Leo Park | leo@acme.test |
| Globex Studios | Nina Patel | nina@globex.test |
| Globex Studios | Omar Haddad | omar@globex.test |

The seeded meetings are synthetic and show every state of the flow. Due dates are relative to the day you seed, so the Actions screen always has overdue, due-this-week, later and completed items.

| Organization | Meeting | State |
| --- | --- | --- |
| Acme Robotics | Q1 launch planning | Reviewed: 3 actions (one overdue, one due this week, one done) |
| Acme Robotics | Northwind pilot feedback review | Reviewed: 2 actions (one edited before accepting, one done) and 1 suggestion still pending |
| Acme Robotics | Controls engineer hiring sync | Fresh: no commitments in the notes, so generating finds none |
| Acme Robotics | Robot arm safety review | Fresh: generate to get 2 commitments and 1 decision |
| Acme Robotics | Weekly engineering sync | Fresh: generate to get 2 commitments and 1 decision |
| Globex Studios | Brand refresh kickoff | Reviewed: 3 actions (one overdue and edited, one done) |
| Globex Studios | Spring campaign storyboard review | Pending review: 2 suggestions |
| Globex Studios | Studio operations weekly | Fresh: generate to get 2 commitments and 1 decision |

The app's sign-in screen lists these users. Tapping one calls `POST /api/v1/dev/session {"email": ...}`. That returns a random bearer token, and the server stores only its SHA-256 digest. Every other request sends `Authorization: Bearer <token>`. The server takes the organization from the token's user, never from the client. This shortcut is for development only: the `dev/*` routes are drawn only when `Rails.env.local?` is true, and there are no passwords, registration or reset.

```bash
TOKEN=$(curl -s -X POST localhost:3000/api/v1/dev/session -H 'Content-Type: application/json' \
  -d '{"email":"maya@acme.test"}' | ruby -rjson -e 'puts JSON.parse(STDIN.read)["token"]')
curl -s localhost:3000/api/v1/meetings -H "Authorization: Bearer $TOKEN"
```

### AI provider

| `AI_PROVIDER` | Behaviour |
| --- | --- |
| `fake` (default) | Deterministic. Recognises `<Name> will <task> by <YYYY-MM-DD>.` and `Decision: <task>.` sentences. No secrets. |
| `anthropic` | Real adapter using the official `anthropic` Ruby SDK, model `claude-opus-5-5`, with structured JSON output. Needs `ANTHROPIC_API_KEY` in `backend/.env`. |

The real adapter is unit-tested against a stand-in SDK client, and was run against the live API on 2026-10-30: all 5 real evaluation cases passed, and loosely written notes gave grounded suggestions in about 5 s. See [EVALUATION.md](EVALUATION.md). With `AI_PROVIDER=anthropic` the app accepts natural notes; with `fake` it only recognises the two sentence shapes above.

To demo failures, inject them into the running server's fake provider without restarting it:

```bash
bin/rails "ai:fake_mode[malformed_once]"   # next generation returns invalid JSON, then recovers
bin/rails "ai:fake_mode[timeout_once]"     # next generation raises a provider timeout
bin/rails "ai:fake_mode[slow]"             # every generation waits 5s (FAKE_AI_SLOW_SECONDS)
bin/rails ai:fake_mode:clear               # back to normal
```

## 2. Run the mobile app

```bash
cd mobile
flutter pub get
open -a Simulator                                   # or: xcrun simctl boot "iPhone 16"
flutter devices                                     # note the simulator id
flutter run -d <simulator-id>                       # API defaults to http://localhost:3000
```

**API base URL.** The app reads it from `--dart-define=API_BASE_URL=...`. Without that, it uses:
- `http://localhost:3000` on the iOS simulator, which shares the Mac's network.
- `http://10.0.2.2:3000` on the Android emulator, which is the emulator's alias for the Mac's localhost.

For a physical device, start Rails with `bin/rails server -b 0.0.0.0 -p 3000` and run the app with:

```bash
flutter run --dart-define=API_BASE_URL=http://<your-mac-LAN-ip>:3000
```

**Warning:** binding to `0.0.0.0` exposes the unauthenticated dev sign-in to everyone on your network, and anyone there can get a token for any seeded user. Only do this on a trusted network, with synthetic data.

The sign-in screen shows which URL the app is using.

**App icon and launch screen.** Generated from `mobile/assets/branding/`. To change them, edit and run `flutter test tool/generate_brand_assets.dart`, then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`. iOS caches launch screens, so restart the simulator to see a new one.

**Demo journey.** Sign in as Maya, tap **New meeting**, and paste synthetic notes. Tap **Generate suggestions**, edit one suggestion and tap **Accept**. Open **Actions** and tick the item. Fully quit and relaunch the app: you stay signed in, and the action is still completed. Sign in as Nina and Acme's meetings aren't visible.

## 3. Tests and evaluation

```bash
# API: models, services, request specs, isolation, concurrency
cd backend && bin/rails test

# Lint and security scan
bin/rubocop && bin/brakeman -q

# Evaluation fixtures (challenge/fixtures/evaluation-cases.json)
bin/rails "eval:run[fake]"
bin/rails "eval:run[anthropic]"            # needs ANTHROPIC_API_KEY; otherwise every case is "blocked"

# Flutter unit + widget tests
cd mobile && flutter test && flutter analyze

# Live journey: real Flutter UI against the running API and database
cd backend && bin/rails "ai:fake_mode[malformed_once]"      # optional: exercise the error path
cd mobile && flutter test test/live_backend_test.dart --dart-define=LIVE_API_BASE_URL=http://localhost:3000
```

## Troubleshooting

- **`xcodebuild failed to load a required plug-in … run 'xcodebuild -runFirstLaunch'`.** Xcode 26.3's system components aren't installed yet. Run `sudo xcodebuild -runFirstLaunch` once in a terminal; it asks for your password. The first build machine hit exactly this.
- **Low disk space.** An iOS debug build needs roughly 2–3 GB free.
- **`Could not reach the server at http://localhost:3000`** in the app. Check that Rails is running, or pass `API_BASE_URL`.
- **Sign-in list is empty.** Run `bin/rails db:seed`.

## Known gaps

- The real Anthropic adapter was checked on 5 evaluation cases and one extra note only. Short notes take 3–5 s against a 25 s timeout with one retry; long notes on a model that always thinks are unmeasured and may exceed it.
- The demo video hasn't been recorded, and the full journey hasn't been tapped through on the simulator yet (the app does build and launch there); see the Status table.
- The Liquid Glass UI was added after the core build. It is checked by the widget tests and the live journey, and visually on the simulator's sign-in screen only; dark mode, Android, and frame times with many blurred surfaces have not been checked.
- The meeting list has no pagination, and there is no rate limiting on generation.
- Dev sign-in issues one token per user. Signing in as the same user elsewhere, for example with the curl example or the live test, signs out the app.
- A client timeout during generation is recovered by refreshing; there is no push or polling.

## Next three improvements

1. Run the five extraction cases against the real provider, then tune `Ai::Prompt` and record the results.
2. Move generation to a background job with a status endpoint the app polls. This removes the long synchronous request and the client-timeout gap.
3. Add per-user rate limits and provider cost/latency metrics on `suggestion_generations`, plus a minimum-client-version header for API evolution.
