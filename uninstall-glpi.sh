#!/usr/bin/env bash
# uninstall-glpi.sh
# Safely remove GLPI (Apache vHost, files, data dir, DB + DB user)

set -euo pipefail

# --- CONFIG -------------------------------------------------------------

GLPI_DIR="/var/www/glpi"
GLPI_DATA_DIR="/var/lib/glpi-data"
APACHE_SITE_NAME="glpi.conf"       # /etc/apache2/sites-available/$APACHE_SITE_NAME

DB_HOST="localhost"
DB_NAME="glpidb"
DB_USER="glpiuser"
DB_ROOT_USER="root"

# optional: root password aus Datei einlesen
MYSQL_ROOT_PWD_FILE="/root/.mysql_root_pwd"

if [[ -f "$MYSQL_ROOT_PWD_FILE" ]]; then
  MYSQL_ROOT_PWD="$(<"$MYSQL_ROOT_PWD_FILE")"
else
  MYSQL_ROOT_PWD=""
fi

# --- FUNKTIONEN ---------------------------------------------------------

safe_delete_dir() {
  local dir="$1"
  local label="$2"

  # 1) Leer?
  if [[ -z "$dir" ]]; then
    echo "FEHLER: $label-Verzeichnis-Pfad ist leer – lösche NICHT."
    return 1
  fi

  # 2) Root?
  if [[ "$dir" == "/" ]]; then
    echo "FEHLER: $label-Verzeichnis ist '/' – lösche NICHT."
    return 1
  fi

  # 3) Existiert überhaupt?
  if [[ ! -d "$dir" ]]; then
    echo "$label-Verzeichnis '$dir' existiert nicht – überspringe."
    return 0
  fi

  # 4) Nur bestimmte Prefixe erlauben
  case "$dir" in
    /var/www/*|/var/lib/*)
      # ok
      ;;
    *)
      echo "FEHLER: $label-Verzeichnis '$dir' liegt NICHT unter /var/www oder /var/lib – lösche NICHT."
      return 1
      ;;
  esac

  # 5) Basename prüfen (sollte nicht 'www' oder 'var' etc. sein)
  local base
  base="$(basename "$dir")"
  case "$base" in
    ""|"/"|"var"|"www"|"html"|"lib")
      echo "FEHLER: $label-Verzeichnis-Basename '$base' ist verdächtig – lösche NICHT."
      return 1
      ;;
  esac

  echo "-> Lösche $label-Verzeichnis: $dir"
  rm -rf -- "$dir"
}

# -----------------------------------------------------------------------

echo "----------------------------------------"
echo " GLPI Uninstaller"
echo "----------------------------------------"
echo "GLPI-Verzeichnis:      $GLPI_DIR"
echo "GLPI-Datenverzeichnis: $GLPI_DATA_DIR"
echo "Apache vHost:          $APACHE_SITE_NAME"
echo "DB-Host:               $DB_HOST"
echo "DB-Name:               $DB_NAME"
echo "DB-User:               $DB_USER"
echo

read -r -p "Wirklich ALLES löschen (inkl. Datenbank + DB-User)? [y/N] " ANSWER
case "$ANSWER" in
  y|Y|yes|YES)
    echo "OK, fahre mit Deinstallation fort..."
    ;;
  *)
    echo "Abgebrochen."
    exit 0
    ;;
esac

# --- Apache vHost deaktivieren / löschen --------------------------------

if command -v apache2ctl >/dev/null 2>&1; then
  VHOST_AVAILABLE="/etc/apache2/sites-available/$APACHE_SITE_NAME"
  VHOST_ENABLED="/etc/apache2/sites-enabled/$APACHE_SITE_NAME"

  if [[ -f "$VHOST_AVAILABLE" || -f "$VHOST_ENABLED" ]]; then
    echo "-> Apache-Site '$APACHE_SITE_NAME' deaktivieren..."
    if command -v a2dissite >/dev/null 2>&1; then
      a2dissite "$APACHE_SITE_NAME" || true
    fi

    echo "-> Apache-Site-Dateien löschen..."
    rm -f "$VHOST_AVAILABLE" "$VHOST_ENABLED" || true

    echo "-> Apache neu laden..."
    systemctl reload apache2 || true
  else
    echo "Apache-Site '$APACHE_SITE_NAME' nicht gefunden – überspringe."
  fi
else
  echo "Apache scheint nicht installiert zu sein – überspringe vHost-Schritte."
fi

# --- GLPI-Verzeichnisse mit Safety-Checks löschen ----------------------

safe_delete_dir "$GLPI_DIR" "GLPI"
safe_delete_dir "$GLPI_DATA_DIR" "GLPI-Daten"

# --- Datenbank + User löschen ------------------------------------------

if command -v mysql >/dev/null 2>&1; then
  echo "-> Versuche, Datenbank und User zu löschen..."

  MYSQL_CMD=(mysql -h "$DB_HOST" -u "$DB_ROOT_USER")
  if [[ -n "$MYSQL_ROOT_PWD" ]]; then
    MYSQL_CMD+=("-p$MYSQL_ROOT_PWD")
  fi

  "${MYSQL_CMD[@]}" <<SQL || {
    echo "WARNUNG: Konnte Datenbank/User nicht löschen. Bitte manuell prüfen."
  }
DROP DATABASE IF EXISTS \`$DB_NAME\`;
DROP USER IF EXISTS '$DB_USER'@'localhost';
DROP USER IF EXISTS '$DB_USER'@'%';
FLUSH PRIVILEGES;
SQL

else
  echo "MySQL/MariaDB-Client 'mysql' nicht gefunden – DB-Löschung übersprungen."
fi

echo
echo "----------------------------------------"
echo " GLPI wurde entfernt."
echo " Apache + PHP + MariaDB bleiben installiert."
echo "----------------------------------------"
