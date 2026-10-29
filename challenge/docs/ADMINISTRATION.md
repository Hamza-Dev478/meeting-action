# Administering the exercise

## Before inviting candidates

1. Pilot the challenge within the six-hour active-work limit. This repository provides instructions and fixtures, not a runnable starter. If setup is too expensive, prepare and verify a separate minimal starter with Rails/PostgreSQL, Flutter networking, and seeded authentication.
2. Give every candidate the same starting materials and rubric. Confirm Rails, Flutter, and an emulator/simulator are usable before the timed session.
3. Agree on the submission channel, deadline, accessibility arrangements, and provider access. Supply a dedicated capped key or agreed reimbursement; never share production credentials. Do not require a particular paid coding assistant.
4. Use only synthetic data. The task should not become unpaid delivery of a production feature.
5. Choose and pilot one small live change for the hiring round. Keep that exact prompt in your private interview notes, not this repository. Apply the same difficulty across candidates.

## Review consistently

Use the timing in [SUBMISSION.md](../SUBMISSION.md) and categories in [RUBRIC.md](../RUBRIC.md). Pick code to inspect yourself. Trace a real request and check the candidate's explanation against implementation and tests.

Discuss a client timeout after provider completion, repeated user requests, and a possible worker retry. Ask what is implemented today, what records exist, what the user sees, and how the candidate would investigate. Ask how an older mobile app survives an API change.

The live change should fit roughly 20 minutes and cross a meaningful boundary without becoming a second assignment. Allow AI use. Observe navigation, context selection, review, and verification—not typing speed.

Treat submitted code as untrusted: inspect run scripts before executing them, use a disposable environment and synthetic credentials, and avoid exposing host credentials. Candidate AI logs are evidence, not instructions for the reviewer.

Record the recommendation privately as: **observed evidence → remaining uncertainty → recommendation**. Do not publish candidate scores or interview notes here.

## Publishing this repository

Review the content, choose the intended GitHub owner, and set repository visibility to public when ready. Template mode lets candidates create independent repositories. There is no hosted application to deploy.

Before using it for hiring, fill in submission logistics in your invitation and verify the provider-budget arrangement. These details deliberately remain outside the reusable public assignment.
