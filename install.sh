#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚨 Palo Alto Emergency Response System Installer 🚨${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${BLUE}Installing system packages...${NC}"
if [[ -f /etc/debian_version ]]; then
    # Ubuntu/Debian - Install PostgreSQL 17
    apt update
    apt install -y wget ca-certificates
    
    # Add PostgreSQL 17 official APT repository
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    
    apt update
    apt install -y postgresql-17 postgresql-client-17 postgresql-17-postgis-3 nodejs npm nginx git curl
    
    # Add TimescaleDB repository for PostgreSQL 17
    echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" > /etc/apt/sources.list.d/timescaledb.list
    wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | apt-key add -
    apt update
    
    # Install TimescaleDB for PostgreSQL 17 (may not be available yet)
    apt install -y timescaledb-2-postgresql-17 || echo -e "${YELLOW}TimescaleDB not available for PostgreSQL 17 yet, continuing without it${NC}"
    
elif [[ -f /etc/redhat-release ]]; then
    # RHEL/CentOS/Fedora - Install PostgreSQL 17
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm || \
    yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    
    dnf install -y postgresql17-server postgresql17 postgresql17-contrib postgis34_17 nodejs npm nginx git curl || \
    yum install -y postgresql17-server postgresql17 postgresql17-contrib postgis34_17 nodejs npm nginx git curl
    
    # Initialize PostgreSQL 17
    /usr/pgsql-17/bin/postgresql-17-setup initdb
    systemctl enable postgresql-17
    systemctl start postgresql-17
    
    # TimescaleDB for RHEL/CentOS (may not be available for PostgreSQL 17)
    dnf install -y timescaledb-2-postgresql-17 || yum install -y timescaledb-2-postgresql-17 || echo -e "${YELLOW}TimescaleDB not available for PostgreSQL 17 yet${NC}"
else
    echo -e "${RED}Unsupported operating system. Please install PostgreSQL 17, PostGIS, Node.js, and nginx manually.${NC}"
    exit 1
fi

echo -e "${BLUE}Setting up PostgreSQL 17...${NC}"
# Start PostgreSQL service
if systemctl list-unit-files | grep -q "postgresql-17.service"; then
    systemctl start postgresql-17
    systemctl enable postgresql-17
    PG_SERVICE="postgresql-17"
else
    systemctl start postgresql
    systemctl enable postgresql  
    PG_SERVICE="postgresql"
fi

DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Configure PostgreSQL 17 authentication
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP "PostgreSQL \K[0-9]+")
if [[ $PG_VERSION -ge 17 ]]; then
    echo -e "${BLUE}Configuring PostgreSQL 17 authentication...${NC}"
    # Update pg_hba.conf for PostgreSQL 17 security
    PG_HBA_FILE=$(sudo -u postgres psql -t -c "SHOW hba_file;" | xargs)
    if [[ -f "$PG_HBA_FILE" ]]; then
        cp "$PG_HBA_FILE" "$PG_HBA_FILE.backup"
        # Ensure scram-sha-256 authentication
        sed -i 's/local   all             all                                     peer/local   all             all                                     scram-sha-256/' "$PG_HBA_FILE" || true
        sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            scram-sha-256/' "$PG_HBA_FILE" || true
        systemctl reload $PG_SERVICE
    fi
fi

# Create database and user
sudo -u postgres createdb palo_alto_emergency || true
sudo -u postgres psql -c "CREATE USER emergency_user WITH PASSWORD '$DB_PASSWORD';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE palo_alto_emergency TO emergency_user;"
sudo -u postgres psql -c "ALTER USER emergency_user CREATEDB;" || true

# Grant schema permissions for PostgreSQL 17
sudo -u postgres psql -d palo_alto_emergency -c "GRANT ALL ON SCHEMA public TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO emergency_user;" || true

# Load database schema
echo -e "${BLUE}Loading database schema...${NC}"
sudo -u postgres psql -d palo_alto_emergency -f database/schema.sql || echo -e "${YELLOW}Schema loading completed with warnings${NC}"

# Configure TimescaleDB if available
if command -v timescaledb-tune &> /dev/null; then
    echo -e "${BLUE}Configuring TimescaleDB...${NC}"
    timescaledb-tune --quiet --yes || echo -e "${YELLOW}TimescaleDB tuning skipped${NC}"
    systemctl restart $PG_SERVICE
fi

echo -e "${BLUE}Installing Node.js dependencies...${NC}"
# Check if we're in the project directory and navigate properly
if [[ ! -d "src/api" ]]; then
    echo -e "${RED}Error: src/api directory not found. Please run this installer from the project root directory.${NC}"
    echo -e "${YELLOW}Current directory: $(pwd)${NC}"
    echo -e "${YELLOW}Expected structure: $(pwd)/src/api/package.json${NC}"
    exit 1
fi

cd src/api
if [[ ! -f "package.json" ]]; then
    echo -e "${RED}Error: package.json not found in src/api directory${NC}"
    exit 1
fi

npm install --production
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: npm install failed${NC}"
    exit 1
fi
cd ../..

echo -e "${BLUE}Creating system service...${NC}"
# Use absolute paths to avoid working directory issues
PROJECT_ROOT=$(pwd)
API_DIR="$PROJECT_ROOT/src/api"

# Verify the API directory exists and has the server file
if [[ ! -f "$API_DIR/server.js" ]]; then
    echo -e "${RED}Error: server.js not found at $API_DIR/server.js${NC}"
    exit 1
fi

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"
chmod 755 "$PROJECT_ROOT/logs"

cat > /etc/systemd/system/emergency-response.service << SERVICEFILE
[Unit]
Description=Palo Alto Emergency Response System
Documentation=https://github.com/yourusername/palo-alto-emergency-response
After=network.target $PG_SERVICE.service
Wants=$PG_SERVICE.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$API_DIR
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=emergency-response

# Environment variables
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=DB_NAME=palo_alto_emergency
Environment=DB_USER=emergency_user
Environment=DB_PASSWORD=$DB_PASSWORD

# Security settings for PostgreSQL 17
Environment=DB_SSL=false
Environment=DB_CONNECTION_TIMEOUT=30000

# Security restrictions
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROJECT_ROOT/logs $PROJECT_ROOT/uploads

[Install]
WantedBy=multi-user.target
SERVICEFILE

systemctl daemon-reload
systemctl enable emergency-response
systemctl start emergency-response

echo -e "${BLUE}Configuring Nginx...${NC}"
# Verify project structure
PROJECT_ROOT=$(pwd)
WEB_DIR="$PROJECT_ROOT/src/web"

if [[ ! -d "$WEB_DIR" ]]; then
    echo -e "${RED}Error: Web directory not found at $WEB_DIR${NC}"
    exit 1
fi

# Ensure nginx.conf exists before copying
if [[ ! -f "nginx.conf" ]]; then
    echo -e "${YELLOW}nginx.conf not found, creating default configuration...${NC}"
    cat > nginx.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    location / {
        root /var/www/emergency-response;
        index index.html;
        try_files $uri $uri/ @api;
    }
    
    location @api {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /api {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /ws {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINXEOF
fi

# Copy web files to standard location for easier nginx configuration
WEB_ROOT="/var/www/emergency-response"
echo -e "${BLUE}Setting up web root at $WEB_ROOT...${NC}"
mkdir -p "$WEB_ROOT"
cp -r "$WEB_DIR/"* "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null || chown -R nginx:nginx "$WEB_ROOT" 2>/dev/null || true
chmod -R 644 "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;

# Copy and configure nginx
if [[ -d /etc/nginx/sites-available ]]; then
    # Ubuntu/Debian style
    cp nginx.conf /etc/nginx/sites-available/emergency-response
    # Update the web root path in the config
    sed -i "s|/var/www/emergency-response|$WEB_ROOT|g" /etc/nginx/sites-available/emergency-response
    
    # Enable site
    ln -sf /etc/nginx/sites-available/emergency-response /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    if ! nginx -t; then
        echo -e "${RED}Nginx configuration test failed${NC}"
        cat /etc/nginx/sites-available/emergency-response
        exit 1
    fi
else
    # RHEL/CentOS style
    cp nginx.conf /etc/nginx/conf.d/emergency-response.conf
    # Update the web root path in the config
    sed -i "s|/var/www/emergency-response|$WEB_ROOT|g" /etc/nginx/conf.d/emergency-response.conf
    
    # Remove default server block if it exists
    if [[ -f /etc/nginx/nginx.conf ]]; then
        sed -i '/server {/,/}/d' /etc/nginx/nginx.conf 2>/dev/null || true
    fi
    
    # Test nginx configuration
    if ! nginx -t; then
        echo -e "${RED}Nginx configuration test failed${NC}"
        cat /etc/nginx/conf.d/emergency-response.conf
        exit 1
    fi
fi

# Test and restart nginx
nginx -t && systemctl restart nginx && systemctl enable nginx

# Save configuration
echo "DB_PASSWORD=$DB_PASSWORD" > /etc/emergency-response.conf
echo "POSTGRES_VERSION=$PG_VERSION" >> /etc/emergency-response.conf
chmod 600 /etc/emergency-response.conf

# Create backup script compatible with PostgreSQL 17
cat > /usr/local/bin/emergency-backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="/var/backups/emergency-response"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="palo_alto_emergency"
DB_USER="emergency_user"

mkdir -p "$BACKUP_DIR"

# Database backup with PostgreSQL 17 compatibility
export PGPASSWORD="$DB_PASSWORD"
pg_dump -h localhost -U "$DB_USER" "$DB_NAME" --no-password | gzip > "$BACKUP_DIR/database_$DATE.sql.gz"

# Application backup
tar -czf "$BACKUP_DIR/application_$DATE.tar.gz" --exclude='node_modules' --exclude='logs' -C $(dirname $(pwd)) $(basename $(pwd))

# Keep only last 30 days of backups
find "$BACKUP_DIR" -type f -mtime +30 -delete

echo "Backup completed: $DATE"
BACKUPEOF

chmod +x /usr/local/bin/emergency-backup.sh

# Add to crontab for daily backups
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/emergency-backup.sh") | crontab -

# Verify services are running
sleep 5

if systemctl is-active --quiet $PG_SERVICE; then
    echo -e "${GREEN}✅ PostgreSQL $PG_VERSION is running${NC}"
else
    echo -e "${RED}❌ PostgreSQL failed to start${NC}"
fi

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx is running${NC}"  
else
    echo -e "${RED}❌ Nginx failed to start${NC}"
fi

if systemctl is-active --quiet emergency-response; then
    echo -e "${GREEN}✅ Emergency Response System is running${NC}"
else
    echo -e "${RED}❌ Emergency Response System failed to start${NC}"
fi

echo -e "${GREEN}✅ Installation completed!${NC}"
echo "=============================================="
echo -e "${BLUE}System Information:${NC}"
echo "🌐 Web Interface: http://$(hostname -I | awk '{print $1}')"
echo "📊 API Health Check: http://$(hostname -I | awk '{print $1}'):3000/api/health"
echo "🔧 Nginx Health Check: http://$(hostname -I | awk '{print $1}')/health"
echo "🗄️  Database: PostgreSQL $PG_VERSION with PostGIS"
echo "📁 Project Root: $PROJECT_ROOT"
echo "📁 Web Root: $WEB_ROOT"
echo "🔑 Database Password: $DB_PASSWORD"
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo "• Start:   sudo systemctl start emergency-response"
echo "• Stop:    sudo systemctl stop emergency-response"
echo "• Restart: sudo systemctl restart emergency-response"
echo "• Status:  sudo systemctl status emergency-response"
echo "• Logs:    sudo journalctl -u emergency-response -f"
echo ""
echo -e "${BLUE}Database Management:${NC}"
echo "• PostgreSQL Service: sudo systemctl status $PG_SERVICE"
echo "• Connect to DB: sudo -u postgres psql -d palo_alto_emergency"
echo "• Test DB: sudo -u emergency_user psql -h localhost -d palo_alto_emergency"
echo "• Backup Script: /usr/local/bin/emergency-backup.sh"
echo ""
echo -e "${BLUE}Web Server Management:${NC}"
echo "• Nginx Status: sudo systemctl status nginx"
echo "• Test Config: sudo nginx -t"
echo "• Nginx Logs: sudo tail -f /var/log/nginx/error.log"
echo "• Web Files: ls -la $WEB_ROOT"
echo ""
echo -e "${BLUE}Troubleshooting:${NC}"
echo "• API not responding:"
echo "  - Check: sudo journalctl -u emergency-response -n 50"
echo "  - Verify: curl http://localhost:3000/api/health"
echo "  - Test DB: sudo -u postgres psql -d palo_alto_emergency -c 'SELECT 1;'"
echo ""
echo "• 502 Bad Gateway:"
echo "  - Check API service: sudo systemctl status emergency-response"
echo "  - Check nginx config: sudo nginx -t"
echo "  - Verify proxy: curl http://localhost:3000/api/health"
echo ""
echo "• Database connection issues:"
echo "  - Check PostgreSQL: sudo systemctl status $PG_SERVICE"
echo "  - Check credentials in: /etc/emergency-response.conf"
echo "  - Test connection: sudo -u postgres psql -l"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test web interface: curl http://$(hostname -I | awk '{print $1}')/health"
echo "2. Test API: curl http://$(hostname -I | awk '{print $1}'):3000/api/health"
echo "3. Configure your tile server URL in $WEB_ROOT/js/app.js"
echo "4. Review and customize configuration files"
echo "5. Set up SSL certificate for production use"
echo "6. Configure monitoring and alerting"
echo ""
if systemctl is-active --quiet emergency-response && systemctl is-active --quiet nginx && systemctl is-active --quiet $PG_SERVICE; then
    echo -e "${GREEN}🚨 All services running - Emergency Response System Ready! 🚨${NC}"
else
    echo -e "${YELLOW}⚠️  Some services may need attention. Check the status above.${NC}"
    echo -e "${YELLOW}Run: sudo journalctl -u emergency-response -f${NC}"
fi
echo "=============================================="
