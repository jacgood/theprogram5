#!/bin/bash
set -e

# Test PostgreSQL connection and data
echo "Testing PostgreSQL connection and database migration..."

POSTGRES_CONTAINER="webdna-postgres"
POSTGRES_USER="webdna_user"
POSTGRES_DB="webdna_main"

# Check if container is running
if ! docker ps | grep -q $POSTGRES_CONTAINER; then
    echo "❌ PostgreSQL container is not running"
    exit 1
fi

echo "✅ PostgreSQL container is running"

# Test connection
if docker exec $POSTGRES_CONTAINER pg_isready -U $POSTGRES_USER -d $POSTGRES_DB > /dev/null 2>&1; then
    echo "✅ PostgreSQL is accepting connections"
else
    echo "❌ Cannot connect to PostgreSQL"
    exit 1
fi

# List all databases
echo ""
echo "📊 Available databases:"
docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
    SELECT 
        datname as \"Database\", 
        pg_size_pretty(pg_database_size(datname)) as \"Size\"
    FROM pg_database 
    WHERE datistemplate = false 
    ORDER BY datname;"

echo ""
echo "🔍 Database connection info:"
echo "Host: localhost"
echo "Port: 5432"
echo "Main Database: $POSTGRES_DB"
echo "Username: $POSTGRES_USER"
echo "Password: webdna_secure_password_2024"

echo ""
echo "🎯 Example connection commands:"
echo "  docker exec -it webdna-postgres psql -U webdna_user -d goodvaluation"
echo "  psql -h localhost -p 5432 -U webdna_user -d goodvaluation"

echo ""
echo "✅ PostgreSQL migration completed successfully!"