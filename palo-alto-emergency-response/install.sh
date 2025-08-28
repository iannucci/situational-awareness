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

# FIXED: Get the absolute path of the project directory
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
echo -e "${BLUE}Project root: $PROJECT_ROOT${NC}"

# FIXED: Verify we're in the correct directory
if [[ ! -f "$PROJECT_ROOT/database/schema.sql" ]]; then
    echo -e "${RED}Error: database/schema.sql not found at $PROJECT_ROOT/database/schema.sql${NC}"
    echo -e "${RED}Please ensure you're running this script from the project root directory${NC}"
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/src/api/package.json" ]]; then
    echo -e "${RED}Error: API package.json not found at $PROJECT_ROOT/src/api/package.json${NC}"
    exit 1
fi

echo -e "${BLUE}Installing system packages...${NC}"
if [[ -f /etc/debian_version ]]; then
    # Ubuntu/Debian - Install PostgreSQL 16 (more stable than 17)
    apt update
    apt install -y wget ca-certificates
    
    # Add PostgreSQL official APT repository
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    
    apt update
    apt install -y postgresql-16 postgresql-client-16 postgresql-16-postgis-3 nodejs npm nginx git curl
    
    # Install TimescaleDB (optional)
    apt install -y timescaledb-2-postgresql-16 || echo -e "${YELLOW}TimescaleDB not available, continuing without it${NC}"
    
elif [[ -f /etc/redhat-release ]]; then
    # RHEL/CentOS/Fedora
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm || \
    yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    
    dnf install -y postgresql16-server postgresql16 postgresql16-contrib postgis34_16 nodejs npm nginx git curl || \
    yum install -y postgresql16-server postgresql16 postgresql16-contrib postgis34_16 nodejs npm nginx git curl
    
    # Initialize PostgreSQL
    /usr/pgsql-16/bin/postgresql-16-setup initdb
    systemctl enable postgresql-16
    systemctl start postgresql-16
    
else
    echo -e "${RED}Unsupported operating system. Please install PostgreSQL 16+, PostGIS, Node.js, and nginx manually.${NC}"
    exit 1
fi

echo -e "${BLUE}Setting up PostgreSQL...${NC}"
# Start PostgreSQL service
if systemctl list-unit-files | grep -q "postgresql-16.service"; then
    systemctl start postgresql-16
    systemctl enable postgresql-16
    PG_SERVICE="postgresql-16"
else
    systemctl start postgresql
    systemctl enable postgresql  
    PG_SERVICE="postgresql"
fi

# Wait for PostgreSQL to be ready
sleep 5

# Generate secure password
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Configure PostgreSQL authentication
echo -e "${BLUE}Configuring PostgreSQL authentication...${NC}"
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP "PostgreSQL \K[0-9]+")
if [[ $PG_VERSION -ge 14 ]]; then
    PG_HBA_FILE=$(sudo -u postgres psql -t -c "SHOW hba_file;" | xargs)
    if [[ -f "$PG_HBA_FILE" ]]; then
        cp "$PG_HBA_FILE" "$PG_HBA_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        # Update authentication methods
        sed -i 's/local   all             all                                     peer/local   all             all                                     scram-sha-256/' "$PG_HBA_FILE" || true
        sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            scram-sha-256/' "$PG_HBA_FILE" || true
        systemctl reload $PG_SERVICE
        sleep 2
    fi
fi

# Create database and user
echo -e "${BLUE}Creating database and user...${NC}"
sudo -u postgres createdb palo_alto_emergency || echo -e "${YELLOW}Database may already exist${NC}"
sudo -u postgres psql -c "DROP USER IF EXISTS emergency_user;" || true
sudo -u postgres psql -c "CREATE USER emergency_user WITH PASSWORD '$DB_PASSWORD';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE palo_alto_emergency TO emergency_user;" || true
sudo -u postgres psql -c "ALTER USER emergency_user CREATEDB;" || true

# Grant schema permissions
echo -e "${BLUE}Setting up database permissions...${NC}"
sudo -u postgres psql -d palo_alto_emergency -c "GRANT ALL ON SCHEMA public TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO emergency_user;" || true

# FIXED: Load database schema with absolute path
echo -e "${BLUE}Loading database schema from $PROJECT_ROOT/database/schema.sql...${NC}"
if [[ -f "$PROJECT_ROOT/database/schema.sql" ]]; then
    sudo -u postgres psql -d palo_alto_emergency -f "$PROJECT_ROOT/database/schema.sql" || echo -e "${YELLOW}Schema loading completed with warnings${NC}"
else
    echo -e "${RED}Error: Schema file not found at $PROJECT_ROOT/database/schema.sql${NC}"
    exit 1
fi

# Configure TimescaleDB if available
if command -v timescaledb-tune &> /dev/null; then
    echo -e "${BLUE}Configuring TimescaleDB...${NC}"
    timescaledb-tune --quiet --yes || echo -e "${YELLOW}TimescaleDB tuning skipped${NC}"
    systemctl restart $PG_SERVICE
    sleep 3
fi

echo -e "${BLUE}Installing Node.js dependencies...${NC}"
cd "$PROJECT_ROOT/src/api"

if [[ ! -f "package.json" ]]; then
    echo -e "${RED}Error: package.json not found in $PROJECT_ROOT/src/api/package.json${NC}"
    exit 1
fi

npm install --production
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: npm install failed${NC}"
    exit 1
fi

cd "$PROJECT_ROOT"

echo -e "${BLUE}Creating system service...${NC}"
API_DIR="$PROJECT_ROOT/src/api"

# Verify the API directory exists and has the server file
if [[ ! -f "$API_DIR/server.js" ]]; then
    echo -e "${RED}Error: server.js not found at $API_DIR/server.js${NC}"
    exit 1
fi

# Create logs directory with proper permissions
mkdir -p "$PROJECT_ROOT/logs"
chmod 755 "$PROJECT_ROOT/logs"

# FIXED: Create environment file
cat > "$PROJECT_ROOT/.env" << ENVFILE
NODE_ENV=production
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=palo_alto_emergency
DB_USER=emergency_user
DB_PASSWORD=$DB_PASSWORD
DB_SSL=false
DB_CONNECTION_TIMEOUT=30000
ENVFILE

chmod 600 "$PROJECT_ROOT/.env"

# Create systemd service file with proper environment handling
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

# FIXED: Environment file
EnvironmentFile=$PROJECT_ROOT/.env

# Security restrictions
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROJECT_ROOT/logs

[Install]
WantedBy=multi-user.target
SERVICEFILE

systemctl daemon-reload
systemctl enable emergency-response

echo -e "${BLUE}Configuring Nginx...${NC}"
WEB_DIR="$PROJECT_ROOT/src/web"

if [[ ! -d "$WEB_DIR" ]]; then
    echo -e "${RED}Error: Web directory not found at $WEB_DIR${NC}"
    exit 1
fi

# Copy web files to standard location
WEB_ROOT="/var/www/emergency-response"
echo -e "${BLUE}Setting up web root at $WEB_ROOT...${NC}"
mkdir -p "$WEB_ROOT"
cp -r "$WEB_DIR/"* "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null || chown -R nginx:nginx "$WEB_ROOT" 2>/dev/null || true
chmod -R 644 "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;

# Create nginx configuration specifically for system installation
echo -e "${BLUE}Creating nginx configuration for system installation...${NC}"

# Create nginx config for system installation (different from Docker version)
cat > /tmp/emergency-response-nginx.conf << 'NGINXCONF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Main application - serve static files
    location / {
        root /var/www/emergency-response;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            add_header Vary "Accept-Encoding";
        }
    }
    
    # API endpoints (System installation - uses localhost)
    location /api {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        
        # CORS headers for API
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
        
        # Handle OPTIONS requests for CORS
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin * always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
            add_header Access-Control-Max-Age 1728000 always;
            add_header Content-Length 0;
            add_header Content-Type "text/plain; charset=UTF-8";
            return 204;
        }
    }
    
    # WebSocket support for real-time updates
    location /ws {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket timeouts
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_connect_timeout 60s;
    }
    
    # Health check endpoint (nginx level)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ \.(htaccess|htpasswd|ini|log|sh|sql|conf)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/json
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Client settings
    client_max_body_size 10M;
    client_body_buffer_size 128k;
    
    # Proxy timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    proxy_busy_buffers_size 8k;
}
NGINXCONF

# Configure nginx based on system type
if [[ -d /etc/nginx/sites-available ]]; then
    # Ubuntu/Debian style
    cp /tmp/emergency-response-nginx.conf /etc/nginx/sites-available/emergency-response
    
    # Enable site and disable default
    ln -sf /etc/nginx/sites-available/emergency-response /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    echo -e "${GREEN}✅ Configured nginx (Ubuntu/Debian style)${NC}"
else
    # RHEL/CentOS style
    cp /tmp/emergency-response-nginx.conf /etc/nginx/conf.d/emergency-response.conf
    
    # Disable default server block in main config if it exists
    if [[ -f /etc/nginx/nginx.conf ]]; then
        # Comment out any existing server blocks in main config
        sed -i '/^[[:space:]]*server[[:space:]]*{/,/^[[:space:]]*}/s/^/#/' /etc/nginx/nginx.conf 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Configured nginx (RHEL/CentOS style)${NC}"
fi

# Clean up temporary file
rm -f /tmp/emergency-response-nginx.conf

# Test nginx configuration
echo -e "${BLUE}Testing nginx configuration...${NC}"
if ! nginx -t; then
    echo -e "${RED}Nginx configuration test failed${NC}"
    echo -e "${YELLOW}Checking nginx configuration...${NC}"
    
    # Show the configuration we created
    if [[ -f /etc/nginx/sites-available/emergency-response ]]; then
        echo -e "${BLUE}Configuration file: /etc/nginx/sites-available/emergency-response${NC}"
        head -20 /etc/nginx/sites-available/emergency-response
    elif [[ -f /etc/nginx/conf.d/emergency-response.conf ]]; then
        echo -e "${BLUE}Configuration file: /etc/nginx/conf.d/emergency-response.conf${NC}"
        head -20 /etc/nginx/conf.d/emergency-response.conf
    fi
    
    # Show nginx error
    echo -e "${BLUE}Nginx test output:${NC}"
    nginx -t 2>&1 || true
    
    exit 1
fi

echo -e "${GREEN}✅ Nginx configuration test passed${NC}"

# Start services
echo -e "${BLUE}Starting services...${NC}"
systemctl start emergency-response
nginx -t && systemctl restart nginx && systemctl enable nginx

# Save configuration
echo "DB_PASSWORD=$DB_PASSWORD" > /etc/emergency-response.conf
echo "PROJECT_ROOT=$PROJECT_ROOT" >> /etc/emergency-response.conf
echo "POSTGRES_VERSION=$PG_VERSION" >> /etc/emergency-response.conf
chmod 600 /etc/emergency-response.conf

# Create backup script
cat > /usr/local/bin/emergency-backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="/var/backups/emergency-response"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="palo_alto_emergency"
DB_USER="emergency_user"

# Load configuration
if [[ -f /etc/emergency-response.conf ]]; then
    source /etc/emergency-response.conf
fi

mkdir -p "$BACKUP_DIR"

# Database backup
if [[ -n "$DB_PASSWORD" ]]; then
    export PGPASSWORD="$DB_PASSWORD"
    pg_dump -h localhost -U "$DB_USER" "$DB_NAME" --no-password | gzip > "$BACKUP_DIR/database_$DATE.sql.gz"
fi

# Application backup
if [[ -n "$PROJECT_ROOT" ]] && [[ -d "$PROJECT_ROOT" ]]; then
    tar -czf "$BACKUP_DIR/application_$DATE.tar.gz" \
        --exclude='node_modules' \
        --exclude='logs' \
        --exclude='.git' \
        -C "$(dirname "$PROJECT_ROOT")" "$(basename "$PROJECT_ROOT")"
fi

# Keep only last 30 days of backups
find "$BACKUP_DIR" -type f -mtime +30 -delete

echo "Backup completed: $DATE"
BACKUPEOF

chmod +x /usr/local/bin/emergency-backup.sh

# Add to crontab for daily backups at 2 AM
(crontab -l 2>/dev/null | grep -v emergency-backup; echo "0 2 * * * /usr/local/bin/emergency-backup.sh") | crontab -

# Wait for services to fully start
sleep 10

# Verify services are running
echo -e "${BLUE}Verifying services...${NC}"

if systemctl is-active --quiet $PG_SERVICE; then
    echo -e "${GREEN}✅ PostgreSQL $PG_VERSION is running${NC}"
else
    echo -e "${RED}❌ PostgreSQL failed to start${NC}"
fi

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx is running${NC}"  
else
    echo -e "${RED}❌ Nginx failed to start${NC}"
    echo "Checking nginx error log:"
    tail -n 10 /var/log/nginx/error.log || true
fi

if systemctl is-active --quiet emergency-response; then
    echo -e "${GREEN}✅ Emergency Response System is running${NC}"
else
    echo -e "${RED}❌ Emergency Response System failed to start${NC}"
    echo "Checking service status:"
    systemctl status emergency-response --no-pager || true
    echo "Checking logs:"
    journalctl -u emergency-response -n 20 --no-pager || true
fi

# Test API health
sleep 5
API_HEALTH=$(curl -s -f http://localhost:3000/api/health || echo "FAILED")
if [[ "$API_HEALTH" != "FAILED" ]]; then
    echo -e "${GREEN}✅ API health check passed${NC}"
else
    echo -e "${YELLOW}⚠️ API health check failed, but service may still be starting${NC}"
fi

echo -e "${GREEN}✅ Installation completed!${NC}"
echo "=============================================="
echo -e "${BLUE}System Information:${NC}"
echo "🌐 Web Interface: http://$(hostname -I | awk '{print $1}')"
echo "📊 API Health Check: http://$(hostname -I | awk '{print $1}'):3000/api/health"
echo "🔧 Nginx Health Check: http://$(hostname -I | awk '{print $1}')/health"
echo "🗄️ Database: PostgreSQL $PG_VERSION with PostGIS"
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
echo -e "${BLUE}Troubleshooting:${NC}"
echo "• Service logs: sudo journalctl -u emergency-response -f"
echo "• Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo "• Test API: curl http://localhost:3000/api/health"
echo "• Test Database: psql -h localhost -d palo_alto_emergency -U emergency_user -c 'SELECT 1;'"
echo ""

if systemctl is-active --quiet emergency-response && systemctl is-active --quiet nginx && systemctl is-active --quiet $PG_SERVICE; then
    echo -e "${GREEN}🚨 All services running - Emergency Response System Ready! 🚨${NC}"
else
    echo -e "${YELLOW}⚠️ Some services may need attention. Check the status above.${NC}"
    echo -e "${YELLOW}Run: sudo journalctl -u emergency-response -f${NC}"
fi
echo "=============================================="
