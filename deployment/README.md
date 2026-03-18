# Medoru Production Deployment

This directory contains Ansible playbooks for deploying Medoru to production.

## Prerequisites

- Ansible installed locally
- SSH access to server (meddle@178.104.91.176 with key ~/.ssh/id_ghub_ed25519)
- Domain: medoru.net pointing to 178.104.91.176
- Environment variables ready (see below)

## File Structure

```
deployment/
├── inventory/
│   └── production          # Server inventory
├── group_vars/
│   └── production.yml      # Production variables
├── roles/
│   ├── common/            # Server basics (firewall, packages)
│   ├── postgres/          # PostgreSQL installation
│   ├── certbot/           # SSL certificates
│   ├── nginx/             # Reverse proxy
│   └── medoru/            # Application service
├── setup.yml              # Initial server setup (run once)
├── update.yml             # Deploy new releases
└── README.md              # This file
```

## Initial Setup

### 1. Build the Release

```bash
# From project root
cd /var/home/meddle/development/elixir/medoru

# Get dependencies
mix deps.get

# Build assets
cd assets && npm install && npm run build
cd ..

# Build release
MIX_ENV=prod mix release

# Create tarball
tar -czf medoru_release.tar.gz -C _build/prod/rel/medoru .
```

### 2. Run Setup Playbook

Set the required environment variables and run the setup:

```bash
cd deployment

# Generate secret key if you don't have one
export SECRET_KEY_BASE=$(mix phx.gen.secret)

# Set other environment variables
export DB_PASSWORD="your_postgres_password"
export GOOGLE_CLIENT_ID="your_google_client_id"
export GOOGLE_CLIENT_SECRET="your_google_client_secret"

# Run setup (you'll be prompted for sudo password)
# Use -K to prompt for sudo password
ansible-playbook -i inventory/production setup.yml -K
```

**Required environment variables:**
- `DB_PASSWORD` - PostgreSQL password for meddle user
- `SECRET_KEY_BASE` - Phoenix secret (generate with `mix phx.gen.secret`)
- `GOOGLE_CLIENT_ID` - Google OAuth Client ID
- `GOOGLE_CLIENT_SECRET` - Google OAuth Client Secret

**Alternative**: If you have passwordless sudo set up, omit the `-K` flag.

### 3. Restore Database (Manual)

```bash
# SSH to server
ssh -i ~/.ssh/id_ghub_ed25519 meddle@medoru.net

# Copy and restore dump
pg_restore -d medoru_prod --no-owner --no-privileges < prod_dump.tar.gz

# Or use the CSV files:
cd /tmp/prod_dump
psql -d medoru_prod < restore.sh
```

### 4. Start the Application

```bash
# On server
sudo systemctl start medoru
sudo systemctl enable medoru
```

## Deploy Updates

### 1. Build New Release

```bash
# From project root
MIX_ENV=prod mix release

# Create tarball
tar -czf deployment/../medoru_release.tar.gz -C _build/prod/rel/medoru .
```

### 2. Run Update Playbook

```bash
cd deployment

# With sudo password prompt
ansible-playbook -i inventory/production update.yml -K

# Or without if you have passwordless sudo
ansible-playbook -i inventory/production update.yml
```

## Managing the Application

```bash
# Check status
sudo systemctl status medoru

# View logs
sudo journalctl -u medoru -f

# Restart
sudo systemctl restart medoru

# Stop
sudo systemctl stop medoru
```

## Environment Variables

Environment variables are stored in `/etc/medoru/medoru.env` and sourced by systemd.

To update environment variables:
```bash
sudo nano /etc/medoru/medoru.env
sudo systemctl restart medoru
```

## SSL Certificates

Certificates are automatically managed by Certbot and renewed via cron.

To force renewal:
```bash
sudo certbot renew --force-renewal
```

## Troubleshooting

### Application won't start
```bash
# Check logs
sudo journalctl -u medoru -n 100

# Check environment file exists and is readable
sudo cat /etc/medoru/medoru.env

# Check database connection
sudo -u medoru /opt/medoru/current/bin/medoru eval 'Medoru.Repo.query!("SELECT 1")'
```

### Nginx issues
```bash
# Test config
sudo nginx -t

# Check nginx error log
sudo tail -f /var/log/nginx/error.log
```

### Database issues
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Connect to database
sudo -u postgres psql -d medoru_prod
```

## Security

- Firewall: Only ports 22 (SSH), 80 (HTTP redirect), 443 (HTTPS) are open
- PostgreSQL: Only listens on localhost
- SSL: Enforced with HSTS headers
- Fail2ban: Installed and enabled

## Domain

- Domain: medoru.net
- IP: 178.104.91.176
