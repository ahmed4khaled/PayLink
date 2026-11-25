# PayLink – System Modules

## 1. Introduction

PayLink is organized into business modules within a Modular Monolith architecture.

Each module is responsible for a specific part of the system. This separation keeps business logic organized, reduces unnecessary dependencies, and makes the system easier to maintain and extend.

All modules operate within one application and communicate through clearly defined interfaces and application services.

## 2. Core Business Modules

### 2.1 Accounts and Wallet Module

**Responsibility:**

Manages customer accounts, verification levels, wallet balances, and wallet-related operations.

**Main Functions:**

- Own account business information, account status, role, and verification level.
- Create and manage customer accounts.
- Manage customer verification levels.
- Provide account identity and status information to Authentication through its defined interface; credential and session records remain outside this module.
- Maintain available and held wallet balances.
- Handle simulated card wallet top-ups.
- Handle agent cash wallet top-ups.
- Hold funds before biller payment processing.
- Hold the full customer total (bill amount plus fee); Sara's brief example holds 352.50 EGP for a 350.00 EGP electricity bill.
- Capture held funds after confirmed payment success.
- Release held funds after confirmed payment failure.
- On definitive failure, record `Failed`; when the held funds are released, atomically record the ledger movement and transition `Failed` → `Refunded`.
- Do not assume a credit method for optional FR-27 completed-payment refunds. The user approved deferring implementation and method selection until team/TA resolution of AQ-07/AQ-12 (2026-11-25); this is not team/TA approval.
- Maintain wallet transaction records and financial ledger entries.
- Ensure wallet operations do not create negative balances.
- Ensure fund holding, capturing, and releasing operations are atomic and idempotent.
- Reserve funds atomically against the ledger-derived available balance so concurrent payments cannot spend the same funds; insufficient funds reject the payment.
- Prevent duplicate financial movements.

### 2.2 Authentication Module

**Responsibility:**

Implements internal authentication and the lifecycle of database-backed login sessions. It owns credential verification and session revocation, while Accounts and Wallet remains the source of account identity, status, role, and verification information.

**Main Functions:**

- Authenticate account credentials through Spring Security's injected `PasswordEncoder` interface, configured with `Argon2PasswordEncoder` (Argon2id).
- Own `account_credentials` and `login_sessions`; store password hashes and session-token hashes only.
- Track failed logins and apply the configured rate-limit and lockout policy; policy values remain open for team/TA approval.
- Create sessions using cryptographically secure random tokens and persist only their secure hashes.
- Validate cookie tokens against persisted sessions and reject expired or revoked sessions.
- Revoke the current session on logout and all active account sessions on logout from all devices.
- Provide authentication to protected requests and establish account identity and authorities for authorization.
- Initiate password changes and reset workflows without assuming unspecified verification or expiry rules.

**Ownership Boundary:**

Authentication may depend on Accounts for account identity and status, but it does not own wallet, ledger, payment, or biller operations. Accounts does not store credentials or session records. No roles table is added; the account's role remains part of the account record.

The exact login identifier remains unspecified. The user approved deferring its selection on 2026-11-25 until account provisioning is defined for Customer, Agent, Admin, and Support. Rationale: the brief selects no credential key, and choosing one would invent a requirement. This records user approval, not team/TA approval; the design does not assume phone, email, username, or another key.

### 2.3 Biller Catalog Module

**Responsibility:**

Manages the available billers, their services, and the information required to perform bill inquiries and payments.

**Main Functions:**

- Store biller information.
- Manage available biller services.
- Manage required customer input fields.
- Provide biller and service details.
- Manage biller activation and availability.
- Allow authorized administrators to add, edit, and disable billers and services.
- Provide the information required before a payment is initiated.

### 2.4 Payment Processing Module

**Responsibility:**

Controls the payment lifecycle from initiation until the final outcome.

**Main Functions:**

- Create payment requests.
- Validate payment details.
- Enforce payment idempotency.
- Coordinate fraud checks before funds are held.
- Coordinate wallet fund holds and captures.
- Calculate and apply the appropriate payment workflow.
- Send payment requests through the appropriate biller integration.
- Track payment status and valid state transitions.
- Process successful, rejected, failed, and unknown payment outcomes.
- Handle asynchronous biller callbacks.
- Ignore duplicate callbacks without repeating financial operations.
- Coordinate failed-payment fund releases.
- Coordinate optional FR-27 completed-payment refund requests only after the team/TA resolves the deferred method and policy (AQ-07/AQ-12); do not assume a `Completed` → `Refunded` payment-state transition. The user approved deferral on 2026-11-25; this is not team/TA approval.
- Prevent duplicate payment processing and duplicate financial movements.
- Coordinate status inquiries for unresolved payments.

When a payment enters Unknown, the user-approved AQ-15 interpretation (2026-11-25) schedules status inquiries at 1, 5, and 15 minutes after that entry. Rationale: deterministic retry times from the start of the unresolved state. Section 2.6 specifies the offsets but not their anchor. This records user approval, not team/TA approval. If no definitive outcome is available after these attempts, the payment remains Unknown with its funds held until reconciliation or later evidence resolves it.

### 2.5 Biller Integration Module

**Responsibility:**

Handles communication between PayLink and external biller systems.

**Main Functions:**

- Send bill inquiry and payment requests to external billers.
- Support different biller communication protocols.
- Convert PayLink requests into biller-specific formats.
- Convert external biller responses into a common internal format.
- Process asynchronous biller callbacks.
- Callback authentication details remain open (AQ-09); no authentication scheme is assumed.
- Handle communication timeouts and integration errors.
- Support biller status inquiries for unresolved payments.
- Isolate failures between different biller integrations.
- Support callback duplicate detection and appropriate logging.

**Supported Integrations:**

- ElectroCo: REST API using JSON; inquiry uses the meter number, response is under one second, and payment is confirmed immediately.
- AquaCo: SOAP-style XML over HTTP; responds in 2–4 seconds, uses different field names and error codes, and refuses payments above the bill amount.
- TopUpNet: REST API using JSON; may return `accepted` first and sends a later asynchronous `success` or `failed` callback.
- NetCo: Optional daily CSV batch; Payments file uploaded once per day, Result File returned next morning, and no live inquiry.

Each biller integration is isolated so that adding a new biller does not require changing the core payment processing logic.

The Phase 2 ElectroCo v2 change (new field names, piaster amounts, signed requests) is confined to `ElectroCoAdapter` and its configuration. TopUpNet's initial `accepted` response is pending, not final: the payment remains `SentToBiller` until its definitive callback. A duplicate callback is logged and ignored without repeating a financial operation. A failed settlement comparison, including a settlement record for a PayLink `Failed` payment, is flagged for Support review rather than changing payment state.

### 2.6 Fees and Commissions Module

**Responsibility:**

Calculates service fees and agent commissions according to configured business rules.

**Main Functions:**

- Calculate fees based on biller and service type.
- Apply fixed fee rules.
- Apply percentage-based fee rules.
- Apply tiered fee rules.
- Apply minimum fee conditions where required.
- Apply promotional fee reductions.
- Calculate agent commissions for eligible completed payments.
- Return calculated fee details to the payment process.
- Ensure commission is recorded and credited exactly once.

**Commission Rule:**

Agent commission is 40% of the service fee and applies only to agent-assisted payments that reach the Completed state.

### 2.7 Notifications Module

**Responsibility:**

Manages payment-related notifications to customers and other relevant users.

**Main Functions:**

- Send payment completion notifications.
- Notify customers when a payment reaches `Failed`, as required by FR-22.
- Rejected-payment and refund-related notifications are optional proposals, not mandatory requirements; obtain team approval before treating them as required outcomes.
- Support SMS and push notification delivery.
- Support email notification delivery where required.
- Retry failed notification deliveries according to the configured rules.
- Track notification delivery status.
- Mark notifications as Undelivered after the allowed retry attempts.

SMS and email notifications support three additional delivery retries. Notification failures must not change the payment result or interrupt payment processing.

## 3. Supporting Modules

### 3.1 Fraud Checks Module

**Responsibility:**

Evaluates payment requests against fraud prevention and payment restriction rules before funds are held.

**Main Functions:**

- Check account status.
- Validate single-payment limits.
- Validate daily payment limits.
- Check payment frequency and velocity.
- Detect suspicious payment activity.
- Apply configured fraud prevention rules.
- Return an approval or rejection decision to the payment process.

**Velocity Rule:**

The brief sets the threshold at more than 5 payments from one account within 60 seconds and blocks new payment attempts for 10 minutes. **User-approved AQ-14 interpretation (2026-11-25):** count payment initiation attempts, including attempts later rejected. Rationale: detect rapid repeated activity before it can evade the rule through rejected outcomes. This records the user's approval and does not claim team/TA approval. Whether daily limits include service fees or rejected attempts remains open.

The wallet module remains responsible for enforcing available balance and preventing negative balances.

### 3.2 Reconciliation Module

**Responsibility:**

Compares PayLink payment records with biller settlement information to identify discrepancies.

**Main Functions:**

- Receive and process biller settlement information.
- Process optional NetCo daily CSV files.
- Compare internal payment records with biller settlement records.
- Identify missing or mismatched transactions.
- Identify payments that remain in Unknown status.
- Use definitive settlement evidence to support payment outcome resolution.
- Generate daily reconciliation reports.
- Flag discrepancies for investigation.
- If a settlement file lists a PayLink `Failed` payment, record a difference for Support review; do not create an unlisted payment-state transition.
- Maintain reconciliation processing records and audit information.

### 3.3 Audit, Configuration and Statistics Module

**Responsibility:**

Maintains administrative configuration, records important system activities, and provides daily operational statistics.

**Main Functions:**

- Manage configurable service fee values.
- Manage configurable payment limits.
- Record administrative configuration changes.
- Record important administrative actions.
- Maintain audit records for financial and operational activities.
- Support traceability of money movements by recording who performed an action, when it occurred, and why.
- Generate daily payment statistics.
- Calculate daily payment totals, fee totals, commission totals, and failure totals.
- Provide daily statistics to authorized administrators.

### 3.4 Support Operations Module

**Responsibility:**

Provides authorized support employees with tools to investigate payment issues and manage customer support operations.

**Main Functions:**

- Search for payments using payment references.
- View complete payment history.
- Review relevant transaction and status information.
- Block and unblock customer accounts.
- Whether an account block affects payments already in progress remains open (AQ-10).
- Review completed-payment refund requests.
- Proposed AQ-12 workflow, user-approved 2026-11-25 pending team/TA confirmation: one authorized Support-role user approves or rejects; record actor, timestamp, outcome, reason, payment/refund identifiers and resulting ledger movement. No dual control is proposed.
- Record support actions in the audit trail.
- Ensure support operations follow role-based authorization rules.

## 4. Module Interaction

The modules cooperate to complete the main PayLink payment workflow.

1. The Payment Processing Module receives a payment request.
2. The Accounts and Wallet Module provides account and wallet information.
3. The Fees and Commissions Module calculates the applicable service fee.
4. The Fraud Checks Module evaluates the payment request.
5. The Accounts and Wallet Module holds the required funds after approval.
6. The Biller Integration Module communicates with the selected biller.
7. The Payment Processing Module updates the payment status based on the biller response.
8. The Accounts and Wallet Module captures held funds after confirmed success. On confirmed failure, Payment Processing records `Failed`; the Wallet module releases the hold exactly once and records the lifecycle transition to `Refunded` with the release ledger movement.
9. The Fees and Commissions Module calculates the eligible agent commission when applicable.
10. The Notifications Module sends the appropriate payment notification.
11. The Audit, Configuration and Statistics Module records relevant financial and administrative activities.
12. The Reconciliation Module compares payment records with settlement information and helps resolve unresolved payment outcomes.
13. The Support Operations Module provides authorized investigation and refund approval capabilities.

### Authentication Interactions

- A login request is verified by Authentication against account and credential data; successful authentication creates a persisted login session.
- For protected requests, the Authentication Filter passes the configured cookie token to SessionManager, which validates it through LoginSessionRepository before populating SecurityContext.
- Authentication obtains account identity, status, and role from Accounts; it does not accept client-supplied authorities.
- Credential and session persistence belongs to Authentication. Wallet, payment, biller, and ledger responsibilities remain in their existing modules.

## 5. Module Dependency Rules

To maintain separation between modules, the following rules apply:

- Each module owns its business responsibilities.
- Authentication owns credentials and login sessions; Accounts owns account business data, status, role, and verification.
- Modules communicate through defined interfaces and application services.
- A module should not directly modify another module's internal data.
- Payment Processing coordinates the payment workflow but does not implement external biller protocols.
- Biller-specific communication details remain inside Biller Integration.
- Fee calculation and commission rules remain inside Fees and Commissions.
- Fraud decisions are handled by Fraud Checks.
- Wallet balance changes are handled by Accounts and Wallet.
- Notification delivery is independent of the payment result.
- Reconciliation uses payment and settlement records to identify discrepancies.
- Support Operations handles authorized investigation and refund approval.
- Audit records must be maintained for relevant financial and administrative operations.
- Daily statistics must be available only to authorized administrators.

## 6. Module Summary

| Module | Main Responsibility |
|---|---|
| Accounts and Wallet | Accounts, verification, balances, and wallet transactions |
| Authentication | Credential verification and database-backed session lifecycle |
| Biller Catalog | Biller and service information |
| Payment Processing | Payment workflow and lifecycle |
| Biller Integration | External biller communication |
| Fees and Commissions | Service fees and agent commissions |
| Notifications | Payment-related messages |
| Fraud Checks | Fraud prevention and payment limits |
| Reconciliation | Settlement comparison and discrepancy reporting |
| Audit, Configuration and Statistics | Configuration, audit records, and daily statistics |
| Support Operations | Payment investigation, account blocking, and refund approval |

## 7. Conclusion

The selected modules provide a clear separation of PayLink's business responsibilities.

They support reliable payment processing, secure wallet operations, extensible biller integration, flexible fee calculation, fraud prevention, independent notifications, reconciliation, administrative monitoring, and customer support operations.

The Modular Monolith structure keeps these responsibilities organized within one application while allowing each module to evolve independently.
