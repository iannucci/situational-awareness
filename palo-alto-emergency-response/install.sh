#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚨 Palo Alto Emergency Response System Installer 🚨${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${BLUE}Installing system packages...${NC}"
if [[ -f /etc/debian_version ]]; then
    apt update
    apt install -y postgresql-14 nodejs npm nginx git curl
else
    echo "Please install PostgreSQL 14, Node.js, npm, nginx, and git manually"
    exit 1
fi

echo -e "${BLUE}Setting up PostgreSQL...${NC}"
systemctl start postgresql
systemctl enable postgresql

DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

sudo -u postgres createdb palo_alto_emergency || true
sudo -u postgres psql -c "CREATE USER emergency_user WITH PASSWORD '$DB_PASSWORD';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE palo_alto_emergency TO emergency_user;"
sudo -u postgres psql -d palo_alto_emergency -f database/schema.sql || true

echo -e "${BLUE}Installing Node.js dependencies...${NC}"
cd src/api && npm install --production && cd ../..

echo -e "${BLUE}Creating system service...${NC}"
cat > /etc/systemd/system/emergency-response.service << SERVICEFILE
[Unit]
Description=Emergency Response System
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=$(pwd)/src/api
ExecStart=/usr/bin/node server.js
Restart=always
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=DB_HOST=localhost
Environment=DB_NAME=palo_alto_emergency
Environment=DB_USER=emergency_user
Environment=DB_PASSWORD=$DB_PASSWORD

[Install]
WantedBy=multi-user.target
SERVICEFILE

systemctl daemon-reload
systemctl enable emergency-response
systemctl start emergency-response

echo -e "${BLUE}Configuring Nginx...${NC}"
cp nginx.conf /etc/nginx/sites-available/emergency-response 2>/dev/null || cp nginx.conf /etc/nginx/conf.d/emergency-response.conf
sed -i 's|/usr/share/nginx/html|'$(pwd)'/src/web|g' /etc/nginx/sites-available/emergency-response 2>/dev/null || sed -i 's|/usr/share/nginx/html|'$(pwd)'/src/web|g' /etc/nginx/conf.d/emergency-response.conf

if [[ -d /etc/nginx/sites-enabled ]]; then
    ln -sf /etc/nginx/sites-available/emergency-response /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
fi

nginx -t && systemctl restart nginx && systemctl enable nginx

echo "DB_PASSWORD=$DB_PASSWORD" > /etc/emergency-response.conf
chmod 600 /etc/emergency-response.conf

echo -e "${GREEN}✅ Installation completed!${NC}"
echo "🌐 Web: http://$(hostname -I | awk '{print $1}')"
echo "📊 API: http://$(hostname -I | awk '{print $1}'):3000/api/health"
echo "🔑 DB Password: $DB_PASSWORD"
