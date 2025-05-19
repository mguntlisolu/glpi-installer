# GLPI Automated Installer (PHP 8.3)

This is a secure and production-ready Bash script that installs GLPI (version 10.0.14) with PHP 8.3 on Ubuntu.

## Features

- Installs and configures:
  - Apache2 + PHP 8.3 + required extensions
  - MySQL database and user for GLPI
  - GLPI download and extraction
- Uses `/public` as the only web-accessible directory
- Moves the GLPI `files/` directory outside of the web root
- Sets `GLPI_VAR_DIR` accordingly in `define.php`
- Enables `session.cookie_httponly` for improved security
- Configures Apache by adding a global `ServerName`
- Creates a virtual host for the given domain

## Usage

Download and run the script:

```bash
wget https://raw.githubusercontent.com/<your-username>/<repo-name>/main/install-glpi.sh
chmod +x install-glpi.sh
./install-glpi.sh
