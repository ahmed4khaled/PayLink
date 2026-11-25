# PayLink Student Brief to Design Traceability

## Source and review scope

Primary source: the user-provided `PayLink Year Work Project - Student Brief.pdf`, especially Sections 2.1–2.7, 3.1–3.4 and the Phase 1 deliverables in Section 4. The PDF was read during this review, but it is absent from the final current working tree at the repository root. Add the authoritative brief to the team's submission package through its explicit review/staging process. This review also compared `docs/requirements.md` and the current design pack. The brief takes precedence where the requirements pack differs.

“Full” means the design explicitly represents the required behavior. “Partial” means a related AQ decision or implementation evidence is still outstanding. This is a design review; it does not claim that the required automated tests or Phase 2 implementation exist.

`docs/requirements.md` includes NFR-07 through NFR-09 as team targets/proposals; they are not listed in the official Brief's Section 3.3 and are not treated as official Student Brief requirements in this matrix.

## Business rules and biller behavior

| Brief reference | Required behavior and exact values | Design coverage | Status and correction |
|---|---|---|---|
| 2.2, 2.3 | Inquiry shows bill amount, fee and total before confirmation; wallet available/held balances come from a ledger, never direct balance overwrites. | `pay-bill-sequence.puml`, `class-diagram.puml`, `database-erd.puml` | Full. The full amount including fee is held. Sara’s 350.00 + 2.50 = 352.50 EGP example resolves AQ-13. |
| 2.4 ElectroCo | REST/JSON, meter-number inquiry, under 1 second, immediate confirmation. Phase 2 field names change, amounts use piasters, requests are signed; only ElectroCo integration changes. | `modules.md`, `design-patterns.md`, `class-diagram.puml`, `architecture.md` | Full. API v2 mapping, conversion and signing are assigned to `ElectroCoAdapter`. |
| 2.4 AquaCo | SOAP-style XML over HTTP, 2–4 second responses, different field names/error codes, refuses payments above bill amount. | `modules.md`, `class-diagram.puml`, `pay-bill-sequence.puml` | Full. Adapter maps the error code to a definitive refusal and reason. |
| 2.4 TopUpNet | REST/JSON; initial `Accepted`; later `Success` or `Failed` callback. | `modules.md`, `class-diagram.puml`, `pay-bill-sequence.puml`, `database-erd.puml` | Full. `Accepted` remains pending in `SentToBiller`; only a definitive callback changes state. Duplicate callback fingerprints are ignored and logged. |
| 2.4 NetCo | Optional daily CSV, one payment-file upload per day, next-morning result file, no live inquiry. | `modules.md`, `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Full. NetCo is represented as an optional batch adapter and reconciliation source, not a live inquiry target. |
| 2.6 limits | Basic daily limit 5,000 EGP; verified daily limit 30,000 EGP; single payment 5–10,000 EGP. | `payment-state.puml`, `class-diagram.puml`, `use-case.puml`, `database-erd.puml`, `docs/requirements.md` | Values represented. Daily-total fee composition and whether rejected attempts count toward daily limits remain open under AQ-14. Velocity-attempt treatment is separately recorded in the next row. |
| 2.6 fees | Electricity/water fixed 2.50 EGP; mobile 1.5%, minimum 1 EGP; internet 2 EGP through 200 EGP and 4 EGP above; promotion waives fee for one configured biller/date range. | `design-patterns.md`, `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Full. Strategies, tiers and promotion configuration are modeled. |
| 2.6 commission | 40% of service fee, credited to agent wallet when payment completes. | `modules.md`, `class-diagram.puml`, `database-erd.puml`, `pay-bill-sequence.puml` | Full. Credited once for an agent-assisted completed payment. |
| 2.6 velocity | More than 5 payments from one account in 60 seconds blocks new payment attempts for 10 minutes. | `modules.md`, `class-diagram.puml`, `use-case.puml`, `design-patterns.md`, `payment-state.puml`, `pay-bill-sequence.puml`, `docs/requirements.md` | User approved counting payment initiation attempts, including later-rejected attempts, on 2026-11-25. **Reason:** detect rapid repeated activity before it can evade the rule through rejected outcomes. This records user approval only, not team/TA approval. Whether fees/rejected attempts count toward daily limits remains open. |
| 2.6 timeout/retries | Live-biller timeout 10 seconds; Unknown is re-queried at 1, 5, and 15 minutes, up to three times, then waits for reconciliation. | `architecture.md`, `modules.md`, `design-patterns.md`, `payment-state.puml`, `pay-bill-sequence.puml`, `class-diagram.puml`, `database-erd.puml`, `docs/requirements.md` | User approved measuring all offsets from entry into Unknown on 2026-11-25. **Reason:** deterministic retry times from the start of the unresolved payment state. This records user approval, not team/TA approval. If no definitive outcome follows, Unknown and the hold remain until reconciliation/evidence. |
| 2.6 notifications | Failed SMS or email is retried three times, then marked Undelivered. | `architecture.md`, `modules.md`, `class-diagram.puml`, `pay-bill-sequence.puml` | Full for SMS/email. Whether push shares the retry rule remains AQ-16. |
| 2.6 money | Exact decimal types, never floating point. | `class-diagram.puml`, `database-erd.puml`, `architecture.md` | Full. Money and stored amounts use Decimal. |

## Required modules (Section 3.1)

| Required module | Design representation | Status |
|---|---|---|
| Accounts and Wallet | `modules.md`, `class-diagram.puml`, `database-erd.puml` | Full: accounts, verification, wallets, derived balances, ledger, holds, top-ups and refund credits. |
| Biller Catalog | `modules.md`, `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Full: billers, services, input fields, amount bounds and activation. |
| Payment Processing | `modules.md`, `class-diagram.puml`, `pay-bill-sequence.puml`, `payment-state.puml` | Full: lifecycle, idempotency and orchestration. |
| Biller Integration | `modules.md`, `class-diagram.puml`, `pay-bill-sequence.puml` | Full: one adapter per required biller, timeout, callback and batch boundaries. |
| Fees and Commissions | `modules.md`, `design-patterns.md`, `class-diagram.puml`, `database-erd.puml` | Full: fixed, percentage, tiered, promotion and agent commission. |
| Notifications | `modules.md`, `class-diagram.puml`, `pay-bill-sequence.puml`, `use-case.puml`, `docs/requirements.md` | Completion and failure notifications are required by FR-22. SMS and push are specified there; SMS/email retry rule is explicit in Section 2.6. Rejected/refund outcomes are marked optional proposals, not mandatory behavior. Push retry scope remains AQ-16. |
| Fraud Checks (extra) | `modules.md`, `class-diagram.puml`, `pay-bill-sequence.puml` | Velocity counting interpretation is user-approved; daily-limit count details under AQ-14 remain open. |
| Reconciliation (extra) | `modules.md`, `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Full: settlement comparison, report differences and support review. |

## Functional requirements

| ID | Required behavior | Design file(s) | Status and correction |
|---|---|---|---|
| FR-1 | Register customer at Basic verification. | `class-diagram.puml`, `use-case.puml` | Partial: registration fields remain AQ-01. |
| FR-2 | Upgrade customer to Verified and raise limits. | `class-diagram.puml`, `use-case.puml`, `payment-state.puml` | Partial: approval actor/workflow remains AQ-02. |
| FR-3 | View available/held balance and transaction history. | `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Full; balances derive from ledger. |
| FR-4 | Top up using simulated card or agent cash. | `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Partial: simulated-card limits/failure rules remain AQ-03. |
| FR-5 | Every balance change has a ledger entry; balances computed from ledger. | `class-diagram.puml`, `database-erd.puml`, `architecture.md` | Full. |
| FR-6 | Admin adds, edits and disables billers/services. | `modules.md`, `class-diagram.puml`, `use-case.puml` | Full. |
| FR-7 | Customer sees billers and required inputs. | `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Full; examples include meter number and phone number. |
| FR-8 | Bill inquiry shows amount, fee and total before paying. | `pay-bill-sequence.puml`, `class-diagram.puml`, `use-case.puml` | Full for successful inquiry. Inquiry failure/timeout and changed amount remain AQ-05/AQ-06. |
| FR-9 | Pay a bill from wallet. | `pay-bill-sequence.puml`, `use-case.puml` | Full. |
| FR-10 | Same idempotency key returns original result. | `pay-bill-sequence.puml`, `database-erd.puml`, `class-diagram.puml` | Full; unique customer/key constraint and duplicate flow represented. |
| FR-11 | Allow only Section 2.5 lifecycle transitions. | `payment-state.puml`, `class-diagram.puml`, `architecture.md`, `design-patterns.md` | Full after removing extra transitions. |
| FR-12 | Hold before biller call; release on confirmed failure. | `pay-bill-sequence.puml`, `refund-sequence.puml`, `database-erd.puml` | Full; hold/release are atomic and idempotent; failed release ends at Refunded. |
| FR-13 | Timeout enters Unknown and retries by schedule. | `payment-state.puml`, `pay-bill-sequence.puml`, `class-diagram.puml`, `docs/requirements.md` | Retry anchor is user-approved: offsets from entry into Unknown; no payment resubmission. This does not claim team/TA approval. |
| FR-14 | Accept TopUpNet callbacks and ignore duplicates. | `class-diagram.puml`, `database-erd.puml`, `pay-bill-sequence.puml` | Full; duplicate callback is audited without a repeated transition/movement. |
| FR-15 | Three required billers; NetCo batch optional. | `modules.md`, `class-diagram.puml`, `use-case.puml` | Full. |
| FR-16 | Fees follow Section 2.6 including promotion. | `design-patterns.md`, `class-diagram.puml`, `database-erd.puml` | Full. |
| FR-17 | Agent pays for customer and earns commission. | `pay-bill-sequence.puml`, `class-diagram.puml`, `database-erd.puml` | Full; only on completion, credited once. |
| FR-18 | Above single/daily limit is rejected with reason. | `class-diagram.puml`, `payment-state.puml`, `pay-bill-sequence.puml` | Partial on AQ-14 daily-total interpretation; single limits are explicit. |
| FR-19 | More than 5 in 60 seconds blocks account for 10 minutes. | `modules.md`, `class-diagram.puml`, `use-case.puml`, `design-patterns.md`, `payment-state.puml`, `pay-bill-sequence.puml`, `docs/requirements.md` | Official threshold and duration are represented. User approved counting initiation attempts, including later-rejected attempts, on 2026-11-25; this is not recorded as team/TA approval. |
| FR-20 | Support searches by reference and sees full history. | `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Full. |
| FR-21 | Support blocks/unblocks account. | `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Full; effect on in-flight payments remains AQ-10. |
| FR-22 | SMS and push on completion and failure. | `class-diagram.puml`, `pay-bill-sequence.puml`, `use-case.puml` | Full. |
| FR-23 | Retry failed notifications three times, then Undelivered. | `architecture.md`, `modules.md`, `class-diagram.puml`, `pay-bill-sequence.puml` | Full for SMS/email; push remains AQ-16. |
| FR-24 | Admin edits fees/limits without redeployment. | `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Full through configuration service/items. |
| FR-25 | Audit every money movement and admin action. | `class-diagram.puml`, `database-erd.puml`, `pay-bill-sequence.puml`, `refund-sequence.puml`, `use-case.puml` | Full in the design. |
| FR-26 | Daily reconciliation report from settlement file. | `architecture.md`, `modules.md`, `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | Partial on timezone AQ-11; mismatch and support review are represented. |
| FR-27 | Optional customer refund request for Completed payment, support approves. | `refund-sequence.puml`, `class-diagram.puml`, `database-erd.puml`, `use-case.puml` | User-approved deferral (2026-11-25), not team/TA approval: keep outside Phase 1 implementation until AQ-07/AQ-12 are resolved. The user also approved the AQ-12 reviewer/audit proposal, pending team/TA confirmation. Wallet credit remains only a proposal; no Completed → Refunded transition. |
| FR-28 | Admin views daily payment, fee, commission and per-biller failure totals. | `class-diagram.puml`, `use-case.puml`, `modules.md` | Full. |

## Eight hard cases (Section 2.7)

| # | Required outcome | Design coverage | Status |
|---|---|---|---|
| 1 | Duplicate request: one payment/charge; second gets original result. | `pay-bill-sequence.puml`, `database-erd.puml` | Full: idempotency lookup and uniqueness. |
| 2 | ElectroCo answers at 12 seconds: Unknown at 10 seconds, customer told processing, funds held. | `pay-bill-sequence.puml`, `payment-state.puml` | Full: late response resolves Unknown only through a valid transition. |
| 3 | AquaCo refusal/error code: Failed, release, SMS with clear reason. | `modules.md`, `pay-bill-sequence.puml`, `refund-sequence.puml`, `class-diagram.puml` | Full. |
| 4 | Two simultaneous payments, balance covers one: one succeeds, other Rejected, no negative balance. | `pay-bill-sequence.puml`, `class-diagram.puml`, `database-erd.puml` | Full: atomic conditional reservation on ledger-derived available funds. |
| 5 | SMS provider outage: payment completes; SMS retries and ends Undelivered. | `pay-bill-sequence.puml`, `architecture.md`, `modules.md`, `class-diagram.puml` | Full: three additional SMS retries, independent of payment. |
| 6 | Duplicate TopUpNet success: one completion; second callback ignored and logged. | `pay-bill-sequence.puml`, `class-diagram.puml`, `database-erd.puml` | Full: per-biller fingerprint, state validation, audit record. |
| 7 | Settlement lists a PayLink Failed payment: report difference for Support review. | `use-case.puml`, `modules.md`, `architecture.md`, `database-erd.puml` | Full: flag only; no automatic state change. |
| 8 | Add a biller with new integration/config only. | `architecture.md`, `modules.md`, `design-patterns.md`, `class-diagram.puml` | Full: adapter/factory boundary; ElectroCo v2 changes only ElectroCoAdapter. |

No automated tests are claimed by this design traceability review.

## Non-functional and technical requirements

| Brief reference | Required behavior | Design coverage | Status and correction |
|---|---|---|---|
| 3.3 Correctness | Zero double charges and zero negative balances in duplicate/concurrency tests. | `pay-bill-sequence.puml`, `database-erd.puml`, `class-diagram.puml` | Brief-defined target. Verify with duplicate-request and concurrent-reservation tests; testable after implementation. No result is claimed. |
| 3.3 Performance | 100 payments/second for one minute against mock billers. | `architecture.md` | Brief-defined target. Verify with a timed load test against mock billers; testable after implementation. No result is claimed. |
| 3.3 Resilience | One biller outage does not stop other billers. | `modules.md`, `architecture.md`, `design-patterns.md` | Brief-defined target. Verify by disabling one mock biller while testing another; testable after implementation. No result is claimed. |
| 3.3 Modifiability | New biller changes Biller Integration and configuration only. | `architecture.md`, `modules.md`, `class-diagram.puml` | Brief-defined target. Verify through the Phase 2 biller change request and a diff/review of changed modules; testable after implementation. No result is claimed. |
| 3.3 Auditability | Every movement has who/when/why audit data. | `class-diagram.puml`, `database-erd.puml`, `pay-bill-sequence.puml`, `refund-sequence.puml` | Brief-defined target. Verify every generated financial movement has linked actor/time/reason audit data; testable after implementation. No result is claimed. |
| 3.3 Testability | At least 70% domain-logic line coverage in CI. | `.github/workflows/ci.yml` (workflow currently runs `clean verify`; no coverage report configured) | Brief-defined target. Verify the CI coverage report for domain logic; testable after implementation. No coverage result is claimed. |

| 3.4 Database | Relational DB with at least 10 tables and schema migrations. | `database-erd.puml`, `architecture.md` | ERD models 29 logical entities (recounted from the 29 `entity` declarations). No schema-migration files were found; migrations are an implementation deliverable, not an ERD/design completeness defect. |
| 3.4 API | At least 20 REST endpoints documented in OpenAPI, plus async flow. | `architecture.md`, `class-diagram.puml`, `use-case.puml` | Async in-application event flow is designed. No OpenAPI specification was found, so endpoint count/documentation remain unverified implementation work. |
| 3.4 Patterns/architecture | At least 5 patterns; layered or hexagonal modular monolith. | `design-patterns.md`, `class-diagram.puml`, `architecture.md` | Full: seven patterns, Modular Monolith and Layered Architecture. |
| 3.4 Phase 2 architecture | Evolve Notifications and Reconciliation to event-driven/service-based style with ADR. | `architecture.md`, `modules.md`, `class-diagram.puml` | Planned boundary is documented; Phase 2 ADRs and deployment remain future work. |
| 3.4 Docker/CI/tests/UI | Dockerfile, Compose, workflow that builds, lints and runs a test on every push; implementation tests/client are later work. | `Dockerfile`, `docker-compose.yml`, `.github/workflows/ci.yml`, `pom.xml`, `config/checkstyle/checkstyle.xml` | Maven Checkstyle is bound to `verify`, and CI runs `./mvnw -B clean verify`; Java 27 matches Maven and Docker stages. The branch trigger now includes all branches. Compose config passed; Docker Engine is unavailable for image/runtime checks. YAML parser validation and a CI run for these unpushed changes remain outstanding. |

The six targets above are the official Section 3.3 NFRs. The Section 4 requirements-pack deliverable asks for at least six measurable NFRs; NFR-01 through NFR-06 are documented with targets and verification methods above. Section 3.3 separately says to choose and measure at least six and have tests or reports show the numbers. No measurements are claimed here: this review did not fabricate runtime or performance figures, and those require an implemented system. Genuine Section 3.3 measurement evidence remains outstanding; the team/TA should confirm how it is expected to be produced for the Phase 1 submission. NFR-07 to NFR-09 in the requirements pack are team proposals, not official Brief targets, and must remain visibly unapproved until the team/TA agrees.

## Phase 1 design deliverables (Section 4)

| Required deliverable | Source file | Result |
|---|---|---|
| Use-case diagram | `use-case.puml` | Present; actors, payment, refunds, reconciliation and optional NetCo modeled. |
| Domain class diagram | `class-diagram.puml` | Present; domain entities, responsibilities and patterns modeled. |
| Pay-bill sequence | `pay-bill-sequence.puml` | Present; inquiry through outcomes, retries, callbacks and hard cases represented. |
| Refund a failed payment sequence | `refund-sequence.puml` | Present as primary diagram; optional FR-27 is a separate second diagram in the same source file. |
| Payment state diagram | `payment-state.puml` | Present; only Section 2.5 transitions. |
| Database ER diagram | `database-erd.puml` | Present; 29 logical entities, relational keys and constraints. Entity count independently recounted from source declarations. |

Other Section 4 Phase 1 items: `docs/prompt-log.md`, `docs/requirements.md`, and `docs/requirements.pdf` exist. The PDF text was extracted and contains key approved requirements, but it must be regenerated after the current Markdown decision update. No Markdown-to-PDF converter/library or project generation script was found in the available environment. Prompt records include five genuine prompts from the current conversation, but two verified incorrect-answer/improved-prompt cases remain missing; see the Prompt Log. CI trigger and Docker/PlantUML validation results are reported in the remediation report, not inferred from file presence. The official Student Brief PDF was used for this review but is now absent from the current worktree; confirm the team's submission package includes it.

## AQ decisions checked against the brief

| Decision | Brief result | Design status |
|---|---|---|
| AQ-01 registration fields | Not specified. | Open; no fields invented. |
| AQ-02 verification approval | Upgrade required; actor/evidence not specified. | Open. |
| AQ-03 simulated-card rules | Simulated card top-up required; limits/failure rules not specified. | Open. |
| AQ-04 agent authentication | Internal PayLink authentication is approved. Agent identity provisioning, credential lifecycle, and the login key are not specified by requirements. | Partly resolved: the user approved deferring login-identifier selection until provisioning is defined for all roles (2026-11-25). **Reason:** the brief selects no credential key, so choosing one would invent a requirement. This records user approval, not team/TA approval. Agent provisioning and credential lifecycle remain open. |
| AQ-05 inquiry failure/timeout | Bill inquiry required; failure/timeout behavior not specified. | Open. |
| AQ-06 bill amount changes after inquiry | Not specified. | Open. |
| AQ-07 completed-payment refund details | FR-27 is optional; the brief does not specify method, amount/eligibility or ledger treatment. | User approved deferring implementation/definition on 2026-11-25, not team/TA approval. The policy remains open pending team/TA resolution of AQ-07/AQ-12; wallet credit is only a proposal; no Completed → Refunded transition. |
| AQ-08 exhausted Unknown retries | Brief says wait for reconciliation. | Resolved; remain Unknown, funds held. |
| AQ-09 callback authentication | Callback required; authentication scheme not specified. | Open. |
| AQ-10 block during in-flight payment | Not specified. | Open. |
| AQ-11 daily timezone | Not specified. | Open. |
| AQ-12 refund approval authorization/audit detail | User approved a proposed single authorized Support-role reviewer with actor, timestamp, outcome, reason, payment/refund identifiers and resulting ledger movement recorded; no dual control in the proposed flow (2026-11-25). | User approval only; team/TA confirmation remains pending. FR-27 remains deferred; this proposal is not a team decision. |
| AQ-13 hold composition | Section 2.2 explicitly holds Sara's 352.50 EGP total (350.00 bill + 2.50 fee). | Resolved: hold bill amount plus fee. `docs/requirements.md` and its regenerated PDF reflect the resolution. |
| AQ-14 daily/velocity count | Velocity threshold is more than 5 payments in 60 seconds; daily limit fee composition and rejected-attempt treatment are not specified. | Partly resolved: user approved counting all payment initiation attempts, including later-rejected attempts, on 2026-11-25. Reason: detect rapid repeated activity before it can evade the rule through rejected outcomes. This is not team/TA approval. Daily-limit fee/rejected-attempt composition remains unresolved. |
| AQ-15 retry anchor | Offsets 1, 5, 15 specified; anchor is not explicit. | User approved all offsets from Unknown entry on 2026-11-25. Reason: deterministic retry times from the start of the unresolved state. This records user approval only, not team/TA approval. |
| AQ-16 push retries | SMS/email retries specified; push retry scope is not. | Open. |

## Internal authentication and session management

The approved technical design decision is: **Internal Authentication using Spring Security, separate `account_credentials` and `login_sessions` tables, `Argon2PasswordEncoder`, and database-backed stateful sessions.** The design does not add a new requirement ID or change the payment lifecycle.

| Existing requirement / source | Current coverage | Missing requirement or decision |
|---|---|---|
| US-001 / FR-1 customer registration | `use-case.puml`, `class-diagram.puml`, `modules.md`, `database-erd.puml` | Registration is represented. Required personal fields remain AQ-01. Credential setup/completion details are not defined. |
| NFR-07 protected endpoint authentication and role/permission authorization (team target; validate with TA) | `architecture.md`, `modules.md`, `class-diagram.puml`, `use-case.puml` | Internal authentication and RBAC for Customer, Agent, Admin, and Support are designed. Endpoint-level permissions and automated verification belong in implementation requirements/tests. |
| AQ-04 agent identification/authentication | `architecture.md`, `modules.md`, `class-diagram.puml`, `database-erd.puml`, `docs/requirements.md` | Internal authentication is selected. The user approved keeping the login identifier unspecified until all-role provisioning is defined (2026-11-25); reason: the brief selects no credential key, and choosing one would invent a requirement. This is not team/TA approval. Agent provisioning/identity remains open; no registration or credential issuance flow is inferred. |
| Login, logout, logout-all, change/reset password | `use-case.puml`, `class-diagram.puml`, `architecture.md` | These behaviors are represented as design use cases, but are not explicit functional requirements in the current requirements document. Team should define acceptance criteria and reset verification before implementation. |

The following policy decisions remain open for team/TA approval; the design assigns no values:

- Session expiration duration and session inactivity timeout.
- Account lockout threshold and lockout duration.
- Password complexity policy and failed-login rate-limit policy.
- Password-reset verification and expiration rules.
- Maximum concurrent sessions per account.
- Whether password changes must revoke all active sessions.
- The actual account login identifier and its provisioning, especially for Agent, Admin, and Support accounts. Deferring the choice until all-role provisioning is defined is user-approved (2026-11-25); the identifier itself remains open.

The class-diagram `loginIdentifier` is only a generic request placeholder. The user approved deferring the choice on 2026-11-25; no phone, email, username, or other key has been selected, and this does not claim team/TA approval. The ERD therefore does not add an assumed identifier field; resolve the actual key before implementation/API persistence is fixed.

## Traceability gaps requiring team review

- The eight hard cases and FR-1 through FR-28 are mapped above. User stories US-001 through US-028 are linked from the requirements traceability table, but this design matrix does not separately map every individual Given/When/Then criterion to a diagram element.
- Login, logout, logout-all, password change/reset, and RBAC are represented as an approved internal-authentication design addition, but they do not yet have dedicated functional requirement IDs and acceptance criteria. The team must decide whether to add them to the requirements baseline before implementation.
- NFR-07 through NFR-09 are not official Section 3.3 requirements. Their proposal status and need for team/TA approval must be preserved.
- NFR-01 through NFR-06 have documented target and verification-method sources, but no measurements are available in this Phase 1 evidence set.
- The root Student Brief PDF is user-provided and untracked. Confirm the submission package contains the authoritative source document.

Cookie deployment settings must include `HttpOnly`, `Secure`, an appropriate `SameSite` value, and CSRF protection for cookie-authenticated state changes. Passwords and raw session tokens are never persisted; only the password hash and session-token hash are stored. Session validation rejects expired or revoked sessions. These are technical design constraints, not new Student Brief requirement IDs.
