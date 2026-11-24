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

- Create and manage customer accounts.
- Manage customer verification levels.
- Maintain available and held wallet balances.
- Handle simulated card wallet top-ups.
- Handle agent cash wallet top-ups.
- Hold funds before biller payment processing.
- Capture held funds after confirmed payment success.
- Release held funds after confirmed payment failure.
- Maintain wallet transaction records and financial ledger entries.
- Ensure wallet operations do not create negative balances.
- Ensure fund holding, capturing, and releasing operations are atomic and idempotent.
- Prevent duplicate financial movements.

### 2.2 Biller Catalog Module

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

### 2.3 Payment Processing Module

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
- Coordinate completed-payment refund requests.
- Prevent duplicate payment processing and duplicate financial movements.
- Coordinate status inquiries for unresolved payments.

When a payment enters Unknown, status inquiries are scheduled at 1, 5, and 15 minutes after entering that state. If no definitive outcome is available after these attempts, the payment remains Unknown with its funds held until reconciliation or later evidence resolves it.

### 2.4 Biller Integration Module

**Responsibility:**

Handles communication between PayLink and external biller systems.

**Main Functions:**

- Send bill inquiry and payment requests to external billers.
- Support different biller communication protocols.
- Convert PayLink requests into biller-specific formats.
- Convert external biller responses into a common internal format.
- Process asynchronous biller callbacks.
- Handle communication timeouts and integration errors.
- Support biller status inquiries for unresolved payments.
- Isolate failures between different biller integrations.
- Support callback duplicate detection and appropriate logging.

**Supported Integrations:**

- ElectroCo: REST API using JSON.
- AquaCo: SOAP-style XML over HTTP.
- TopUpNet: REST API using JSON with asynchronous callbacks.
- NetCo: Optional daily CSV settlement integration.

Each biller integration is isolated so that adding a new biller does not require changing the core payment processing logic.

### 2.5 Fees and Commissions Module

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

### 2.6 Notifications Module

**Responsibility:**

Manages payment-related notifications to customers and other relevant users.

**Main Functions:**

- Send payment completion notifications.
- Notify customers about failed or rejected payments.
- Send refund-related notifications.
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

More than 5 payment attempts within a rolling 60-second window causes new payment attempts to be blocked for 10 minutes.

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
- Review completed-payment refund requests.
- Approve or reject refund requests according to the authorized workflow.
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
8. The Accounts and Wallet Module captures the held funds after confirmed success or releases them after confirmed failure.
9. The Fees and Commissions Module calculates the eligible agent commission when applicable.
10. The Notifications Module sends the appropriate payment notification.
11. The Audit, Configuration and Statistics Module records relevant financial and administrative activities.
12. The Reconciliation Module compares payment records with settlement information and helps resolve unresolved payment outcomes.
13. The Support Operations Module provides authorized investigation and refund approval capabilities.

## 5. Module Dependency Rules

To maintain separation between modules, the following rules apply:

- Each module owns its business responsibilities.
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