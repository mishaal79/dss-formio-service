# Form.io Community Local Development Environment

Complete Docker Compose setup for local Form.io Community Edition development.

## Quick Start

1. **Copy environment configuration**:
   ```bash
   cp .env.example .env
   ```

2. **Start the services**:
   ```bash
   docker-compose up -d
   ```

3. **Access Form.io**:
   - **URL**: http://localhost:3001
   - **Admin Email**: admin@example.com
   - **Admin Password**: changeme123

## Services

### Form.io Community (Port 3001)
- **Image**: `formio/formio:rc`
- **Access**: http://localhost:3001
- **Health Check**: http://localhost:3001/health

### MongoDB (Port 27017)
- **Version**: MongoDB 6.0
- **Username**: admin
- **Password**: password
- **Database**: formio
- **Data Persistence**: `./data/mongodb`

## Environment Configuration

### Required Variables
Edit `.env` to customize:

```bash
# MongoDB
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=password

# Form.io Admin
ROOT_EMAIL=admin@example.com
ROOT_PASSWORD=changeme123

# Security (CHANGE THESE!)
JWT_SECRET=your-jwt-secret-change-me-now
DB_SECRET=your-db-secret-change-me-now
```

### GCS Storage Configuration
For file uploads using Google Cloud Storage:

```bash
FORMIO_FILES_SERVER=s3
FORMIO_S3_SERVER=https://storage.googleapis.com
FORMIO_S3_BUCKET=your-bucket-name
FORMIO_S3_KEY=your-gcs-access-key
FORMIO_S3_SECRET=your-gcs-secret-key
```

## Common Commands

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f formio
docker-compose logs -f mongodb

# Stop services
docker-compose down

# Reset data (WARNING: Deletes all data)
docker-compose down -v
sudo rm -rf ./data/mongodb/*

# Update Form.io image
docker-compose pull formio
docker-compose up -d formio
```

## Database Management

### Connect to MongoDB
```bash
# Using Docker
docker-compose exec mongodb mongosh -u admin -p password

# Using local MongoDB client
mongosh "mongodb://admin:password@localhost:27017/formio?authSource=admin"
```

### Database Operations
```javascript
// List databases
show dbs

// Switch to formio database
use formio

// List collections
show collections

// View forms
db.forms.find().pretty()
```

## Troubleshooting

### Form.io Won't Start
1. Check MongoDB is healthy: `docker-compose ps`
2. View Form.io logs: `docker-compose logs formio`
3. Verify environment variables in `.env`

### Connection Issues
1. Ensure MongoDB authentication is working:
   ```bash
   docker-compose exec mongodb mongosh -u admin -p password --eval "db.adminCommand('ping')"
   ```

2. Check network connectivity:
   ```bash
   docker-compose exec formio ping mongodb
   ```

### Port Conflicts
If port 3001 is in use:
```yaml
# In docker-compose.yml, change:
ports:
  - "3002:3001"  # Use port 3002 instead
```

## Production Readiness

This setup matches the production configuration patterns:

- **Authentication**: MongoDB with proper auth
- **Networking**: Container networking with health checks
- **Configuration**: JSON-based NODE_CONFIG
- **Storage**: S3-compatible (GCS) configuration ready
- **Monitoring**: Health check endpoints configured

### Security Notes
- Change default passwords in `.env`
- Use strong JWT and DB secrets
- Configure proper email settings for production
- Set up proper GCS bucket permissions

## Integration with GCP Deployment

This local environment mirrors the GCP Cloud Run configuration:
- Same MongoDB authentication pattern
- Same environment variable structure
- Same S3-compatible storage configuration
- Compatible with the Terraform deployment in this repository

To deploy to GCP, use the main project's Makefile:
```bash
cd ..
make deploy-com  # Deploy community edition to GCP
```