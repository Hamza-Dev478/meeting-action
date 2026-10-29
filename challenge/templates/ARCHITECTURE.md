# Architecture and tradeoffs

Aim for one page. Separate implemented behavior from proposed improvements.

## Flow and data

Show the Flutter → Rails → provider/database path and the main entities. A small diagram is welcome.

## Boundaries

Explain authentication, organization scoping, credential handling, AI response validation, and grounding limits.

## Failure and concurrency

Explain repeated acceptance, concurrent requests, client timeouts, provider retries, and the choice of synchronous work or background jobs.

## Production evolution

Explain how you would monitor failures and cost, handle higher usage, and change the API without breaking older installed mobile apps. Mention migration compatibility and recovery where relevant.

## Current state

- Implemented:
- Incomplete or unverified:
- Next three improvements, ordered by importance:
