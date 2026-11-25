# PayLink – Architecture Design

## 1. Architecture Overview

PayLink follows a **Modular Monolith architecture** using the **Layered Architecture pattern**.

The application is deployed as a single system and organized internally into separate business modules. Each module has a defined responsibility and communicates with other modules through clear interfaces.

This architecture provides a balance between simplicity, maintainability, and extensibility while supporting the consistency required for financial operations.

## 2. Architecture Style: Modular Monolith

A Modular Monolith is selected because PayLink contains several closely related business capabilities, including account management, wallet operations, payment processing, biller integration, fee calculation, notifications, and reconciliation.

These capabilities must cooperate while maintaining consistent financial transactions and payment records.

### Reasons for Choosing Modular Monolith

- **Simplicity:** The application is deployed and managed as one system.
- **Modularity:** Business responsibilities are separated into independent modules.
- **Data Consistency:** Related financial operations can use database transactions to maintain consistency.
- **Maintainability:** Each module has a clear responsibility, reducing unnecessary dependencies.
- **Extensibility:** New biller integrations can be added without changing the core payment business logic.
- **Testability:** Individual modules and their business rules can be tested separately.

## 3. Architecture Pattern: Layered Architecture

The system uses four logical layers.

### 3.1 Presentation Layer

Responsible for receiving requests and returning responses.

Responsibilities:

- Expose REST API endpoints.
- Handle requests from customers, agents, administrators, and support employees.
- Validate request structure and input data.
- Authenticate users and enforce access permissions through the security components.
- Pass requests to the Application Layer.
- Return appropriate responses.

### 3.2 Application Layer

Responsible for coordinating application use cases and business workflows.

Responsibilities:

- Coordinate payment processing operations.
- Coordinate wallet operations.
- Manage bill inquiry and payment use cases.
- Coordinate refund workflows.
- Coordinate communication between business modules.
- Manage transaction idempotency and duplicate request handling.
- Coordinate external callback processing.
- Schedule and coordinate payment status inquiry retries.
- Coordinate daily reconciliation and statistics generation.
- Manage transaction boundaries where required.

### 3.3 Domain Layer

Contains the core business rules and domain logic of PayLink.

Responsibilities:

- Define payment lifecycle rules and valid state transitions.
- Manage wallet and payment business rules.
- Apply payment limits and fraud rules.
- Calculate service fees and agent commissions.
- Enforce financial consistency rules.
- Control fund holding, capturing, and releasing operations.
- Ensure financial operations are processed exactly once.
- Define domain entities and business interfaces.
- Protect against invalid financial operations and duplicate processing.

### 3.4 Infrastructure Layer

Responsible for technical implementations, data persistence, and external communication.

Responsibilities:

- Implement database access and persistence.
- Persist payments, wallets, ledger entries, and audit records.
- Integrate with external billers through isolated adapters.
- Implement external payment and notification provider integrations.
- Handle scheduled background jobs and retry execution.
- Receive and process external callbacks.
- Store callback records to support duplicate detection and traceability.
- Support reconciliation file processing and report storage.
- Provide implementations for interfaces defined by the inner layers.

## 4. High-Level Dependency Rules

The architecture follows these dependency rules:

1. The Presentation Layer communicates with the Application Layer.
2. The Application Layer coordinates use cases and invokes domain business logic.
3. The Domain Layer contains business rules and does not depend on infrastructure implementations.
4. The Infrastructure Layer implements the technical interfaces required by the inner layers.
5. Modules communicate through clearly defined interfaces and application services.
6. A module should not directly modify another module's internal data.
7. External biller protocols and provider-specific details remain isolated from core business logic.
8. Dependencies should point toward the Domain Layer rather than making the Domain Layer depend on external technical details.

## 5. Important Architectural Considerations

### 5.1 Payment Reliability

Payment processing follows the approved payment lifecycle:

- Initiated
- FundsHeld
- SentToBiller
- Completed
- Rejected
- Failed
- Unknown
- Refunded

Only the transitions defined in the requirements are allowed.

The mandatory failed-payment release is a two-step lifecycle outcome: a definitive refusal moves the payment to `Failed`; releasing its held funds exactly once then moves it to `Refunded`. `Failed` is not terminal while that required release is pending. The optional FR-27 refund of a `Completed` payment is separate. On 2026-11-25, the user approved deferring its implementation and refund-method, amount/eligibility and ledger definition until team/TA resolution of AQ-07 and AQ-12. The user separately approved a proposed AQ-12 rule: one authorized Support-role approver, with the decision and resulting movement audited; no dual control in the proposal. Both are user approvals only, not team/TA approval. No `Completed → Refunded` transition or completed-refund method is approved.

When a payment enters the Unknown state:

- Its funds remain held.
- User-approved AQ-15 interpretation (2026-11-25): status inquiries at 1, 5, and 15 minutes after entering Unknown, with all offsets measured from that entry. Rationale: deterministic retry times from the start of the unresolved state.
- Section 2.6 specifies the offsets but not their anchor. This records user approval of the interpretation, not team/TA approval. If no definitive result is available after the three inquiries, payment remains Unknown and awaits reconciliation.
- These retries perform status inquiries and must not blindly resubmit the original payment.
- A confirmed success changes the payment to Completed.
- A confirmed failure changes the payment to Failed.
- If no definitive result is available after the configured retries, the payment remains Unknown and awaits reconciliation.

Unknown payments must never be refunded automatically.

### 5.2 Financial Consistency

Wallet and payment operations must prevent duplicate charges and negative balances.

The system uses:

- Database transactions for related financial updates.
- Idempotency controls to prevent duplicate payment processing.
- A financial ledger to record money movements.
- Audit records to maintain transaction traceability.
- Controlled fund holding, capture, and release operations.
- Atomic and idempotent financial operations to ensure that capture and release are each performed at most once for the corresponding payment outcome.

The payment state/history change and its corresponding hold, capture, or release ledger movement are committed as one database unit of work. Payment events are published only after that outcome commits.

All monetary calculations use exact decimal values rather than floating-point arithmetic.

Section 2.2 resolves AQ-13: the hold is the full customer total (bill amount plus service fee). Sara's example holds 352.50 EGP for a 350.00 EGP bill and a 2.50 EGP fee.

### 5.3 Biller Integration

Each biller integration is isolated behind a common internal interface.

The required mock billers are:

- ElectroCo: REST API using JSON.
- AquaCo: SOAP-style XML over HTTP.
- TopUpNet: REST API using JSON with asynchronous callbacks.

NetCo is an optional integration that uses daily CSV settlement processing.

The ElectroCo API v2 change (field mapping, pounds-to-piasters conversion, and request signing) belongs entirely in `ElectroCoAdapter`; other modules continue using the common biller interface.

TopUpNet callback authentication is not specified and remains open (AQ-09); the architecture does not assume a signature or credential scheme.
TopUpNet's initial `Accepted` is an integration response, not a payment state or definitive outcome; payment remains `SentToBiller` until its callback confirms success or failure.

### 5.4 Failure Handling

A biller timeout must not be treated as a confirmed payment failure.

When a payment enters the Unknown state:

- Its funds remain held.
- The system performs scheduled biller status inquiries.
- A confirmed success changes the payment to Completed.
- A confirmed failure changes the payment to Failed.
- If no definitive result is available, the payment remains Unknown.

When a payment is confirmed as Failed, the held funds are released exactly once, and the corresponding financial records are updated.

Unknown payments must never be refunded automatically.

### 5.5 Agent Commission

Agent commission is calculated as **40% of the service fee** for agent-assisted payments that successfully reach the Completed state.

Commission must be recorded and credited exactly once. Failed, rejected, or unresolved payments must not generate a commission.

### 5.6 Notification Independence

Notification delivery is independent of the payment outcome.

A notification provider failure must not reverse or interrupt a successfully completed payment. Failed notification deliveries are handled through their own retry process.

SMS and email notifications support three additional delivery retries before being marked as Undelivered. Push notification retry behavior remains subject to the relevant requirements decision.

### 5.7 Reconciliation

The system supports daily reconciliation between PayLink payment records and available biller settlement evidence.

Reconciliation identifies discrepancies and can resolve Unknown payments when definitive settlement evidence is available.

The reconciliation process must maintain audit records and must not automatically change a payment outcome without sufficient evidence.

A settlement record that lists a PayLink `Failed` payment is a reconciliation difference for Support review; it does not itself add a state transition or reverse the recorded outcome.

The timezone for daily limits and reconciliation remains open (AQ-11). Behavior for payments already in flight when an account is blocked also remains open (AQ-10).

### 5.8 Throughput and Phase 2 evolution

The Student Brief's performance target is 100 payments per second for one minute against mock billers. The modular boundaries and isolated adapters support this target, but the design itself does not demonstrate the throughput; it must be measured during implementation.

For Phase 1, payment events are handled inside the application through the event publisher/observer boundary. In Phase 2, Notifications and Reconciliation are to evolve to an event-driven or service-based style, with an ADR recording options and trade-offs. Payment lifecycle and wallet consistency remain owned by the core application.

### 5.9 Authentication and Session Management

Authentication is implemented internally with Spring Security. PayLink stores account credentials separately from account business data in `account_credentials`, and persists stateful sessions in `login_sessions`. The selected password encoder is Spring Security's `PasswordEncoder` interface, injected through dependency injection and implemented by `Argon2PasswordEncoder` (Argon2id). Passwords are never stored in plaintext. No external authentication provider or JWT-only stateless session scheme is used.

`SessionManager` generates cryptographically secure random session tokens. It returns the raw token only to the authentication response/cookie path and stores only a secure token hash in the database. Protected requests must present a session that is both unexpired and unrevoked. Logout revokes the current session; logout from all devices revokes all active sessions for the account. Database-backed persistence is provided explicitly through `LoginSessionRepository`; Spring Security is not assumed to persist sessions in the relational database automatically.

#### Request Authentication Flow

```text
Client
  -> Authentication Filter (reads configured session cookie)
  -> SessionManager (hashes token and validates session)
  -> LoginSessionRepository (loads active session)
  -> reject if missing, expired, or revoked
  -> SecurityContext (set account identity and database-derived authorities)
  -> Protected API
```

Authorization is distinct from authentication: authentication verifies identity, while authorization decides what that identity may access. Role-based access control applies to Customer, Agent, Admin, and Support. Authorities come from the account record; client-supplied roles are never trusted.

The session cookie uses `HttpOnly`, `Secure`, and a `SameSite` setting appropriate to the client flow. CSRF protection is required for state-changing requests authenticated by this cookie. Passwords, raw session tokens, token hashes, and other sensitive authentication values must not be logged. Failed logins are counted and rate-limited using a documented policy; exact thresholds and lockout behavior remain open.

Session expiration duration, inactivity timeout, maximum concurrent sessions, lockout threshold and duration, password complexity, password-reset verification and expiry, the actual login identifier, and whether a password change revokes all sessions remain open for team/TA decision. On 2026-11-25 the user approved deferring identifier selection until provisioning is defined for all roles; this is not a team/TA approval and selects no key. No values or workflows are implied by this design.

`loginIdentifier` is a generic design placeholder only. The user approved keeping it unresolved (2026-11-25) until provisioning is defined for all roles. Rationale: the brief selects no credential key, and choosing one would invent a requirement. No phone number, email address, username, or other lookup key is selected; requirements, API contracts, and persistence must not assume one.

## 6. Architecture Decision Summary

| Decision | Selected Approach |
|---|---|
| Architecture Style | Modular Monolith |
| Architecture Pattern | Layered Architecture |
| Deployment | Single application |
| Internal Structure | Business modules |
| Communication | Defined module interfaces |
| Database | Relational database |
| Authentication | Internal Spring Security; database-backed stateful sessions; Argon2PasswordEncoder |
| Current implementation baseline | Java / Spring Boot with PostgreSQL (repository configuration) |
| External Integration | Isolated adapters |
| Financial Consistency | Transactions, idempotency, and ledger records |
| Payment Reliability | State management, retries, and reconciliation |

## 7. Expected Benefits

The selected architecture provides:

- Clear separation of business responsibilities.
- Easier maintenance and testing.
- Reliable handling of financial operations.
- Isolation of external biller integrations.
- Easier addition of new billers.
- Consistent payment lifecycle management.
- Better traceability of financial operations.
- A foundation that supports future system growth.
