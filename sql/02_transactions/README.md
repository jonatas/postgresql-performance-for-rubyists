# 🔄 Transaction Management - SQL Edition

This module explores ACID properties, isolation levels, and MVCC with executable SQL scripts.

## Prerequisites

```bash
# Connect to the workshop DB (Docker default port 5433)
psql -h 0.0.0.0 -p 5433 -U postgres -d workshop_db -c "SELECT version();"
```

## Running the scripts

```bash
# Transaction lab
psql -h 0.0.0.0 -p 5433 -U postgres -d workshop_db -f sql/02_transactions/transaction_lab.sql

# Exercises
psql -h 0.0.0.0 -p 5433 -U postgres -d workshop_db -f sql/02_transactions/exercises.sql
```

## What you'll learn

- Transaction boundaries (BEGIN/COMMIT/ROLLBACK)
- Isolation levels (Read Committed, Repeatable Read)
- Locking basics
- MVCC observation via row versions

## Tips

- You can run the lab multiple times; scripts are idempotent.
- For concurrency experiments, open two terminal windows with `psql`.


