# PayLink – Design Patterns

## 1. Introduction

PayLink uses design patterns to organize its business logic, reduce dependencies, and support future changes.

The selected patterns address important system requirements such as biller integration, fee calculation, payment lifecycle management, fraud detection, notifications, and retry handling.

## 2. Selected Design Patterns

### 2.1 Adapter Pattern

**Used In:** Biller Integration Module

**Purpose:**

The Adapter Pattern allows PayLink to communicate with different billers through a common internal interface, even when each biller uses a different communication protocol or data format.

**Application in PayLink:**

Each biller has its own adapter:

- ElectroCoAdapter communicates using REST and JSON.
- AquaCoAdapter communicates using SOAP-style XML over HTTP.
- TopUpNetAdapter communicates using REST and JSON and supports asynchronous callbacks.

Each adapter converts PayLink requests into the format expected by the selected biller and converts external responses into a common internal format.

The adapter also helps isolate biller-specific response formats and error codes from the core payment processing logic.

**Benefit:**

New billers can be integrated without changing the core payment processing logic.

### 2.2 Factory Pattern

**Used In:** Biller Integration Module

**Purpose:**

The Factory Pattern centralizes the creation or selection of the appropriate biller adapter.

**Application in PayLink:**

When a payment or inquiry identifies a biller, the factory selects the corresponding adapter, such as ElectroCoAdapter, AquaCoAdapter, or TopUpNetAdapter.

**Benefit:**

Adapter selection is centralized, avoiding repeated selection logic throughout the application.

### 2.3 Strategy Pattern

**Used In:** Fees and Commissions Module

**Purpose:**

The Strategy Pattern allows different fee and commission calculation rules to be applied according to the payment type and business rules.

**Application in PayLink:**

PayLink uses different fee calculation strategies:

- Electricity and Water: Fixed fee of 2.50 EGP.
- Mobile Top-Up: 1.5% of the payment amount, with a minimum fee of 1 EGP.
- Internet: 2 EGP for payments up to and including 200 EGP and 4 EGP for payments above 200 EGP.
- Promotions may reduce the service fee to zero for eligible billers and time periods.

Each calculation rule can be represented by a separate fee strategy.

Agent commission is calculated separately using the commission rule:

- Agent commission is 40% of the service fee.
- Commission applies only to agent-assisted payments that reach the Completed state.
- Commission must be recorded and credited exactly once per eligible payment.

**Benefit:**

Fee and commission rules can be changed or extended without placing all calculation logic inside one large conditional structure.

### 2.4 State Pattern

**Used In:** Payment Processing Module

**Purpose:**

The State Pattern manages payment behavior according to its current lifecycle state and controls which transitions are allowed.

**Application in PayLink:**

A payment can have one of the following official states:

- Initiated
- FundsHeld
- SentToBiller
- Completed
- Rejected
- Failed
- Unknown
- Refunded

The payment lifecycle defines the permitted transitions:

- Initiated can move to FundsHeld or Rejected.
- FundsHeld can move to SentToBiller.
- SentToBiller can move to Completed, Failed, or Unknown.
- Unknown can later move to Completed or Failed after a definitive result.
- Failed can move to Refunded when the held funds are released.

Completed, Rejected, and Refunded are terminal states in the defined payment lifecycle.

**Important Distinction:**

The Failed-to-Refunded transition represents releasing funds previously held for a failed payment.

An optional refund of an already Completed payment is a separate refund workflow that requires support approval. It must not be confused with the automatic release of held funds after a confirmed failure.

**Benefit:**

Payment transitions remain controlled, and invalid state changes can be prevented.

### 2.5 Chain of Responsibility Pattern

**Used In:** Fraud Checks Module

**Purpose:**

The Chain of Responsibility Pattern allows a payment request to pass through a sequence of independent validation and fraud checks.

**Application in PayLink:**

A payment request may pass through checks such as:

- Account status validation.
- Single-payment limit validation.
- Daily payment limit validation.
- Payment velocity checks.
- Suspicious activity checks.

Each check evaluates the request and either allows processing to continue or rejects it according to the applicable rules.

The velocity rule blocks new payment attempts for 10 minutes when more than 5 payment attempts occur within a rolling 60-second window.

**Benefit:**

Fraud checks can be added, removed, or reordered without placing all validation logic inside one component.

### 2.6 Observer Pattern

**Used In:** Notifications Module

**Purpose:**

The Observer Pattern allows interested components to be notified when an important payment event occurs.

**Application in PayLink:**

Payment events such as successful completion, confirmed failure, or refund can generate notification events.

The Notifications Module receives the relevant event and sends the appropriate message through the configured notification provider.

Notification delivery is handled independently from the payment result.

If a notification provider is unavailable, the payment outcome remains unchanged. Notification delivery is retried independently.

SMS and email notifications support three additional delivery retries before being marked as Undelivered.

**Benefit:**

Payment processing does not need to depend directly on notification delivery. Notification failures can be retried without changing the payment outcome.

### 2.7 Command Pattern

**Used In:** Payment Retry Handling

**Purpose:**

The Command Pattern encapsulates an operation as a separate command that can be scheduled and executed independently.

**Application in PayLink:**

When a payment enters the Unknown state, PayLink schedules biller status inquiry commands to check the final payment outcome.

The inquiry schedule is:

- First inquiry: 1 minute after entering Unknown.
- Second inquiry: 5 minutes after entering Unknown.
- Third inquiry: 15 minutes after entering Unknown.

Each command checks the existing payment outcome. It must not create a new payment, repeat the original payment request, or cause another wallet deduction.

If all three inquiries finish without a definitive result, the payment remains Unknown and its funds stay held until definitive evidence becomes available through a later callback or reconciliation.

**Benefit:**

Retry operations are separated from the original payment workflow, allowing controlled scheduling and reducing the risk of duplicate financial transactions.

## 3. Design Pattern Summary

| Design Pattern | PayLink Module | Main Purpose |
|---|---|---|
| Adapter | Biller Integration | Unify different biller protocols |
| Factory | Biller Integration | Select the appropriate biller adapter |
| Strategy | Fees and Commissions | Support different fee and commission calculation rules |
| State | Payment Processing | Control payment lifecycle transitions |
| Chain of Responsibility | Fraud Checks | Organize sequential fraud validation |
| Observer | Notifications | React to payment events |
| Command | Payment Retry Handling | Encapsulate scheduled status inquiries |

## 4. Design Considerations

- Each pattern is applied to a specific responsibility.
- Patterns should simplify the design rather than introduce unnecessary complexity.
- Payment state transitions must follow the approved payment lifecycle.
- External biller communication must remain isolated from core payment logic.
- Notification and retry operations must not cause duplicate financial transactions.
- Wallet operations must preserve financial consistency and idempotency.
- Retry commands must check existing payment outcomes instead of resubmitting payment requests.
- Commission must only be generated for eligible completed agent-assisted payments and must be processed exactly once.
- All financial operations must be recorded accurately in the ledger and audit trail.
- Duplicate callbacks must not cause repeated payment completion or duplicate financial movements.

## 5. Conclusion

The selected design patterns provide a structured approach to handling PayLink's main business requirements.

They support extensible biller integration, flexible fee and commission calculation, controlled payment lifecycle transitions, organized fraud checks, independent notifications, and reliable retry handling.