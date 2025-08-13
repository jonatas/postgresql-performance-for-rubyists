#!/bin/bash

# PostgreSQL Performance Workshop - Ruby Setup Script
# This script sets up the Ruby environment for the workshop

set -e

echo "🚀 Setting up PostgreSQL Performance Workshop - Ruby Edition"
echo "=========================================================="

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby is not installed. Please install Ruby 3.0+ first."
    exit 1
fi

RUBY_VERSION=$(ruby -v | cut -d' ' -f2 | cut -d'p' -f1)
echo "✅ Ruby version: $RUBY_VERSION"

# Check if bundler is installed
if ! command -v bundle &> /dev/null; then
    echo "📦 Installing bundler..."
    gem install bundler
fi

# Install dependencies
echo "📦 Installing Ruby dependencies..."
bundle install

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "📄 Loading environment from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if PostgreSQL is running
echo "🔍 Checking PostgreSQL connection..."
if ! bundle exec ruby -e "
require 'pg'
begin
  conn = PG.connect(ENV['DATABASE_URL'] || 'postgres://localhost/workshop_db')
  puts '✅ PostgreSQL connection successful'
  conn.close
rescue => e
  puts '❌ PostgreSQL connection failed: ' + e.message
  puts 'Please ensure PostgreSQL is running and DATABASE_URL is set correctly'
  puts 'Current DATABASE_URL: ' + (ENV['DATABASE_URL'] || 'not set')
  exit 1
end
"; then
    echo "❌ PostgreSQL setup failed"
    exit 1
fi

# Test the first example
echo "🧪 Testing workshop setup..."
if bundle exec ruby ruby/01_storage/practice_storage.rb; then
    echo "✅ Workshop setup successful!"
    echo ""
    echo "🎉 You're ready to start the workshop!"
    echo ""
    echo "Next steps:"
    echo "1. Read the main README.md for an overview"
    echo "2. Start with ruby/01_storage/README.md"
echo "3. Run examples with: bundle exec ruby ruby/01_storage/practice_storage.rb"
    echo ""
    echo "Happy learning! 🚀"
else
    echo "❌ Workshop test failed"
    exit 1
fi
