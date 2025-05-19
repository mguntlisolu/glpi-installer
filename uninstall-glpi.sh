#!/bin/bash

echo "Full GLPI environment cleanup - including Apache, MySQL, PHP and configs"

read -p "Enter the MySQL username to remove (e.g. glpiuser): " DB_USER

# 1. Stop services
sudo systemctl stop apache2 mysql

# 2. Remove Apache GLPI site
sudo a2dissite glpi.conf 2>/dev/null
sudo rm -f /etc/apache2/sites-available/glpi.conf

# 3. Clean web root
sudo rm -rf /var/www/html/*

# 4. Remove GLPI data outside web root
sudo rm -rf /var/lib/glpi-data

# 5. Drop database and user
sudo mysql <<EOF
DROP DATABASE IF EXISTS glpidb;
DROP USER IF EXISTS '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 6. Remove ServerName from apache2.conf
sudo sed -i '/^ServerName .*/d' /etc/apache2/apache2.conf

# 7. Full MySQL cleanup
sudo apt purge --remove mysql-server mysql-client mysql-common -y
sudo rm -rf /etc/mysql /var/lib/mysql /var/log/mysql*

# 8. Full PHP cleanup (only PHP 8.3 here)
sudo apt purge --remove php8.3* libapache2-mod-php8.3 php-pear -y
sudo rm -rf /etc/php

# 9. Optional: Clean Apache configs (keep Apache installed)
sudo rm -f /etc/apache2/sites-enabled/glpi.conf
sudo rm -f /etc/apache2/sites-available/glpi.conf

# 10. Clean up unused packages
sudo apt autoremove -y
sudo apt autoclean

# 11. Restart Apache if kept
sudo systemctl restart apache2 2>/dev/null

echo "Full system cleanup complete. GLPI, MySQL and PHP have been removed"
