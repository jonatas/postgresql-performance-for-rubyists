#!/bin/bash

# PostgreSQL Performance Workshop - SQL Setup Script
# This script sets up the SQL environment for the workshop

set -e

echo "🚀 Setting up PostgreSQL Performance Workshop - SQL Edition"
echo "=========================================================="

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "📄 Loading environment from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if psql is installed
if ! command -v psql &> /dev/null; then
    echo "❌ psql is not installed. Please install PostgreSQL client tools first."
    exit 1
fi

PSQL_VERSION=$(psql --version | cut -d' ' -f3)
echo "✅ psql version: $PSQL_VERSION"

# Check if PostgreSQL is running
echo "🔍 Checking PostgreSQL connection..."

# Try to connect to PostgreSQL using environment variables or defaults
DB_HOST=${POSTGRES_HOST:-localhost}
DB_PORT=${POSTGRES_PORT:-5432}
DB_USER=${POSTGRES_USER:-postgres}
DB_PASSWORD=${POSTGRES_PASSWORD:-password}
DB_NAME=${POSTGRES_DB:-postgres}

if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT version();" &> /dev/null; then
    echo "❌ Cannot connect to PostgreSQL"
    echo ""
    echo "Current connection settings:"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  User: $DB_USER"
    echo "  Database: $DB_NAME"
    echo ""
    echo "Please ensure PostgreSQL is running and accessible."
    echo "You can start PostgreSQL with Docker:"
    echo "docker run -d --rm -it -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_USER=postgres -e POSTGRES_DATABASE=workshop_db -p 5432:5432 timescale/timescaledb-ha:pg17"
    echo ""
    echo "Or check your .env file configuration."
    exit 1
fi

echo "✅ PostgreSQL connection successful"

# Create workshop database if it doesn't exist
echo "🗄️ Setting up workshop database..."
WORKSHOP_DB=${POSTGRES_DB:-workshop_db}
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "CREATE DATABASE $WORKSHOP_DB;" 2>/dev/null || echo "Database already exists"

# Test the first example
echo "🧪 Testing workshop setup..."
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $WORKSHOP_DB -f sql/01_storage/practice_storage.sql; then
    echo "✅ Workshop setup successful!"
    echo ""
    echo "🎉 You're ready to start the workshop!"
    echo ""
    echo "Next steps:"
    echo "1. Read the main README.md for an overview"
    echo "2. Start with sql/01_storage/README.md"
    echo "3. Run examples with: psql -d workshop_db -f sql/01_storage/practice_storage.sql"
    echo ""
    echo "Happy learning! 🚀"
else
    echo "❌ Workshop test failed"
    exit 1
fi
