# Public assessment rubric

Score demonstrated evidence, not confidence or framework trivia. Each category receives 0–4; weighted points equal `weight × rating / 4`.

| Rating | Meaning |
| --- | --- |
| 0 | Missing or cannot explain |
| 1 | Substantial gaps; little reliable evidence |
| 2 | Core approach works, with meaningful weaknesses |
| 3 | Solid implementation, verification, and explanation |
| 4 | Strong judgment demonstrated in both the submission and live adaptation |

| Category | Weight | What we examine |
| --- | ---: | --- |
| AI-assisted engineering | 25 | Context, bounded tasks, critical review, independent verification, effective live use |
| Rails and data integrity | 20 | Modeling, authorization, persistence, concurrent duplicate prevention, meaningful tests |
| Flutter and integration | 15 | Actual API integration, useful state handling, error recovery, working journey |
| AI feature reliability | 15 | Grounding, validation, evaluation quality, predictable failures |
| System design and ownership | 20 | Tradeoffs, retries, operations, mobile compatibility, prioritization |
| Handoff quality | 5 | Reproducible setup, concise documentation, accurate limitations |

AI use is not a penalty. Blindly trusting generated work is a weakness. Logs are supporting evidence; the live review checks understanding and ability to adapt.

Extra infrastructure, polished graphics, agent count, premium tooling, or lengthy documents earn no points by themselves. A candidate who identifies a limitation precisely provides stronger evidence than one who claims unsupported guarantees.

## Interpreting the result

For interviewers, 75/100 is a starting calibration threshold, not an automatic hiring decision. A solo-owner recommendation should also require at least 3/4 in AI-assisted engineering, Rails/data integrity, and system design, plus at least 2/4 in Flutter/integration and AI reliability.

Resolve concerns about cross-organization access, inability to modify generated code, mocked behavior represented as real integration, or falsely reported checks before recommending hire. Distinguish disclosed incompleteness from concealed or misunderstood behavior.

This bounded exercise provides evidence about a candidate's capabilities; it does not establish that they can independently own every part of a production system.
