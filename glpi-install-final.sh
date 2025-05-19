#!/bin/bash

echo "Finalizing GLPI setup - switching to root path"

# Install-Verzeichnis löschen (manuell bestätigen)
if [ -d /var/www/glpi/install ]; then
  echo "Removing install/ directory..."
  sudo rm -rf /var/www/glpi/install
fi

# GLPI_VAR_DIR auslagern (optional)
sudo mkdir -p /var/lib/glpi-data
sudo chown -R www-data:www-data /var/lib/glpi-data
sudo sed -i "s|define('GLPI_VAR_DIR'.*|define('GLPI_VAR_DIR', '/var/lib/glpi-data');|" /var/www/glpi/inc/define.php

# Apache auf public umstellen
sudo bash -c "cat > /etc/apache2/sites-available/glpi.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    ServerAdmin admin@localhost
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

# Apache neuladen
sudo systemctl reload apache2

echo ""
echo "GLPI is now available at http://localhost"
