# identity-memory-budget — Design

One sizing decision: **96 MB**, covering one in-flight Argon2id hash (64 MiB mandated by `identity-bootstrap-mvp`) plus baseline (~4 MB) and margin.

Alternatives considered:

- **128 MB (two concurrent hashes)**: doubles the reservation for a throughput scenario the demo platform does not have; a second concurrent register would transiently brush the cgroup limit and, worst case, fail one request — acceptable at v1. Rejected for frugality; revisit with a registration-throughput requirement.
- **Lower Argon2 `m`**: would fit 25 MB but weakens the committed OWASP posture and amends a frozen security spec to satisfy an accounting table — exactly backwards. Rejected.
- **Serialize hashing behind a semaphore** (code change): keeps 25 MB nominal but still needs >64 MiB for the single hash — arithmetic doesn't close. Rejected.
