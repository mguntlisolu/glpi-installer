#!/bin/bash

echo "GLPI cleanup script - removing all GLPI components"

# Prompt for MySQL username used during setup
read -p "Enter the MySQL username to remove (e.g. glpiuser): " DB_USER

# Step 1: Disable and remove Apache GLPI site
if [ -f /etc/apache2/sites-available/glpi.conf ]; then
  echo "Disabling and removing Apache site glpi.conf"
  sudo a2dissite glpi.conf
  sudo rm /etc/apache2/sites-available/glpi.conf
  sudo systemctl reload apache2
fi

# Step 2: Remove GLPI files from web root
if [ -d /var/www/html ]; then
  echo "Removing /var/www/html contents"
  sudo rm -rf /var/www/html/*
fi

# Step 3: Remove external GLPI data directory
if [ -d /var/lib/glpi-data ]; then
  echo "Removing /var/lib/glpi-data"
  sudo rm -rf /var/lib/glpi-data
fi

# Step 4: Drop GLPI database and user
echo "Dropping MySQL database glpidb and user $DB_USER"
sudo mysql <<EOF
DROP DATABASE IF EXISTS glpidb;
DROP USER IF EXISTS '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Step 5: Optionally remove global ServerName
if grep -q "^ServerName" /etc/apache2/apache2.conf; then
  echo "Removing ServerName from apache2.conf"
  sudo sed -i '/^ServerName .*/d' /etc/apache2/apache2.conf
  sudo systemctl restart apache2
fi

echo "GLPI environment cleaned up successfully"
