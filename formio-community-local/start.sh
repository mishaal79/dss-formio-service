#!/bin/bash

# Form.io Community Local Development Startup Script

set -e

echo "🚀 Starting Form.io Community Local Development Environment"
echo "================================================="

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env file created. Please review and update credentials if needed."
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Start services
echo "🐳 Starting Docker Compose services..."
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
echo "   - MongoDB starting..."

# Wait for MongoDB to be ready
until docker-compose exec -T mongodb mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
    echo "   - Waiting for MongoDB..."
    sleep 2
done

echo "✅ MongoDB is ready!"

# Wait for Form.io to be ready
echo "   - Form.io starting..."
sleep 10

# Check if Form.io is responding
until curl -f http://localhost:3001/health > /dev/null 2>&1; do
    echo "   - Waiting for Form.io..."
    sleep 5
done

echo ""
echo "🎉 Form.io Community is ready!"
echo "================================================="
echo "📱 Access your Form.io instance:"
echo "   URL: http://localhost:3001"
echo "   Admin Email: admin@example.com"
echo "   Admin Password: changeme123"
echo ""
echo "🔧 Useful commands:"
echo "   View logs: docker-compose logs -f formio"
echo "   Stop services: docker-compose down"
echo "   MongoDB shell: docker-compose exec mongodb mongosh -u admin -p password"
echo ""
echo "📚 For more information, see README.md"