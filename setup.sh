# - Run: chmod +x .devcontainer/setup.sh && sudo .devcontainer/setup.sh
# - You can change ODOO_VERSION or DB credentials below as needed.

ODOO_VERSION="16.0"
ODOO_DIR="odoo"
PG_USER="odoo"
PG_PASS="odoo"
PG_DB="odoo"

# Use sudo when not root
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

echo "Ì¥ß Preparing system package lists..."
# fix broken/permission-denied apt lists (common in some containers) and update
$SUDO rm -rf /var/lib/apt/lists/partial || true
$SUDO apt-get update -y

echo "Ì¥ß Installing system dependencies (this may take a few minutes)..."
$SUDO apt-get install -y --no-install-recommends \
    git \
    build-essential \
    libpq-dev \
    python3-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libsasl2-dev \
    libldap2-dev \
    libjpeg-dev \
    libffi-dev \
    libssl-dev \
    wkhtmltopdf \
    curl \
    sudo \
    nodejs \
    npm \
    python3-pip \
    postgresql \
    postgresql-contrib

# make sure pip command exists
$SUDO ln -sf /usr/bin/pip3 /usr/bin/pip || true

# Install less (node) used by some Odoo assets builds
# prefer npm global install; requires sudo for global bin dir
if command -v npm >/dev/null 2>&1; then
  echo "Ì¥ß Installing less (npm)..."
  $SUDO npm install -g less || true
fi

echo "Ì≥• Cloning Odoo $ODOO_VERSION (if missing)..."
if [ ! -d "$ODOO_DIR" ]; then
  git clone --depth 1 --branch "$ODOO_VERSION" https://github.com/odoo/odoo.git "$ODOO_DIR"
else
  echo "‚úÖ Odoo directory already exists. Skipping clone."
fi

echo "Ì∞ç Installing Python dependencies for Odoo..."
# Install requirements globally (typical for dev). Change to virtualenv if preferred.
if [ -f "$ODOO_DIR/requirements.txt" ]; then
  $SUDO pip3 install -r "$ODOO_DIR/requirements.txt"
else
  echo "‚ö†Ô∏è  requirements.txt not found in $ODOO_DIR ‚Äî skipping pip install."
fi

echo "Ì∑ÑÔ∏è  Configuring PostgreSQL user/database..."
# Ensure postgres service is running (system packages)
# On systems without systemd/service, `pg_ctlcluster` or direct start may be required.
# Try a simple check and start if necessary:
if ! pg_isready >/dev/null 2>&1; then
  echo "‚ÑπÔ∏è  PostgreSQL does not appear ready. Attempting to start service..."
  # try common start commands (best-effort)
  $SUDO systemctl start postgresql 2>/dev/null || true
  $SUDO service postgresql start 2>/dev/null || true
fi

# Create DB user and DB if they do not exist
# Detect if role exists
ROLE_EXISTS=$($SUDO -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PG_USER';" || echo "")
if [ "$ROLE_EXISTS" = "1" ]; then
  echo "‚úÖ Postgres role '$PG_USER' already exists."
else
  echo "Ì¥ê Creating Postgres role '$PG_USER'..."
  $SUDO -u postgres psql -c "CREATE ROLE $PG_USER WITH LOGIN PASSWORD '$PG_PASS';"
fi

DB_EXISTS=$($SUDO -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$PG_DB';" || echo "")
if [ "$DB_EXISTS" = "1" ]; then
  echo "‚úÖ Postgres database '$PG_DB' already exists."
else
  echo "Ì∑ÉÔ∏è  Creating Postgres database '$PG_DB' owned by '$PG_USER'..."
  $SUDO -u postgres createdb -O "$PG_USER" "$PG_DB"
fi

echo "Ì¥ê Ensuring local workspace permissions for Odoo user (uid 1000)..."
# Common codespace/devcontainer Odoo image runs as uid 1000; chown project folders to that uid
mkdir -p /workspace/addons || true
$SUDO chown -R 1000:1000 /workspace/addons /workspace/"$ODOO_DIR" || true

echo "‚úÖ Setup complete!"
echo "Next steps:"
echo " - Start Odoo (if you installed system packages) with: sudo -u $PG_USER odoo -c /path/to/odoo.conf"
echo " - Or prefer reproducible images: move these installs into your Dockerfile and rebuild the devcontainer."
