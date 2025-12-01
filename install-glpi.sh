#!/usr/bin/env bash
# install-glpi.sh
# Install GLPI 11 on Ubuntu with Apache + MariaDB

set -euo pipefail

# --- CONFIG -------------------------------------------------------------

GLPI_VERSION="11.0.2"
GLPI_ARCHIVE="glpi-${GLPI_VERSION}.tgz"
GLPI_DOWNLOAD_URL="https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/${GLPI_ARCHIVE}"

GLPI_WEB_ROOT="/var/www"
GLPI_DIR="${GLPI_WEB_ROOT}/glpi"
GLPI_DATA_DIR="/var/lib/glpi-data"

APACHE_SITE_NAME="glpi.conf"
APACHE_USER="www-data"
APACHE_GROUP="www-data"

DB_HOST="localhost"
DB_NAME="glpidb"
DB_USER="glpiuser"
DB_PASSWORD="ChangeMe123!"   # <- anpassen!

MYSQL_ROOT_USER="root"
MYSQL_ROOT_PWD_FILE="/root/.mysql_root_pwd"  # optional

# -----------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root oder mit sudo ausführen."
  exit 1
fi

echo "----------------------------------------"
echo " GLPI ${GLPI_VERSION} Installer"
echo "----------------------------------------"

apt-get update

echo "-> Installiere benötigte Pakete (Apache, MariaDB, PHP + Extensions)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apache2 \
  mariadb-server \
  php \
  php-cli \
  php-common \
  php-curl \
  php-gd \
  php-intl \
  php-mbstring \
  php-mysql \
  php-xml \
  php-zip \
  php-bcmath \
  unzip \
  wget

# --- PHP-Version prüfen -------------------------------------------------

PHP_VERSION_RAW="$(php -r 'echo PHP_VERSION;' || echo '0')"
PHP_MAJOR="$(php -r 'echo PHP_MAJOR_VERSION;' || echo '0')"
PHP_MINOR="$(php -r 'echo PHP_MINOR_VERSION;' || echo '0')"

echo "Installierte PHP-Version: $PHP_VERSION_RAW"

if (( PHP_MAJOR < 8 || (PHP_MAJOR == 8 && PHP_MINOR < 2) )); then
  echo "FEHLER: GLPI 11 benötigt PHP >= 8.2. Aktuell: $PHP_VERSION_RAW"
  echo "Bitte PHP-Version aktualisieren (z.B. Ubuntu 24.04 oder PHP-Repo verwenden) und Skript erneut starten."
  exit 1
fi

# --- MariaDB absichern (optional minimal) -------------------------------

echo "-> MariaDB Dienst starten (falls nicht aktiv)..."
systemctl enable mariadb --now

# Root-Passwort optional hinterlegen (wenn du eine non-interactive Variante willst)
if [[ ! -f "$MYSQL_ROOT_PWD_FILE" ]]; then
  echo "Hinweis: Datei $MYSQL_ROOT_PWD_FILE enthält kein Root-Passwort."
  echo "Du kannst sie nachträglich erstellen, um DB-Aufgaben zu automatisieren."
fi

# --- Datenbank + User anlegen ------------------------------------------

echo "-> Erstelle Datenbank und User (falls noch nicht vorhanden)..."

MYSQL_CMD=(mysql -h "$DB_HOST" -u "$MYSQL_ROOT_USER")

if [[ -f "$MYSQL_ROOT_PWD_FILE" ]]; then
  MYSQL_ROOT_PWD="$(<"$MYSQL_ROOT_PWD_FILE")"
  if [[ -n "$MYSQL_ROOT_PWD" ]]; then
    MYSQL_CMD+=("-p$MYSQL_ROOT_PWD")
  fi
fi

"${MYSQL_CMD[@]}" <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

# --- GLPI herunterladen & entpacken ------------------------------------

echo "-> Lade GLPI ${GLPI_VERSION} herunter..."
mkdir -p "$GLPI_WEB_ROOT"
cd "$GLPI_WEB_ROOT"

if [[ -d "$GLPI_DIR" ]]; then
  echo "WARNUNG: Verzeichnis $GLPI_DIR existiert bereits."
  read -r -p "Soll es überschrieben werden? [y/N] " OVERWRITE
  case "$OVERWRITE" in
    y|Y|yes|YES)
      rm -rf "$GLPI_DIR"
      ;;
    *)
      echo "Abgebrochen."
      exit 1
      ;;
  esac
fi

wget -O "$GLPI_ARCHIVE" "$GLPI_DOWNLOAD_URL"
tar xzf "$GLPI_ARCHIVE"
rm "$GLPI_ARCHIVE"

# entpackt in ./glpi
chown -R "$APACHE_USER:$APACHE_GROUP" "$GLPI_DIR"

# --- externes Datenverzeichnis vorab anlegen ---------------------------

mkdir -p "$GLPI_DATA_DIR"
chown -R "$APACHE_USER:$APACHE_GROUP" "$GLPI_DATA_DIR"

# --- Apache für /glpi konfigurieren ------------------------------------

echo "-> Konfiguriere Apache vHost /glpi ..."

cat >/etc/apache2/sites-available/${APACHE_SITE_NAME} <<EOF
<VirtualHost *:80>
    ServerName localhost

    DocumentRoot ${GLPI_DIR}
    <Directory ${GLPI_DIR}>
        AllowOverride All
        Require all granted
    </Directory>

    Alias /glpi ${GLPI_DIR}

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF

a2enmod rewrite
a2ensite "${APACHE_SITE_NAME}"
systemctl reload apache2

# --- Info für den Benutzer ---------------------------------------------

cat <<INFO

----------------------------------------
GLPI ${GLPI_VERSION} wurde vorbereitet.

1. Öffne deinen Browser:
   http://<dein-server>/glpi/install/install.php

2. Verwende folgende Datenbank-Zugangsdaten:
   Host:     ${DB_HOST}
   DB-Name:  ${DB_NAME}
   User:     ${DB_USER}
   Passwort: ${DB_PASSWORD}

3. Nach Abschluss der Web-Installation:
   -> 'install-glpi-final.sh' ausführen (siehe glpi-final Schritt).
----------------------------------------
INFO
