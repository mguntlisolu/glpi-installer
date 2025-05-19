#!/bin/bash

echo "GLPI Installer with PHP 8.3 - Clean public root setup"

read -p "Enter the MySQL username for GLPI: " DB_USER
read -s -p "Enter the MySQL password for $DB_USER: " DB_PASS
echo ""
read -p "Enter the domain name (e.g. localhost or inventory.example.com): " DOMAIN

# System update
sudo apt update && sudo apt upgrade -y

# Add PHP 8.3 repository
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install Apache, MySQL, PHP and modules
sudo apt install -y apache2 mysql-server unzip wget \
php8.3 php8.3-cli php8.3-common php8.3-mysql php8.3-curl php8.3-gd \
php8.3-intl php8.3-xml php8.3-mbstring php8.3-zip php8.3-bz2 \
php8.3-pspell php8.3-tidy php8.3-imap php8.3-xsl php8.3-ldap php8.3-imagick \
php-apcu php-cas php-pear libapache2-mod-php8.3

# Create MySQL database and user
sudo mysql <<EOF
CREATE DATABASE glpidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON glpidb.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Clean web root
sudo rm -rf /var/www/html/*

# Download and extract GLPI directly into web root
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.14/glpi-10.0.14.tgz
tar -xvzf glpi-10.0.14.tgz
sudo mv glpi/* /var/www/html/

# Copy default .htaccess into /public if missing
if [ ! -f /var/www/html/public/.htaccess ]; then
  sudo cp /var/www/html/.htaccess /var/www/html/public/.htaccess
fi

# Create secure data directory
sudo mkdir -p /var/lib/glpi-data
sudo chown -R www-data:www-data /var/lib/glpi-data

# Update GLPI_VAR_DIR
sudo sed -i "s|define('GLPI_VAR_DIR'.*|define('GLPI_VAR_DIR', '/var/lib/glpi-data');|" /var/www/html/inc/define.php

# Permissions
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Apache config
sudo bash -c "cat > /etc/apache2/sites-available/glpi.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAdmin admin@$DOMAIN
    DocumentRoot /var/www/html/public

    <Directory /var/www/html/public>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF"

# Enable site and mod_rewrite
sudo a2dissite 000-default.conf
sudo a2ensite glpi.conf
sudo a2enmod rewrite

# Add ServerName globally (if missing)
if ! grep -q "^ServerName" /etc/apache2/apache2.conf; then
    echo "ServerName $DOMAIN" | sudo tee -a /etc/apache2/apache2.conf
fi

# Enable secure session settings
sudo sed -i "s/^;*session.cookie_httponly.*/session.cookie_httponly = On/" /etc/php/8.3/apache2/php.ini

# Restart Apache
sudo systemctl restart apache2

# Info output
echo ""
echo "GLPI has been installed under /var/www/html and configured"
echo "Open http://$DOMAIN/install.php to begin the web-based installation"
echo "Do not remove the /install directory until the setup is complete"
