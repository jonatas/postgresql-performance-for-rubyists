# PostgreSQL Storage Deep Dive

This module focuses on understanding PostgreSQL's physical storage mechanisms and how different data types and sizes affect storage organization. Through practical examples, you'll learn how PostgreSQL organizes data at the lowest level and how this impacts database performance and storage efficiency.

## Database Structure

```mermaid
erDiagram
    employees {
        bigint id PK
        varchar name
        integer employee_id
        boolean active
        date hire_date
        decimal salary
        jsonb details
        binary photo
        timestamp created_at
        timestamp updated_at
    }
```

## Module Overview

In this module, you'll explore:
1. How PostgreSQL organizes data in tuples (rows)
2. How different data types affect storage and alignment
3. How PostgreSQL handles large values using TOAST
4. The relationship between theoretical and actual storage sizes

## PostgreSQL Storage Layout

### 1. Basic Page Structure (8KB)

```mermaid
graph TD
    subgraph "PostgreSQL Page Layout"
        direction TB
        PH[Page Header<br/>24 bytes] --> IP[Item Pointers<br/>4 bytes per item]
        IP --> FS[Free Space<br/>Variable Size]
        FS --> TD[Tuple Storage]
        TD --> SA[Special Area<br/>Index-specific data]
    end

    style PH fill:#f9f,stroke:#333,stroke-width:2px
    style IP fill:#bbf,stroke:#333,stroke-width:2px
    style FS fill:#bfb,stroke:#333,stroke-width:2px
    style TD fill:#fbf,stroke:#333,stroke-width:2px
    style SA fill:#fbb,stroke:#333,stroke-width:2px
```

### 2. Tuple Structure

```mermaid
graph LR
    subgraph "Single Tuple Layout"
        TH[Tuple Header<br/>23 bytes] --> NB[Null Bitmap<br/>2 bytes for 9-16 cols]
        NB --> DF[Data Fields]
        DF --> AP[Alignment Padding]
    end

    style TH fill:#ddf,stroke:#333,stroke-width:2px
    style NB fill:#ffd,stroke:#333,stroke-width:2px
    style DF fill:#fbf,stroke:#333,stroke-width:2px
    style AP fill:#ddd,stroke:#333,stroke-width:2px
```

### 3. Data Field Types and Sizes

```mermaid
graph TD
    subgraph "Fixed-Length Types"
        direction LR
        F1[bigint<br/>8 bytes] --- F2[integer<br/>4 bytes]
        F2 --- F3[boolean<br/>1 byte]
        F3 --- F4[date<br/>4 bytes]
        F4 --- F5[decimal<br/>8 bytes]
        F5 --- F6[timestamp<br/>8 bytes]
    end

    subgraph "Variable-Length Types"
        direction LR
        V1[varchar<br/>variable + metadata] --- V2[jsonb<br/>variable + metadata]
        V2 --- V3[binary<br/>variable + metadata]
    end

    style F1 fill:#bbf,stroke:#333,stroke-width:2px
    style F2 fill:#bbf,stroke:#333,stroke-width:2px
    style F3 fill:#bbf,stroke:#333,stroke-width:2px
    style F4 fill:#bbf,stroke:#333,stroke-width:2px
    style F5 fill:#bbf,stroke:#333,stroke-width:2px
    style F6 fill:#bbf,stroke:#333,stroke-width:2px
    style V1 fill:#fbf,stroke:#333,stroke-width:2px
    style V2 fill:#fbf,stroke:#333,stroke-width:2px
    style V3 fill:#fbf,stroke:#333,stroke-width:2px
```

### 4. TOAST Storage System

```mermaid
graph LR
    subgraph "TOAST Handling"
        T1[Table Row] --> C{Size > 2KB?}
        C -->|No| I[Store Inline]
        C -->|Yes| TP[TOAST Pointer<br/>18 bytes]
        TP --> ET[(External<br/>TOAST Table)]
    end

    style T1 fill:#ddf,stroke:#333,stroke-width:2px
    style C fill:#ffd,stroke:#333,stroke-width:2px
    style I fill:#bfb,stroke:#333,stroke-width:2px
    style TP fill:#fdb,stroke:#333,stroke-width:2px
    style ET fill:#bdf,stroke:#333,stroke-width:2px
```

### Storage Size Examples

Here are real-world examples of how different tuple types consume space:

```mermaid
graph LR
    subgraph "Tuple Size Examples"
        direction TB
        MT[Minimal Tuple<br/>mostly NULLs<br/>54 bytes] --- TT[Typical Tuple<br/>mixed types<br/>123 bytes]
        TT --- DT[Detailed Tuple<br/>large fields<br/>2434 bytes]
        DT --- CT[Compact Tuple<br/>small fields<br/>85 bytes]
        CT --- VT[Mixed Tuple<br/>varied sizes<br/>844 bytes]
    end

    style MT fill:#bfb,stroke:#333,stroke-width:2px
    style TT fill:#fbf,stroke:#333,stroke-width:2px
    style DT fill:#fdb,stroke:#333,stroke-width:2px
    style CT fill:#bbf,stroke:#333,stroke-width:2px
    style VT fill:#ffd,stroke:#333,stroke-width:2px
```

### Key Points About Storage

1. **Page Layout**:
   - Fixed 8KB size
   - Contains header, pointers, and tuple data
   - Special area for index-specific information

2. **Tuple Structure**:
   - Fixed header (23 bytes)
   - Null bitmap size depends on column count
   - Data fields with alignment requirements
   - Padding ensures proper alignment

3. **Data Types Impact**:
   - Fixed-length types have predictable sizes
   - Variable-length types need extra metadata
   - NULL values only use 1 bit in null bitmap
   - Large values use TOAST storage

4. **TOAST System**:
   - Handles values larger than 2KB
   - Uses pointer in main tuple (18 bytes)
   - Supports compression
   - External storage in separate table

## Part 1: Understanding Tuples and Page Layout

In PostgreSQL, each row in a table is called a "tuple". These tuples are stored in fixed-size pages (blocks) of 8KB by default. Understanding tuple structure is crucial for:
- Optimizing table design
- Understanding storage overhead
- Managing data alignment
- Predicting storage requirements

### Tuple Structure

A tuple contains:
- Header data (23 bytes)
- Null bitmap (variable size)
- User data (actual column values)
- Alignment padding

Here's a representation of a PostgreSQL page layout:

```mermaid
graph TD
    subgraph "PostgreSQL Page (8KB)"
        direction TB
        PH[Page Header<br/>24 bytes] --> IP[Item Pointers<br/>4 bytes per item]
        IP --> |points to| TD[Tuple Data]
        
        subgraph "Free Space"
            FS[Variable Size<br/>Available for new tuples]
        end
        
        subgraph "Tuple Storage Area"
            TD --> T1[Tuple 1]
            
            subgraph "Tuple Structure"
                TH[Tuple Header<br/>23 bytes]
                NB[Null Bitmap<br/>2 bytes for 9-16 cols]
                
                subgraph "Data Fields"
                    direction TB
                    F1[id: bigint<br/>8 bytes]
                    F2[name: varchar<br/>variable + metadata]
                    F3[employee_id: integer<br/>4 bytes]
                    F4[active: boolean<br/>1 byte]
                    F5[hire_date: date<br/>4 bytes]
                    F6[salary: decimal<br/>8 bytes]
                    F7[details: jsonb<br/>variable + metadata]
                    F8[photo: binary<br/>variable + metadata]
                    F9[timestamps<br/>8 bytes each]
                end
                
                PAD[Alignment Padding<br/>For 8-byte boundaries]
            end
            
            T2[Tuple 2<br/>Header + Values]
            T3[...]
        end
        
        subgraph "TOAST Pointer Area"
            TP[TOAST Pointers<br/>For Large Values]
            TP --> |Points to| ET[(External<br/>TOAST Table)]
        end
        
        subgraph "Special Area"
            SS[Special Space<br/>Index-specific data]
        end
    end

    style PH fill:#f9f,stroke:#333,stroke-width:2px
    style IP fill:#bbf,stroke:#333,stroke-width:2px
    style FS fill:#bfb,stroke:#333,stroke-width:2px
    style TD fill:#fbf,stroke:#333,stroke-width:2px
    style SS fill:#fbb,stroke:#333,stroke-width:2px
    style TH fill:#ddf,stroke:#333,stroke-width:2px
    style NB fill:#ffd,stroke:#333,stroke-width:2px
    style PAD fill:#ddd,stroke:#333,stroke-width:2px
    style TP fill:#fdb,stroke:#333,stroke-width:2px
    style ET fill:#bdf,stroke:#333,stroke-width:2px

    %% Add annotations for NULL handling
    AN1[NULL values only use<br/>1 bit in null bitmap]
    AN2[TOAST-able fields move to<br/>external storage if > 2KB]
    
    AN1 --> NB
    AN2 --> TP
```

### Key Learnings from Tuple Analysis

From our practical examples in `practice_tuple.rb`, we observed:

1. **Basic Tuple Overhead**:
   - Header: 23 bytes fixed
   - Null bitmap: 2 bytes for our 9-column table
   - Actual measurements from different tuple types:
     * Minimal tuple (mostly NULLs): 54 bytes
     * Typical tuple (mixed types): 123 bytes
     * Detailed tuple (large fields): 2434 bytes
     * Compact tuple (small fields): 85 bytes
     * Mixed tuple (varied sizes): 844 bytes

2. **Data Type Storage Patterns**:
   ```
   Fixed-length types (from our examples):
   - integer (employee_id): 4 bytes
   - boolean (active): 1 byte
   - date (hire_date): 4 bytes
   - decimal (salary): 8 bytes
   - timestamp (created_at/updated_at): 8 bytes each

   Variable-length types (from our examples):
   - text/varchar (name): 8-60 bytes in our tests
   - jsonb (details): 19-1316 bytes depending on content
   - binary (photo): 500-1000 bytes in our tests
   ```

3. **Storage Efficiency Insights**:
   - NULL values only consume space in the null bitmap
   - Our table uses 4 TOAST-capable columns (name, details, photo, text fields)
   - A single 8KB page can hold multiple records (5 in our test)
   - Index overhead adds significant space (16KB in our case)

### Practical Exercises - Tuple Analysis

1. **Null Bitmap Investigation**
   ```ruby
   # Modify the employees table to test null bitmap sizes:
   # Current size: 2 bytes for 9 columns
   # Add columns in multiples of 8 to observe changes:
   t.string :department
   t.string :title
   t.string :location
   t.string :manager
   t.string :team
   t.string :project
   t.string :role
   ```

2. **Alignment Impact**
   ```ruby
   # Reorder our existing columns to test alignment:
   # Current order: string, integer, boolean, date, decimal, jsonb, binary, timestamps
   # Try alternative order:
   t.boolean :active       # 1-byte
   t.date    :hire_date    # 4-byte
   t.string  :name         # variable
   t.decimal :salary       # 8-byte
   # Compare storage sizes
   ```

3. **TOAST Threshold Testing**
   ```ruby
   # Use our existing photo and details fields:
   Employee.create!(
     name: "Test Employee",
     photo: "A" * 2048,  # Just under TOAST threshold
     details: { data: "B" * 2048 }  # Test JSONB TOAST
   )
   ```

## Part 2: TOAST Storage

PostgreSQL uses a fixed page size (commonly 8KB), but needs to store values that are potentially much larger. The TOAST system allows PostgreSQL to store and manipulate large values that exceed the page size efficiently.

### TOAST Behavior

```mermaid
graph TD
    A[Table Row] --> B{Value Size > 2KB?}
    B -->|No| C[Store Inline in Table]
    B -->|Yes| D{TOAST Strategy}
    D -->|Plain| E[Store External - No Compression]
    D -->|Extended| F[Store External - With Compression]
    D -->|Main| G[Try Compression First]
    G -->|Still > 2KB| H[Store External]
    G -->|Now < 2KB| I[Store Inline]
    E --> J[(TOAST Table)]
    F --> J
    H --> J
    
    style A fill:#f9f,stroke:#333,stroke-width:2px
    style J fill:#bbf,stroke:#333,stroke-width:2px
```

### TOAST Analysis from Practice

From our examples:
- Large JSON (1316 bytes): Stored inline
- Photo (1000 bytes): Stored inline
- Very large text (>2KB): Moved to TOAST
- Actual table size: 8192 bytes
- TOAST columns: 4 (name, details, photo, text fields)

### Practical Exercises - TOAST

1. **TOAST Threshold Testing**
   ```ruby
   # Create records with increasing field sizes:
   # - 1KB, 1.5KB, 2KB, 2.5KB, 3KB
   # Observe when TOAST kicks in
   ```

2. **TOAST Strategy Impact**
   ```ruby
   # Compare storage for the same large value using:
   # - PLAIN strategy
   # - EXTENDED strategy
   # - MAIN strategy
   ```

3. **Compression Effectiveness**
   ```ruby
   # Store the same size data with:
   # - Random bytes (less compressible)
   # - Repeated pattern (more compressible)
   # Compare TOAST storage size
   ```

## Learning Objectives Checklist

After completing this module, you should understand:
- [ ] Basic tuple structure and overhead
- [ ] How NULL values impact storage
- [ ] Alignment requirements for different data types
- [ ] When and how TOAST storage is triggered
- [ ] The relationship between theoretical and actual storage sizes

## Files in this Module

1. `storage_explorer.rb`: Utilities for analyzing PostgreSQL storage
2. `practice_tuple.rb`: Hands-on exercises with tuple storage concepts
3. `practice_storage.rb`: Examples of general storage concepts

## Additional Resources

- [PostgreSQL Documentation: Database Page Layout](https://www.postgresql.org/docs/current/storage-page-layout.html)
- [PostgreSQL Documentation: TOAST](https://www.postgresql.org/docs/current/storage-toast.html)
- [PostgreSQL Documentation: Database Physical Storage](https://www.postgresql.org/docs/current/storage.html)
