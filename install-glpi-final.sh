#!/usr/bin/env bash
# install-glpi-final.sh
# Post-install steps: move to /, set GLPI_VAR_DIR, configure Apache

set -euo pipefail

GLPI_DIR="/var/www/glpi"
GLPI_DATA_DIR="/var/lib/glpi-data"
APACHE_SITE_NAME="glpi.conf"
APACHE_USER="www-data"
APACHE_GROUP="www-data"

if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root oder mit sudo ausführen."
  exit 1
fi

echo "----------------------------------------"
echo " GLPI Finalizer (/ -> ${GLPI_DIR}/public)"
echo "----------------------------------------"

if [[ ! -d "$GLPI_DIR" ]]; then
  echo "FEHLER: GLPI-Verzeichnis $GLPI_DIR existiert nicht."
  exit 1
fi

# /install entfernen (sollte nach Web-Install nicht mehr gebraucht werden)
if [[ -d "${GLPI_DIR}/install" ]]; then
  echo "-> Entferne Installationsverzeichnis ${GLPI_DIR}/install"
  rm -rf "${GLPI_DIR}/install"
fi

# Datenverzeichnis existiert schon? Sonst anlegen.
mkdir -p "$GLPI_DATA_DIR"
chown -R "$APACHE_USER:$APACHE_GROUP" "$GLPI_DATA_DIR"

# GLPI_VAR_DIR anpassen: in config/define.php
DEFINE_FILE="${GLPI_DIR}/config/define.php"
if [[ -f "$DEFINE_FILE" ]]; then
  echo "-> Setze GLPI_VAR_DIR in ${DEFINE_FILE} auf ${GLPI_DATA_DIR}"
  # einfache Variante: falls Konstante existiert, ersetzen, sonst anhängen
  if grep -q "GLPI_VAR_DIR" "$DEFINE_FILE"; then
    sed -i "s#define('GLPI_VAR_DIR'.*#define('GLPI_VAR_DIR', '${GLPI_DATA_DIR}');#g" "$DEFINE_FILE"
  else
    echo "define('GLPI_VAR_DIR', '${GLPI_DATA_DIR}');" >>"$DEFINE_FILE"
  fi
else
  echo "WARNUNG: ${DEFINE_FILE} nicht gefunden – bitte manuell prüfen."
fi

# Apache vHost auf /var/www/glpi/public umstellen
echo "-> Konfiguriere Apache vHost für GLPI-Root /"

cat >/etc/apache2/sites-available/${APACHE_SITE_NAME} <<EOF
<VirtualHost *:80>
    ServerName localhost

    DocumentRoot ${GLPI_DIR}/public

    <Directory ${GLPI_DIR}/public>
        Require all granted
        AllowOverride All
        Options FollowSymLinks
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF

a2enmod rewrite
a2ensite "${APACHE_SITE_NAME}"
systemctl reload apache2

chown -R "$APACHE_USER:$APACHE_GROUP" "$GLPI_DIR"

echo "----------------------------------------"
echo "GLPI ist nun über http://<dein-server>/ erreichbar."
echo "Datenverzeichnis: ${GLPI_DATA_DIR}"
echo "----------------------------------------"
