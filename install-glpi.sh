#!/bin/bash

echo "GLPI Installer with PHP 8.3 based on official documentation"

read -p "Enter the MySQL username for GLPI: " DB_USER
read -s -p "Enter the MySQL password for $DB_USER: " DB_PASS
echo ""
read -p "Enter the domain name (e.g. localhost or inventory.example.com): " DOMAIN

# Update system
sudo apt update && sudo apt upgrade -y

# Add PHP 8.3 support
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install required packages
sudo apt install -y apache2 mysql-server unzip wget \
php8.3 php8.3-cli php8.3-common php8.3-mysql php8.3-curl php8.3-gd \
php8.3-intl php8.3-xml php8.3-mbstring php8.3-zip php8.3-bz2 \
php8.3-pspell php8.3-tidy php8.3-imap php8.3-xsl php8.3-ldap php8.3-imagick \
php-apcu php-cas php-pear libapache2-mod-php8.3

# Create database and user
sudo mysql <<EOF
CREATE DATABASE glpidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON glpidb.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Create clean directory for GLPI
sudo mkdir -p /var/www/glpi
sudo rm -rf /var/www/glpi/*

# Download and extract GLPI
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.14/glpi-10.0.14.tgz
tar -xvzf glpi-10.0.14.tgz
sudo mv glpi/* /var/www/glpi/

# Set data directory outside webroot
sudo mkdir -p /var/lib/glpi-data
sudo chown -R www-data:www-data /var/lib/glpi-data
sudo sed -i "s|define('GLPI_VAR_DIR'.*|define('GLPI_VAR_DIR', '/var/lib/glpi-data');|" /var/www/glpi/inc/define.php

# Set permissions
sudo chown -R www-data:www-data /var/www/glpi
sudo find /var/www/glpi -type d -exec chmod 755 {} \;
sudo find /var/www/glpi -type f -exec chmod 644 {} \;

# Apache vhost config with DocumentRoot = /var/www/glpi/public
sudo bash -c "cat > /etc/apache2/sites-available/glpi.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAdmin admin@$DOMAIN
    DocumentRoot /var/www/glpi/public

    <Directory /var/www/glpi/public>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF"

# Enable Apache site and rewrite module
sudo a2dissite 000-default.conf
sudo a2ensite glpi.conf
sudo a2enmod rewrite

# Set ServerName globally (optional)
if ! grep -q "^ServerName" /etc/apache2/apache2.conf; then
    echo "ServerName $DOMAIN" | sudo tee -a /etc/apache2/apache2.conf
fi

# Improve PHP security
sudo sed -i "s/^;*session.cookie_httponly.*/session.cookie_httponly = On/" /etc/php/8.3/apache2/php.ini

# Restart Apache
sudo systemctl restart apache2

# Final message
echo ""
echo "GLPI has been installed to /var/www/glpi"
echo "Access the installer at: http://$DOMAIN/install/install.php"
echo "After completing the setup, delete the install/ directory manually"
