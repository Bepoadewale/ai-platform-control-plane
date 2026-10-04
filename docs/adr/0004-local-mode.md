# ADR 0004: Local mode renders desired state

**Status:** Retained as a contributor-harness decision. Since the AWS pilot completed on
2026-10-04, the cloud reference is the primary deployment story.

**Decision:** Local mode has no AWS prerequisite and renders manifest values instead of pretending to create cloud resources.

**Why:** It makes contributor review and testing accessible without pretending to create cloud
resources. Local execution is not used to claim AWS or enterprise/public-SaaS behavior.
