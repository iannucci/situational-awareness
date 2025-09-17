#!/bin/bash

# API example
# http://host:3000/api/v1/incidents/active

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAME="situational-awareness"
APP_DIR="/opt/$NAME"
UNIT_FILE="/etc/systemd/system/$NAME.service"
ETC_DIR="/etc/$NAME"
SCHEMA_TMP="/tmp/$NAME_schema.sql"

DB_USER='situational_awareness_user'
DB_PASSWORD='none'
DB_HOST='pa-sitrep.local.mesh'
DB_PORT=5432
DB_NAME='situational_awareness'

echo -e "${BLUE}🚨 Situational Awareness System Installer 🚨${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Install Situational Awareness system."
  echo ""
  echo "Options:"
  echo "  --user NAME         Specify the database username (default $DB_USER)"
  echo "  --password PW       Specify the password for the database user (default $DB_PASSWORD)"
  echo "  --host HOST         Specify the database host (default $DB_HOST)"
  echo "  --port PORT         Specify the port (default $DB_PORT)"
  echo "  --database DBNAME   Specify the name of the database (default $DB_NAME)"
  echo ""
  echo "Example:"
  echo "  $0 --user sauser --password foobar"
  exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --user)
            DB_USER="$2"
            shift
            ;;
        --password)
            ESCAPED_STRING=$(echo "$2" | sed "s/'/''/g")
            DB_PASSWORD=$ESCAPED_STRING
            echo "Password is set to $ESCAPED_STRING"
            shift
            ;;
        --host)
            DB_HOST="$2"
            shift
            ;;
        --port)
            DB_PORT="$2"
            shift
            ;;
        --database)
            DB_NAME="$2"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
    shift # Shift past the current argument (option or flag)
done

if [ "$DB_PASSWORD" == "'none'" ]; then
    echo -e "${RED}Must specify a --password${NC}"
    exit 1
fi

echo "Creating app dir at $APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo mkdir -p "$ETC_DIR"

echo "Copying project files"
sudo cp -r database "$APP_DIR/"
sudo cp -r src "$APP_DIR/"
# sudo cp nginx.conf "$ETC_DIR/"

# FIXED: Get the absolute path of the project directory
# PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# FIXED: Verify we're in the correct directory and all files exist
if [[ ! -f "$APP_DIR/database/schema.sql" ]]; then
    echo -e "${RED}Error: database/schema.sql not found at $APP_DIR/database/schema.sql${NC}"
    echo -e "${YELLOW}This usually means:${NC}"
    echo -e "${YELLOW}1. The project generator didn't complete successfully${NC}"
    echo -e "${YELLOW}2. You're running install.sh from the wrong directory${NC}"
    echo -e "${YELLOW}3. Some files were accidentally deleted${NC}"
    echo ""
    echo -e "${BLUE}Current directory structure:${NC}"
    ls -la "$APP_DIR/" 2>/dev/null || echo "Cannot access $APP_DIR"
    echo ""
    echo -e "${BLUE}Checking for key files:${NC}"
    echo -n "database/ directory: "
    [[ -d "$APP_DIR/database" ]] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}"
    echo -n "src/api/ directory: "
    [[ -d "$APP_DIR/src/api" ]] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}"
    echo -n "src/web/ directory: "
    [[ -d "$APP_DIR/src/web" ]] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}"
    echo ""
    echo -e "${YELLOW}To fix this issue:${NC}"
    echo -e "${YELLOW}1. Re-run the project generator: ./generate-project.sh${NC}"
    echo -e "${YELLOW}2. Or create the missing schema file manually (see below)${NC}"
    echo -e "${YELLOW}3. Make sure you're in the project root directory${NC}"
    
    echo -e "${RED}Please re-run the project generator to create all missing files${NC}"
    exit 1
fi

# This allows psql to access this file
rm -f "$SCHEMA_TMP"
cp "$APP_DIR/database/schema.sql" "$SCHEMA_TMP"

if [[ ! -f "$APP_DIR/src/api/package.json" ]]; then
    echo -e "${RED}Error: API package.json not found at $APP_DIR/src/api/package.json${NC}"
    exit 1
fi

echo -e "${BLUE}Installing system packages...${NC}"
if [[ -f /etc/debian_version ]]; then
    # Ubuntu/Debian - Install PostgreSQL 16 (more stable than 17)
    apt update
    rm -f /usr/share/keyrings/postgresql-archive-keyring.gpg
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
# DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

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
echo -e "${BLUE}Creating database...${NC}"
sudo -u postgres psql -c "DROP database IF EXISTS $DB_NAME WITH (FORCE);" || true
sudo -u postgres createdb $DB_NAME || echo -e "${YELLOW}Database may already exist${NC}"
sudo -u postgres psql -c "DROP OWNED BY $DB_USER;" || true

# echo -e "${BLUE}Dropping user $DB_USER if exists...${NC}"
# sudo -u postgres psql -c "SELECT 'DROP OWNED BY $DB_USER' FROM pg_roles WHERE rolname = '$DB_USER' \gexec"
# echo $drop_owned_by_command | psql -U postgres $DB_NAME

sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" || true

echo -e "${BLUE}Creating user $DB_USER...${NC}"
echo "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" 
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" || true
sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;" || true

# Grant schema permissions
echo -e "${BLUE}Setting up database permissions...${NC}"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;" || true
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;" || true
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;" || true
sudo -u postgres psql -d $DB_NAME -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;" || true
sudo -u postgres psql -d $DB_NAME -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;" || true

echo -e "${BLUE}Loading database schema from $SCHEMA_TMP...${NC}"
if [[ -f "$SCHEMA_TMP" ]]; then
    sudo -u postgres psql -d $DB_NAME -f "$SCHEMA_TMP" || echo -e "${YELLOW}Schema loading completed with warnings${NC}"
else
    echo -e "${RED}Error: Schema file not found at $SCHEMA_TMP${NC}"
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
cd "$APP_DIR/src/api"

if [[ ! -f "package.json" ]]; then
    echo -e "${RED}Error: package.json not found in $APP_DIR/src/api/package.json${NC}"
    exit 1
fi

npm install --omit=dev
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: npm install failed${NC}"
    exit 1
fi

cd "$APP_DIR"

echo -e "${BLUE}Creating system service...${NC}"
API_DIR="$APP_DIR/src/api"

# Verify the API directory exists and has the server file
if [[ ! -f "$API_DIR/server.js" ]]; then
    echo -e "${RED}Error: server.js not found at $API_DIR/server.js${NC}"
    exit 1
fi

# Create logs directory with proper permissions
mkdir -p "$APP_DIR/logs"
chmod 755 "$APP_DIR/logs"

# FIXED: Create environment file
cat > "$APP_DIR/.env" << ENVFILE
NODE_ENV=production
PORT=3000
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_SSL=false
DB_CONNECTION_TIMEOUT=30000
ENVFILE

chmod 600 "$APP_DIR/.env"

# Create systemd service file with proper environment handling
cat > /etc/systemd/system/$NAME.service << SERVICEFILE
[Unit]
Description=Situational Awareness System
Documentation=https://github.com/iannucci/situational-awareness
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
SyslogIdentifier=$NAME

# FIXED: Environment file
EnvironmentFile=$APP_DIR/.env

# Security restrictions
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$APP_DIR/logs

[Install]
WantedBy=multi-user.target
SERVICEFILE

systemctl daemon-reload
systemctl enable $NAME

echo -e "${BLUE}Configuring Nginx...${NC}"
WEB_DIR="$APP_DIR/src/web"

if [[ ! -d "$WEB_DIR" ]]; then
    echo -e "${RED}Error: Web directory not found at $WEB_DIR${NC}"
    exit 1
fi

# Copy web files to standard location
WEB_ROOT="/var/www/$NAME"
echo -e "${BLUE}Setting up web root at $WEB_ROOT...${NC}"
mkdir -p "$WEB_ROOT"
cp -r "$WEB_DIR/"* "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null || chown -R nginx:nginx "$WEB_ROOT" 2>/dev/null || true
chmod -R 644 "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;

# Create nginx configuration specifically for system installation
echo -e "${BLUE}Creating nginx configuration for system installation...${NC}"

# Create nginx config for system installation (different from Docker version)      
cat > /tmp/situational-awareness-nginx.conf << NGINXCONF
server {
    listen 80;
    server_name \$host;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Main application - serve static files
    location / {
        root /var/www/$NAME;
        index index.html index.htm;
        try_files \$uri \$uri/ /index.html;
        
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
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;

        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host pa-sitrep.local.mesh;
        
        # CORS headers for API
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
        
        # Handle OPTIONS requests for CORS
        if (\$request_method = 'OPTIONS') {
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
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host pa-sitrep.local.mesh;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
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
    cp /tmp/situational-awareness-nginx.conf /etc/nginx/sites-available/$NAME
    
    # Enable site and disable default
    ln -sf /etc/nginx/sites-available/$NAME /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    echo -e "${GREEN}✅ Configured nginx (Ubuntu/Debian style)${NC}"
else
    # RHEL/CentOS style
    cp /tmp/situational-awareness-nginx.conf /etc/nginx/conf.d/$NAME.conf
    
    # Disable default server block in main config if it exists
    if [[ -f /etc/nginx/nginx.conf ]]; then
        # Comment out any existing server blocks in main config
        sed -i '/^[[:space:]]*server[[:space:]]*{/,/^[[:space:]]*}/s/^/#/' /etc/nginx/nginx.conf 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Configured nginx (RHEL/CentOS style)${NC}"
fi

# Clean up temporary file
rm -f /tmp/situational-awareness-nginx.conf

# Test nginx configuration
echo -e "${BLUE}Testing nginx configuration...${NC}"
if ! nginx -t; then
    echo -e "${RED}Nginx configuration test failed${NC}"
    echo -e "${YELLOW}Checking nginx configuration...${NC}"
    
    # Show the configuration we created
    if [[ -f /etc/nginx/sites-available/$NAME ]]; then
        echo -e "${BLUE}Configuration file: /etc/nginx/sites-available/$NAME{NC}"
        head -20 /etc/nginx/sites-available/$NAME
    elif [[ -f /etc/nginx/conf.d/$NAME.conf ]]; then
        echo -e "${BLUE}Configuration file: /etc/nginx/conf.d/$NAME.conf${NC}"
        head -20 /etc/nginx/conf.d$NAME.conf
    fi
    
    # Show nginx error
    echo -e "${BLUE}Nginx test output:${NC}"
    nginx -t 2>&1 || true
    
    exit 1
fi

echo -e "${GREEN}✅ Nginx configuration test passed${NC}"

# Start services
echo -e "${BLUE}Restarting services...${NC}"
systemctl restart $NAME
nginx -t
echo -e "${BLUE}Restarting nginx...${NC}"
systemctl restart nginx
systemctl enable nginx

# Save configuration
echo "DB_PASSWORD=$DB_PASSWORD" > $ETC_DIR/$NAME.conf
echo "PROJECT_ROOT=$APP_DIR" >> $ETC_DIR/$NAME.conf
echo "POSTGRES_VERSION=$PG_VERSION" >> $ETC_DIR/$NAME.conf
chmod 600 $ETC_DIR/$NAME.conf

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

if systemctl is-active --quiet $NAME; then
    echo -e "${GREEN}✅ Situational Awareness System is running${NC}"
else
    echo -e "${RED}❌ Situational Awareness System failed to start${NC}"
    echo "Checking service status:"
    systemctl status $NAME --no-pager || true
    echo "Checking logs:"
    journalctl -u $NAME -n 20 --no-pager || true
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
echo "📁 Project Root: $APP_DIR"
echo "📁 Web Root: $WEB_ROOT"
echo "🔑 Database Password: $DB_PASSWORD"
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo "• Start:   sudo systemctl start $NAME"
echo "• Stop:    sudo systemctl stop $NAME"
echo "• Restart: sudo systemctl restart $NAME"
echo "• Status:  sudo systemctl status $NAME"
echo "• Logs:    sudo journalctl -u $NAME -f"
echo ""
echo -e "${BLUE}Troubleshooting:${NC}"
echo "• Service logs: sudo journalctl -u $NAME -f"
echo "• Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo "• Test API: curl http://localhost:3000/api/health"
echo "• Test Database: psql -h localhost -d $DB_NAME -U $DB_USER -c 'SELECT 1;'"
echo ""

if systemctl is-active --quiet $NAME && systemctl is-active --quiet nginx && systemctl is-active --quiet $PG_SERVICE; then
    echo -e "${GREEN}🚨 All services running - Situational Awareness System Ready! 🚨${NC}"
else
    echo -e "${YELLOW}⚠️ Some services may need attention. Check the status above.${NC}"
    echo -e "${YELLOW}Run: sudo journalctl -u $NAME -f${NC}"
fi
echo "=============================================="
