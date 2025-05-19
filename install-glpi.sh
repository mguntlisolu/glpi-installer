#!/bin/bash

echo "=== GLPI Installer mit PHP 8.3 ==="

# 1. Benutzereingaben erfassen
read -p "Gib den MySQL-Benutzernamen für GLPI ein: " DB_USER
read -s -p "Gib das MySQL-Passwort für $DB_USER ein: " DB_PASS
echo ""
read -p "Gib den Domainnamen ein (z.B. glpi.example.com): " DOMAIN

# 2. System aktualisieren
echo "→ System wird aktualisiert..."
sudo apt update && sudo apt upgrade -y

# 3. PHP 8.3 installieren (über PPA falls nötig)
echo "→ PHP 8.3 und Apache installieren..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

sudo apt install -y apache2 mysql-server unzip wget \
php8.3 php8.3-cli php8.3-common php8.3-mysql php8.3-curl php8.3-gd \
php8.3-intl php8.3-xml php8.3-mbstring php8.3-zip php8.3-bz2 \
php8.3-pspell php8.3-tidy php8.3-imap php8.3-xsl php8.3-ldap \
php8.3-imagick php-apcu php-cas php-pear libapache2-mod-php8.3

# 4. Datenbank einrichten
echo "→ MySQL-Datenbank und Benutzer einrichten..."
sudo mysql <<EOF
CREATE DATABASE glpidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON glpidb.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 5. GLPI herunterladen
echo "→ GLPI herunterladen..."
cd /tmp/
wget https://github.com/glpi-project/glpi/releases/download/10.0.14/glpi-10.0.14.tgz
tar -xvzf glpi-10.0.14.tgz
sudo mv glpi /var/www/html/

# 6. Rechte setzen
echo "→ Dateirechte setzen..."
sudo chown -R www-data:www-data /var/www/html/glpi
sudo find /var/www/html/glpi -type d -exec chmod 755 {} \;
sudo find /var/www/html/glpi -type f -exec chmod 644 {} \;

# 7. Apache vHost erstellen
echo "→ Apache-Konfiguration erstellen..."
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

# 8. Apache aktivieren
echo "→ Apache aktivieren und neustarten..."
sudo a2ensite glpi
sudo a2enmod rewrite
sudo systemctl reload apache2

# 9. Optional: HTTPS via Certbot
read -p "Möchtest du HTTPS mit Let's Encrypt aktivieren (j/n)? " SSL_CHOICE
if [[ "$SSL_CHOICE" == "j" || "$SSL_CHOICE" == "J" ]]; then
    echo "→ Certbot installieren und konfigurieren..."
    sudo apt install -y certbot python3-certbot-apache
    sudo certbot --apache -d $DOMAIN
fi

# 10. Fertig
echo ""
echo "✅ GLPI wurde erfolgreich installiert!"
echo "Rufe http://$DOMAIN in deinem Browser auf, um die Einrichtung abzuschließen."
