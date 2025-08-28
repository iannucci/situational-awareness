# Installation Instructions

This document provides step-by-step installation instructions for the Palo Alto Emergency Response System.

## System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
- **Memory**: 4GB RAM
- **Storage**: 20GB free space
- **CPU**: 2 cores

### Recommended Requirements
- **OS**: Ubuntu 22.04 LTS
- **Memory**: 8GB RAM
- **Storage**: 50GB free space (SSD preferred)
- **CPU**: 4 cores
- **Network**: Static IP address for production

## Installation Methods

### Method 1: Automated Installation (Recommended)

The automated installer handles all dependencies and configuration:

```bash
# Download the project
git clone <repository-url>
cd palo-alto-emergency-response

# Make installer executable
chmod +x install.sh

# Run installer as root
sudo ./install.sh
```

The installer will:
- Install PostgreSQL 16 with PostGIS
- Install Node.js and npm
- Install and configure Nginx
- Create database and user
- Load schema and sample data
- Configure systemd service
- Set up log rotation and backups

### Method 2: Docker Installation

For containerized deployment:

```bash
# Clone repository
git clone <repository-url>
cd palo-alto-emergency-response

# Copy environment file
cp .env.example .env

# Edit configuration
nano .env

# Start services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

### Method 3: Manual Installation

For custom installations or troubleshooting:

#### Step 1: Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y postgresql-16 postgresql-16-postgis-3 nodejs npm nginx git curl
```

**RHEL/CentOS:**
```bash
sudo dnf install -y postgresql16-server postgresql16-contrib nodejs npm nginx git curl
```

#### Step 2: Configure Database

```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database
sudo -u postgres createdb palo_alto_emergency

# Create user
sudo -u postgres psql -c "CREATE USER emergency_user WITH PASSWORD 'secure_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE palo_alto_emergency TO emergency_user;"

# Load schema
sudo -u postgres psql -d palo_alto_emergency -f database/schema.sql
```

#### Step 3: Configure Application

```bash
# Install API dependencies
cd src/api
npm install --production

# Create environment file
cp ../../.env.example ../../.env
# Edit .env with your database credentials

# Test API
npm start
```

#### Step 4: Configure Web Server

```bash
# Copy web files
sudo cp -r src/web/* /var/www/html/

# Configure Nginx
sudo cp nginx.conf /etc/nginx/sites-available/emergency-response
sudo ln -s /etc/nginx/sites-available/emergency-response /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test and restart
sudo nginx -t
sudo systemctl restart nginx
```

## Post-Installation

### 1. Verify Installation

Check that all services are running:
```bash
sudo systemctl status emergency-response
sudo systemctl status postgresql
sudo systemctl status nginx
```

Test endpoints:
```bash
curl http://localhost/health
curl http://localhost:3000/api/health
curl http://localhost:3000/api/v1/incidents/active
```

### 2. Configure Firewall

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Allow PostgreSQL (if needed for external access)
sudo ufw allow 5432

# Enable firewall
sudo ufw enable
```

### 3. Set Up SSL (Production)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

### 4. Configure Monitoring

```bash
# View logs
sudo journalctl -u emergency-response -f
sudo tail -f /var/log/nginx
