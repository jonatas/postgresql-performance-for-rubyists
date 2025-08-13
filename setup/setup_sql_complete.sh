#!/bin/bash

# PostgreSQL Performance Workshop - SQL Edition Setup Script
# This script sets up the complete SQL environment and runs all examples

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "📄 Loading environment from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Configuration
DB_HOST=${POSTGRES_HOST:-localhost}
DB_PORT=${POSTGRES_PORT:-5433}
DB_USER=${POSTGRES_USER:-postgres}
DB_NAME=${POSTGRES_DB:-workshop_db}
WORKSHOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}🚀 PostgreSQL Performance Workshop - SQL Edition Setup${NC}"
echo "=================================================="
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to test PostgreSQL connection
test_postgres_connection() {
    local host=$1
    local port=$2
    local user=$3
    
    if psql -h "$host" -p "$port" -U "$user" -c "SELECT 1;" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get PostgreSQL version
get_postgres_version() {
    local host=$1
    local port=$2
    local user=$3
    
    psql -h "$host" -p "$port" -U "$user" -t -c "SELECT version();" | head -1 | sed 's/^[[:space:]]*//'
}

# Step 1: Check prerequisites
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"

# Check if psql is available
if ! command_exists psql; then
    print_error "psql command not found. Please install PostgreSQL client tools."
    echo "Installation instructions:"
    echo "  macOS: brew install postgresql"
    echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
    echo "  CentOS/RHEL: sudo yum install postgresql"
    exit 1
fi
print_status "psql command found"

# Check if we're in the right directory
if [[ ! -f "$WORKSHOP_DIR/README.md" ]]; then
    print_error "Please run this script from the workshop root directory"
    exit 1
fi
print_status "Workshop directory structure verified"

echo ""

# Step 2: Test PostgreSQL connections
echo -e "${BLUE}Step 2: Testing PostgreSQL connections...${NC}"

# Try different connection configurations
CONNECTION_CONFIGS=(
    "localhost:5432:postgres"
    "localhost:5433:postgres"
    "localhost:5432:jonatas"
    "localhost:5433:jonatas"
)

CONNECTION_FOUND=false
for config in "${CONNECTION_CONFIGS[@]}"; do
    IFS=':' read -r host port user <<< "$config"
    
    print_info "Trying connection: $user@$host:$port"
    
    if test_postgres_connection "$host" "$port" "$user"; then
        DB_HOST="$host"
        DB_PORT="$port"
        DB_USER="$user"
        CONNECTION_FOUND=true
        print_status "Successfully connected to PostgreSQL at $host:$port as $user"
        break
    fi
done

if [[ "$CONNECTION_FOUND" == false ]]; then
    print_error "Could not connect to PostgreSQL with any configuration"
    echo ""
    echo "Please ensure PostgreSQL is running and try one of these:"
    echo "  1. Start PostgreSQL service"
    echo "  2. Check if Docker containers are running: docker ps"
    echo "  3. Set PGPASSWORD environment variable: export PGPASSWORD=your_password"
    echo "  4. Try different connection parameters"
    exit 1
fi

# Get PostgreSQL version
PG_VERSION=$(get_postgres_version "$DB_HOST" "$DB_PORT" "$DB_USER")
print_status "PostgreSQL version: $PG_VERSION"

echo ""

# Step 3: Create workshop database
echo -e "${BLUE}Step 3: Setting up workshop database...${NC}"

# Check if database exists
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    print_warning "Database '$DB_NAME' already exists"
    read -p "Do you want to drop and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Dropping existing database..."
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;"
        print_status "Database dropped"
    fi
fi

# Create database if it doesn't exist
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    print_info "Creating database '$DB_NAME'..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;"
    print_status "Database created successfully"
else
    print_status "Database '$DB_NAME' is ready"
fi

echo ""

# Step 4: Run SQL examples
echo -e "${BLUE}Step 4: Running SQL examples...${NC}"

# Array of scripts to run
SCRIPTS=(
    "sql/01_storage/practice_storage.sql:Basic Storage Analysis"
    "sql/01_storage/practice_tuple.sql:Tuple Analysis"
    "sql/01_storage/practice_wal_final.sql:WAL Analysis"
)

for script_info in "${SCRIPTS[@]}"; do
    IFS=':' read -r script_path script_name <<< "$script_info"
    
    if [[ -f "$WORKSHOP_DIR/$script_path" ]]; then
        print_info "Running $script_name..."
        echo "----------------------------------------"
        
        # Run the script and capture output
        if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$WORKSHOP_DIR/$script_path" 2>&1; then
            print_status "$script_name completed successfully"
        else
            print_error "$script_name failed"
            echo "Check the output above for errors"
        fi
        
        echo ""
    else
        print_error "Script not found: $script_path"
    fi
done

echo ""

# Step 5: Verify setup
echo -e "${BLUE}Step 5: Verifying setup...${NC}"

# Check if tables were created
TABLE_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')
print_status "Found $TABLE_COUNT tables in workshop database"

# Check database size
DB_SIZE=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size(current_database()));" | tr -d ' ')
print_status "Database size: $DB_SIZE"

echo ""

# Step 6: Summary
echo -e "${BLUE}Step 6: Setup Summary${NC}"
echo "=================================================="
print_status "PostgreSQL connection: $DB_USER@$DB_HOST:$DB_PORT"
print_status "Workshop database: $DB_NAME"
print_status "PostgreSQL version: $PG_VERSION"
print_status "Database size: $DB_SIZE"
print_status "Tables created: $TABLE_COUNT"

echo ""
echo -e "${GREEN}🎉 SQL Edition setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the output above to understand PostgreSQL storage concepts"
echo "2. Explore the SQL scripts in sql/01_storage/ directory"
echo "3. Read the documentation in shared/01_storage_README.md"
echo "4. Continue with other modules: transactions, queries, timescale"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  Connect to database: psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
echo "  List tables: \dt"
echo "  View table structure: \d table_name"
echo "  Exit psql: \q"
echo ""
echo -e "${YELLOW}For troubleshooting, see: sql/01_storage/README.md${NC}"
