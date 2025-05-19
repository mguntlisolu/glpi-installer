#!/bin/bash

echo "Finalizing GLPI setup and switching to root path..."

# 1. Option: install/ Verzeichnis löschen (nur nach manuellem Setup!)
if [ -d /var/www/glpi/install ]; then
    echo "Removing install/ directory..."
    sudo rm -rf /var/www/glpi/install
fi

# 2. Optional: Datenverzeichnis auslagern
if [ ! -d /var/lib/glpi-data ]; then
    echo "Creating external GLPI data directory..."
    sudo mkdir -p /var/lib/glpi-data
    sudo chown -R www-data:www-data /var/lib/glpi-data
fi

# 3. GLPI_VAR_DIR in define.php anpassen
if grep -q "define('GLPI_VAR_DIR'" /var/www/glpi/inc/define.php; then
    sudo sed -i "s|define('GLPI_VAR_DIR'.*|define('GLPI_VAR_DIR', '/var/lib/glpi-data');|" /var/www/glpi/inc/define.php
fi

# 4. Apache-VHost für Root-Zugriff auf /var/www/glpi/public
echo "Configuring Apache virtual host for GLPI under root path..."

sudo bash -c "cat > /etc/apache2/sites-available/glpi.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/glpi/public

    <Directory /var/www/glpi/public>
        Require all granted
        RewriteEngine On

        # Pass Authorization header (required for API, CalDAV, etc.)
        RewriteCond %{HTTP:Authorization} ^(.+)\$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

        # Route all non-file requests to GLPI router
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)\$ index.php [QSA,L]
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF"

# 5. Apache Reload
echo "Reloading Apache..."
sudo systemctl reload apache2

echo ""
echo "GLPI is now configured to run under http://localhost"
echo "Please ensure the install/ directory is removed"
echo "Setup complete. You can now log in to GLPI."
