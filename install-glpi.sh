#!/bin/bash

echo "GLPI Installer with PHP 8.3 (secure setup)"

# Prompt for credentials and domain
read -p "Enter the MySQL username for GLPI: " DB_USER
read -s -p "Enter the MySQL password for $DB_USER: " DB_PASS
echo ""
read -p "Enter the domain name (e.g. glpi.example.com): " DOMAIN

# Update system
sudo apt update && sudo apt upgrade -y

# Add PHP 8.3 repository
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install required packages
sudo apt install -y apache2 mysql-server unzip wget \
php8.3 php8.3-cli php8.3-common php8.3-mysql php8.3-curl php8.3-gd \
php8.3-intl php8.3-xml php8.3-mbstring php8.3-zip php8.3-bz2 \
php8.3-pspell php8.3-tidy php8.3-imap php8.3-xsl php8.3-ldap php8.3-imagick \
php-apcu php-cas php-pear libapache2-mod-php8.3

# Create GLPI database and user
sudo mysql <<EOF
CREATE DATABASE glpidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON glpidb.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Download and extract GLPI
cd /tmp/
wget https://github.com/glpi-project/glpi/releases/download/10.0.14/glpi-10.0.14.tgz
tar -xvzf glpi-10.0.14.tgz
sudo mv glpi /var/www/html/

# Create a secure data directory outside the web root
sudo mkdir -p /var/lib/glpi-files
sudo chown -R www-data:www-data /var/lib/glpi-files

# Move GLPI to separate directory and use /public as web root
sudo mv /var/www/html/glpi /var/www/html/glpi-full
sudo ln -s /var/www/html/glpi-full/public /var/www/html/glpi

# Adjust GLPI_VAR_DIR in define.php
sudo sed -i "s|define('GLPI_VAR_DIR'.*|define('GLPI_VAR_DIR', '/var/lib/glpi-files');|" /var/www/html/glpi-full/inc/define.php

# Set permissions
sudo chown -R www-data:www-data /var/www/html/glpi-full
sudo find /var/www/html/glpi-full -type d -exec chmod 755 {} \;
sudo find /var/www/html/glpi-full -type f -exec chmod 644 {} \;

# Create Apache virtual host for GLPI
sudo bash -c "cat > /etc/apache2/sites-available/glpi.conf <<EOF
<VirtualHost *:80>
    ServerAdmin admin@$DOMAIN
    DocumentRoot /var/www/html/glpi
    ServerName $DOMAIN

    <Directory /var/www/html/glpi>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF"

# Add ServerName globally to suppress Apache warning
if ! grep -q "^ServerName" /etc/apache2/apache2.conf; then
    echo "ServerName $DOMAIN" | sudo tee -a /etc/apache2/apache2.conf
fi

# Enable security option for PHP sessions
sudo sed -i "s/^;*session.cookie_httponly.*/session.cookie_httponly = On/" /etc/php/8.3/apache2/php.ini

# Enable site and necessary modules
sudo a2ensite glpi
sudo a2enmod rewrite
sudo systemctl restart apache2

# Final message
echo ""
echo "GLPI has been installed and configured."
echo "Access it at: http://$DOMAIN"
echo "Complete the setup through the web interface."
