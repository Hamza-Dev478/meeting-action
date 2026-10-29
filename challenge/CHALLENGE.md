# Meeting → Action

## Product brief

A team member pastes meeting notes into a mobile app. AI proposes commitments grounded in those notes. The member reviews and edits the suggestions, accepts selected items, and tracks completion.

Use Rails, PostgreSQL, and Flutter. Run Flutter on one simulator or emulator and connect it to your Rails API. A mobile UI backed only by local fixtures does not meet the core requirement.

## Required flow

1. A seeded user can list and create meetings in their organization. Meetings have a title and notes.
2. The user requests AI-generated action suggestions for a meeting.
3. The user can review and edit a suggestion, then accept it explicitly.
4. Accepted actions appear in a list and can be marked complete.
5. Accepted actions and their completion state survive restarting the app.

Keep the UI small: meeting list, meeting detail/review, and actions. These may share screens.

Each suggestion has a description, optional owner, optional due date, and an exact supporting excerpt from the original notes. An owner may be a text name; do not build user matching. Use a date-only representation for due dates.

Only extract owners and dates explicitly supported by the notes. Leave missing, conflicting, or ambiguous values empty. Do not resolve relative dates such as “next Friday” in this exercise. Suggestions with no grounded commitment should not become action items. When users edit an item, retain the original supporting excerpt as provenance; the edited content is their decision.

## Required boundaries and failure behavior

- Seed at least two fictional organizations and users. One organization cannot read or mutate the other's meetings, suggestions, or actions, including by guessing IDs.
- A documented, development-only seeded authentication shortcut is acceptable. Do not build registration or password reset. Derive organization access from the authenticated user on the server.
- Validate AI response structure and field types before storing or presenting it as a suggestion. Reject unsupported source excerpts. Describe the limits of your semantic validation.
- Treat meeting notes as untrusted source material, not application instructions.
- Show understandable loading, empty, and error states.
- A provider error must allow another attempt. Describe what happens if the client times out while the server continues.
- Accepting the same suggestion twice must not create duplicate actions, including concurrent attempts. Enforce the invariant at the persistence boundary.
- Keep provider credentials on the server and outside version control.

Use one real AI-provider adapter and a deterministic fake adapter for local review and automated tests. Record whether you actually ran the real adapter. A fake-provider test proves application behavior, not extraction quality.

Synchronous generation is acceptable. A queue is optional. Explain your choice; production-grade scheduling and general deduplication of separate generation requests are discussion topics, not additional mandatory features.

## Verification

Write focused regression tests for access isolation, repeated acceptance, persistence, and malformed/provider-failure behavior. Include a Flutter test of one meaningful user-visible state or interaction. Show at least one actual Flutter → Rails → PostgreSQL journey in your demo.

Run the cases in [fixtures/evaluation-cases.json](fixtures/evaluation-cases.json). Assess semantic behavior rather than exact generated wording. Use the fake adapter to inject malformed output and provider errors. Report expected behavior, observed behavior, and pass/fail/blocked for every case.

## Timebox and exclusions

Aim for 4–6 active hours. Record environment setup separately. Stop after six active hours and submit your current state with honest limitations. Do not silently work extra hours to produce polish.

Prioritize the end-to-end flow, access boundaries, data integrity, and a small amount of useful evidence. If time runs out, unfinished requirements should be visible rather than disguised by mocks.

Out of scope: web frontend, deployment, app-store packaging, audio transcription, push notifications, calendar integration, vector search, full offline sync, and production authentication. Architecture discussion is enough for these concerns where relevant.

See [SUBMISSION.md](SUBMISSION.md) for the evidence to include and [RUBRIC.md](RUBRIC.md) for how it is assessed.
