# PostgreSQL Transactions Deep Dive

This module focuses on understanding PostgreSQL's transaction management, isolation levels, and common concurrency challenges like deadlocks. Through practical examples, you'll learn how PostgreSQL handles concurrent operations and how to design robust transaction strategies.

## Database Structure

```mermaid
erDiagram
    accounts {
        bigint id PK
        decimal balance
        string owner_name
        timestamp created_at
        timestamp updated_at
    }
```

## Module Overview

In this module, you'll explore:
1. How PostgreSQL manages transactions
2. Transaction isolation levels
3. Deadlock detection and prevention
4. Best practices for transaction management

## PostgreSQL Transaction Management

### 1. Basic Transaction Structure
Every PostgreSQL transaction follows this lifecycle:

```mermaid
graph TD
    A[BEGIN] --> B[Execute Statements]
    B --> C{Success?}
    C -->|Yes| D[COMMIT]
    C -->|No| E[ROLLBACK]
    D --> F[End]
    E --> F
```

### 2. Transaction Isolation Levels
PostgreSQL supports four isolation levels, each with different guarantees:

```mermaid
graph TB
    subgraph "Isolation Levels"
        direction TB
        RL[Read Uncommitted*] --> RC[Read Committed]
        RC --> RR[Repeatable Read]
        RR --> S[Serializable]
        
        style RL fill:#fdd,stroke:#333
        style RC fill:#dfd,stroke:#333
        style RR fill:#ddf,stroke:#333
        style S fill:#fdf,stroke:#333
    end

    note["* Behaves as Read Committed in PostgreSQL"]
    note --> RL
```

#### Isolation Level Characteristics

| Level | Dirty Read | Non-Repeatable Read | Phantom Read | Serialization Anomaly |
|-------|------------|---------------------|--------------|----------------------|
| Read Uncommitted* | Prevented | Possible | Possible | Possible |
| Read Committed | Prevented | Possible | Possible | Possible |
| Repeatable Read | Prevented | Prevented | Prevented** | Possible |
| Serializable | Prevented | Prevented | Prevented | Prevented |

\* PostgreSQL treats Read Uncommitted as Read Committed
\** PostgreSQL's implementation prevents phantom reads

#### Example Output from Our Deadlock Simulation:
```
Starting concurrent transfers (this should cause a deadlock)...
👱‍♀️ Alice initiating transfer...
👨 Bob initiating transfer...
Transferring 100 from Bob to Alice
Deadlock detected (attempt 1/3): PG::TRDeadlockDetected
DETAIL: Process 6338 waits for ShareLock on transaction 48693606; blocked by process 6339.
Process 6339 waits for ShareLock on transaction 48693605; blocked by process 6338.
```

#### Using Different Isolation Levels

```ruby
# Read Committed (default)
Account.transaction do
  # Default isolation level
  account.update!(balance: new_balance)
end

# Repeatable Read
Account.transaction(isolation: :repeatable_read) do
  # Prevents non-repeatable reads
  balance = account.balance
  sleep(1) # Simulate work
  # Will see same balance even if another transaction changed it
  account.update!(balance: balance + 100)
end

# Serializable
Account.transaction(isolation: :serializable) do
  # Strongest isolation - prevents all concurrency anomalies
  # May throw SerializationFailure - application must retry
  balance = account.balance
  account.update!(balance: balance + 100)
end
```

### Common Concurrency Phenomena

1. **Dirty Read** (prevented in PostgreSQL)
   - Transaction reads data written by concurrent uncommitted transaction

2. **Non-Repeatable Read** (possible in Read Committed)
   ```ruby
   # Transaction 1           # Transaction 2
   read(A)  # value = 100
                           update(A) to 200
                           commit
   read(A)  # value = 200   
   # Different result!
   ```

3. **Phantom Read** (possible in Read Committed)
   ```ruby
   # Transaction 1           # Transaction 2
   count(*) # returns 10
                           insert new row
                           commit
   count(*) # returns 11
   # Different result!
   ```

4. **Serialization Anomaly** (possible in all except Serializable)
   ```ruby
   # Transaction 1           # Transaction 2
   sum = total_balance()    sum = total_balance()
   insert(-100)            insert(-100)
   commit                  commit
   # Both transactions saw the same sum but both subtracted,
   # potentially leading to negative balance
   ```

### 3. Deadlock Scenario
Our `transaction_lab.rb` demonstrates a classic deadlock:

```mermaid
sequenceDiagram
    participant T1 as Transaction 1
    participant A1 as Account 1
    participant A2 as Account 2
    participant T2 as Transaction 2

    T1->>A1: Lock Account 1
    T2->>A2: Lock Account 2
    T1--xA2: Try to Lock Account 2 (Blocked)
    T2--xA1: Try to Lock Account 1 (Blocked)
    Note over T1,T2: Deadlock Detected!
    T2-->>T2: Transaction Aborted
    T1->>A2: Lock Acquired
    T1->>T1: Transaction Completes
```

## Key Concepts

### 1. Transaction Properties (ACID)
- **Atomicity**: All or nothing execution
- **Consistency**: Database remains valid after transaction
- **Isolation**: Transactions don't interfere with each other
- **Durability**: Committed changes are permanent

### 2. Lock Types
PostgreSQL uses various lock types:
```
- Row-Level Locks
  - FOR UPDATE
  - FOR NO KEY UPDATE
  - FOR SHARE
  - FOR KEY SHARE
  
- Table-Level Locks
  - ACCESS SHARE
  - ROW SHARE
  - ROW EXCLUSIVE
  - SHARE UPDATE EXCLUSIVE
  - SHARE
  - SHARE ROW EXCLUSIVE
  - EXCLUSIVE
  - ACCESS EXCLUSIVE
```

### 3. Deadlock Detection
PostgreSQL automatically detects deadlocks:
1. Monitors wait-for graph
2. Identifies cycles (deadlocks)
3. Chooses a victim transaction
4. Rolls back the victim

## Key Learnings from Deadlock Simulation

### 1. Connection Pool Management
- Each thread needs its own database connection in multi-threaded scenarios
- Use `ActiveRecord::Base.connection_pool.with_connection` to ensure proper connection handling
- Connections are automatically returned to the pool after the block completes

### 2. Transaction Rollback Behavior
- Deadlocks cause automatic transaction rollback
- Both transactions involved in a deadlock may be affected
- Need to explicitly reload records after deadlock to get current state
- Always verify final state after transaction completion

### 3. Lock Ordering
- Inconsistent lock ordering is a primary cause of deadlocks
- To prevent deadlocks, always acquire locks in a consistent order
- Example: Always lock records in ascending ID order
- Use `Account.lock.where(id: [id1, id2]).order(:id)` pattern

### 4. Multi-threaded Transaction Patterns
- Reset initial state before running concurrent transactions
- Use explicit transaction blocks
- Handle both specific (Deadlocked) and generic exceptions
- Verify final state through explicit reload

## Practical Exercises - Transaction Management

1. **Basic Transaction Handling**
   ```ruby
   Account.transaction do
     # Operations here are atomic
     account.update!(balance: account.balance + 100)
   end
   ```

2. **Deadlock Simulation**
   ```ruby
   # See transaction_lab.rb for implementation
   TransactionLab.simulate_deadlock
   ```

3. **Isolation Level Testing**
   ```ruby
   Account.transaction(isolation: :serializable) do
     # Operations here run in serializable isolation
   end
   ```

## Learning Objectives Checklist

After completing this module, you should understand:
- [ ] Basic transaction management in PostgreSQL
- [ ] Different isolation levels and their implications
- [ ] How deadlocks occur and how to prevent them
- [ ] Best practices for handling concurrent transactions
- [ ] Lock types and their use cases

## Files in this Module

1. `transaction_lab.rb`: Hands-on exercises with transaction concepts
2. `README.md`: This documentation file

## Additional Resources

- [PostgreSQL Documentation: Transaction Management](https://www.postgresql.org/docs/current/transaction-iso.html)
- [PostgreSQL Documentation: Concurrency Control](https://www.postgresql.org/docs/current/mvcc.html)
- [PostgreSQL Documentation: Lock Management](https://www.postgresql.org/docs/current/explicit-locking.html)

## Key Observations

1. PostgreSQL's MVCC (Multi-Version Concurrency Control) allows for high concurrency
2. Deadlocks are automatically detected and resolved
3. Proper transaction isolation level selection is crucial for application correctness
4. Lock management requires careful consideration to avoid performance issues
5. Transaction scope should be as narrow as possible while maintaining consistency 