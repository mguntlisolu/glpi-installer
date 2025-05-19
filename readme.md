# GLPI Installer and Uninstaller (Shell Scripts)

This repository provides Bash scripts to install and uninstall [GLPI](https://glpi-project.org/) on a Linux system (Ubuntu or Debian-based).  
The setup follows official recommendations for GLPI version 10.0.7 or later.

---

## Files

### 1. install-glpi.sh

Initial installation script for GLPI. It installs required packages, sets up MySQL, downloads and extracts GLPI to `/var/www/glpi`, and creates an Apache configuration with `/glpi` as access path.

This allows manual web installation at:

    http://localhost/glpi/install/install.php

**Actions performed:**

- Installs Apache, MySQL, PHP 8.3 and required PHP modules
- Creates MySQL database and user
- Extracts GLPI to `/var/www/glpi`
- Sets correct ownership and permissions
- Configures Apache to serve GLPI at `/glpi`
- Enables required Apache modules
- Reloads Apache

---

### 2. glpi-finalize.sh

Used after completing the manual installation through the browser.  
This script reconfigures Apache to serve GLPI directly from `/`, using `/var/www/glpi/public` as the new root.

**Actions performed:**

- Removes the `/install` directory
- Creates external GLPI data directory `/var/lib/glpi-data`
- Updates `GLPI_VAR_DIR` in `define.php`
- Configures Apache with `DocumentRoot /var/www/glpi/public`
- Adds recommended rewrite and auth passthrough rules
- Reloads Apache

GLPI is then available at:

    http://localhost

---

### 3. uninstall-glpi.sh

Optional cleanup script to remove GLPI from the system.

**Actions performed:**

- Disables and deletes the GLPI Apache config
- Deletes GLPI files from `/var/www/glpi`
- Deletes `/var/lib/glpi-data`
- Drops the MySQL database and user
- Reloads Apache

---

## Usage

Make the scripts executable:

chmod +x install-glpi.sh
chmod +x glpi-finalize.sh
chmod +x uninstall-glpi.sh

Run each script using bash:

# To initialize the script
sudo bash install-glpi.sh

# After completing the web-based setup:
sudo bash glpi-finalize.sh

# To uninstall:
sudo bash uninstall-glpi.sh


## HTTPS with Let's Encrypt (recommended)
If you are deploying GLPI directly on a public server (not behind a reverse proxy or firewall), it is strongly recommended to use HTTPS.

You can easily enable HTTPS using Certbot and Let's Encrypt:

# Install Certbot:

bash
Kopieren
Bearbeiten
sudo apt install certbot python3-certbot-apache -y
Run Certbot for your domain:

bash
Kopieren
Bearbeiten
sudo certbot --apache -d yourdomain.example.com
Certbot will automatically configure Apache and reload it with a free, valid SSL certificate.

Note: If GLPI is accessed through a reverse proxy (e.g. nginx, traefik), handle TLS termination at the proxy level instead.

## Requirements
-Ubuntu 20.04+ or Debian 11+
-Internet connection
-Root or sudo permissions
-Static IP or public domain (for Let's Encrypt)

