# Deployment Guide

This guide covers different deployment methods for the Palo Alto Emergency Response System.

## Prerequisites

- PostgreSQL 16+ with PostGIS extension
- Node.js 18+
- Nginx (for production)
- Docker and Docker Compose (for containerized deployment)

## Quick Deployment Options

### 1. Docker Deployment (Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd palo-alto-emergency-response

# Set environment variables
cp .env.example .env
# Edit .env with your configuration

# Start services
docker-compose up -d

# Access the application
open http://localhost
```

### 2. System Installation

```bash
# Run the automated installer
sudo ./install.sh
```

### 3. Manual Installation

#### Database Setup
```bash
# Install PostgreSQL and PostGIS
sudo apt install postgresql-16 postgresql-16-postgis-3

# Create database and user
sudo -u postgres createdb palo_alto_emergency
sudo -u postgres psql -c "CREATE USER emergency_user WITH PASSWORD 'your_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE palo_alto_emergency TO emergency_user;"

# Load schema
sudo -u postgres psql -d palo_alto_emergency -f database/schema.sql
```

#### API Setup
```bash
cd src/api
npm install --production
cp ../../.env.example ../../.env
# Edit .env with your database credentials
npm start
```

#### Web Server Setup
```bash
# Install and configure Nginx
sudo apt install nginx
sudo cp nginx.conf /etc/nginx/sites-available/emergency-response
sudo ln -s /etc/nginx/sites-available/emergency-response /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

## Production Configuration

### SSL/HTTPS Setup
1. Obtain SSL certificates (Let's Encrypt recommended)
2. Update nginx.conf with SSL configuration
3. Redirect HTTP to HTTPS

### Security Hardening
- Configure firewall (UFW/iptables)
- Set up fail2ban
- Regular security updates
- Database connection encryption
- API rate limiting (already configured)

### Monitoring
- Set up log aggregation
- Configure health check monitoring
- Database performance monitoring
- Application performance monitoring

### Backup Strategy
- Automated daily database backups (script included)
- Application file backups
- Configuration backups
- Test restore procedures

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Application environment | `production` |
| `PORT` | API server port | `3000` |
| `DB_HOST` | Database host | `localhost` |
| `DB_PORT` | Database port | `5432` |
| `DB_NAME` | Database name | `palo_alto_emergency` |
| `DB_USER` | Database user | `emergency_user` |
| `DB_PASSWORD` | Database password | - |
| `DB_SSL` | Enable SSL for database | `false` |

## Troubleshooting

### Common Issues

**Database Connection Failed**
- Check PostgreSQL service status
- Verify credentials in .env
- Check pg_hba.conf authentication

**API Server Won't Start**
- Check Node.js version (18+ required)
- Verify all dependencies installed
- Check port availability
- Review logs: `journalctl -u emergency-response -f`

**Nginx 502 Bad Gateway**
- Verify API server is running
- Check nginx configuration
- Verify proxy settings

### Log Locations
- API logs: `journalctl -u emergency-response`
- Nginx logs: `/var/log/nginx/error.log`
- PostgreSQL logs: `/var/log/postgresql/`

### Performance Tuning
- Adjust PostgreSQL settings for your hardware
- Configure connection pooling
- Enable nginx caching
- Optimize database indexes
