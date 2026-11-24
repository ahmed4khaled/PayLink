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

When a payment enters the Unknown state:

- Its funds remain held.
- The system schedules status inquiries at 1, 5, and 15 minutes after entering Unknown.
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

All monetary calculations use exact decimal values rather than floating-point arithmetic.

The amount included in a fund hold must follow the final decision for AQ-13.

### 5.3 Biller Integration

Each biller integration is isolated behind a common internal interface.

The required mock billers are:

- ElectroCo: REST API using JSON.
- AquaCo: SOAP-style XML over HTTP.
- TopUpNet: REST API using JSON with asynchronous callbacks.

NetCo is an optional integration that uses daily CSV settlement processing.

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

## 6. Architecture Decision Summary

| Decision | Selected Approach |
|---|---|
| Architecture Style | Modular Monolith |
| Architecture Pattern | Layered Architecture |
| Deployment | Single application |
| Internal Structure | Business modules |
| Communication | Defined module interfaces |
| Database | Relational database |
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