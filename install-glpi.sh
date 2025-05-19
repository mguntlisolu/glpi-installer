#!/bin/bash

echo "GLPI Installer (Phase 1 - Setup under /glpi path)"

# Eingabe durch Benutzer
read -p "Enter MySQL username for GLPI: " DB_USER
read -s -p "Enter password for user $DB_USER: " DB_PASS
echo ""
read -p "Enter domain (e.g. localhost or inventory.example.com): " DOMAIN

# System vorbereiten
sudo apt update && sudo apt upgrade -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Apache, MySQL, PHP und Erweiterungen
sudo apt install -y apache2 mysql-server unzip wget \
php8.3 php8.3-cli php8.3-common php8.3-mysql php8.3-curl php8.3-gd \
php8.3-intl php8.3-xml php8.3-mbstring php8.3-zip php8.3-bz2 \
php8.3-pspell php8.3-tidy php8.3-imap php8.3-xsl php8.3-ldap \
php8.3-imagick php-apcu php-cas php-pear libapache2-mod-php8.3

# Datenbank erstellen
sudo mysql <<EOF
CREATE DATABASE glpidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON glpidb.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# GLPI herunterladen und entpacken
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.14/glpi-10.0.14.tgz
tar -xvzf glpi-10.0.14.tgz
sudo mv glpi /var/www/glpi

# Rechte setzen
sudo chown -R www-data:www-data /var/www/glpi
sudo find /var/www/glpi -type d -exec chmod 755 {} \;
sudo find /var/www/glpi -type f -exec chmod 644 {} \;

# Apache Konfiguration für Setup über /glpi (Alias)
sudo bash -c "cat > /etc/apache2/sites-available/glpi.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www

    Alias /glpi /var/www/glpi

    <Directory /var/www/glpi>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF"

# Apache aktivieren
sudo a2dissite 000-default.conf
sudo a2ensite glpi
sudo a2enmod rewrite

# ServerName optional ergänzen
if ! grep -q "^ServerName" /etc/apache2/apache2.conf; then
    echo "ServerName $DOMAIN" | sudo tee -a /etc/apache2/apache2.conf
fi

# Apache neu starten
sudo systemctl reload apache2

echo ""
echo "GLPI installed under /var/www/glpi"
echo "Open http://$DOMAIN/glpi/install/install.php in your browser to start the web-based setup"
echo "After completing the installation, run 'glpi-finalize.sh' to move GLPI to root path"
