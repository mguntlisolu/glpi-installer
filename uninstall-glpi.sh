#!/bin/bash

echo "Full GLPI, MySQL, Apache site and data cleanup"

read -p "Enter the MySQL username to remove (e.g. glpiuser): " DB_USER

# Stop MySQL
echo "Stopping MySQL service"
sudo systemctl stop mysql

# Purge MySQL packages
echo "Removing MySQL packages"
sudo apt purge --remove mysql-server mysql-client mysql-common -y
sudo apt autoremove -y
sudo apt autoclean

# Delete MySQL files and logs
echo "Deleting MySQL config and data directories"
sudo rm -rf /etc/mysql /var/lib/mysql
sudo rm -rf /var/log/mysql*

# Remove MySQL system user and group
echo "Removing MySQL system user and group (if they exist)"
sudo deluser mysql 2>/dev/null
sudo delgroup mysql 2>/dev/null

# Drop database and user if anything remains
echo "Dropping database glpidb and user $DB_USER (if still present)"
sudo mysql <<EOF
DROP DATABASE IF EXISTS glpidb;
DROP USER IF EXISTS '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Remove GLPI web directory
echo "Removing GLPI web files"
sudo rm -rf /var/www/html/glpi
sudo rm -rf /var/www/html/*

# Remove GLPI data directory outside webroot
echo "Removing GLPI external data (if exists)"
sudo rm -rf /var/lib/glpi-data

# Remove Apache vhost configuration
echo "Disabling and removing Apache GLPI site"
sudo a2dissite glpi.conf 2>/dev/null
sudo rm -f /etc/apache2/sites-available/glpi.conf
sudo systemctl reload apache2

# Optional: remove ServerName directive from apache2.conf
# echo "Cleaning up global ServerName from apache2.conf"
# sudo sed -i '/^ServerName .*/d' /etc/apache2/apache2.conf
# sudo systemctl restart apache2

echo "GLPI and all related components have been removed"
