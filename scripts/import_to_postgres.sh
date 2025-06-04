#!/bin/bash
set -e

# Import converted MySQL data into PostgreSQL
echo "Importing converted MySQL data into PostgreSQL..."

# Configuration
POSTGRES_CONTAINER="webdna-postgres"
POSTGRES_USER="webdna_user"
POSTGRES_DB="webdna_main"
CONVERTED_SQL="/docker-entrypoint-initdb.d/converted_databases.sql"

# Check if container is running
if ! docker ps | grep -q $POSTGRES_CONTAINER; then
    echo "Error: PostgreSQL container is not running. Please start it first with:"
    echo "  docker-compose up -d postgres"
    exit 1
fi

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker exec $POSTGRES_CONTAINER pg_isready -U $POSTGRES_USER -d $POSTGRES_DB > /dev/null 2>&1; do
    echo "Waiting for PostgreSQL..."
    sleep 2
done

echo "PostgreSQL is ready. Starting import..."

# Import the converted data
echo "Importing data from converted SQL file..."
docker exec -i $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -f $CONVERTED_SQL

if [ $? -eq 0 ]; then
    echo "✓ Data import completed successfully!"
    
    # Show imported databases
    echo ""
    echo "Imported databases:"
    docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';"
else
    echo "✗ Data import failed!"
    exit 1
fi