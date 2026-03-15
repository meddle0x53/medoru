# Iteration 33: Deployment & Production Setup

**Status**: ⏳ PLANNED  
**Priority**: 🔴 HIGH  
**Estimated**: 3-4 days  
**Depends On**: All v0.1.0 iterations complete

## Overview

Deploy Medoru to production server with full infrastructure setup: domain, SSL, systemd service, nginx reverse proxy, and database migration. Domain: **medoru.net**

## Infrastructure Requirements

### Server Setup
- **Domain**: medoru.net
- **SSL**: Certbot (Let's Encrypt)
- **Web Server**: Nginx (reverse proxy)
- **App Server**: Elixir/Phoenix as systemd service
- **Database**: PostgreSQL
- **Server**: VPS (to be provisioned)

## Deployment Method

### Ansible Playbook Structure
```
deploy/
├── ansible/
│   ├── inventory/
│   │   └── production.yml       # Server IP, SSH key
│   ├── group_vars/
│   │   └── all.yml              # Secrets (from local env)
│   ├── playbook.yml             # Main deployment playbook
│   └── roles/
│       ├── common/              # System updates, deps
│       ├── postgres/            # PostgreSQL setup
│       ├── nginx/               # Reverse proxy + SSL
│       ├── app/                 # Phoenix app deployment
│       └── certbot/             # SSL certificates
```

## Secrets & Environment Variables

### Local Development → Production
Copy from local `.env` to server environment:

```bash
# Google OAuth (real credentials)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# Database (production)
DATABASE_URL=postgres://medoru:SECRET@localhost/medoru_prod

# Phoenix
SECRET_KEY_BASE=  # Generate new: mix phx.gen.secret
PHX_HOST=medoru.net
PHX_PORT=4000

# Other
POOL_SIZE=10
```

## Database Migration Strategy

### Data to Migrate (Seed to Production)
```bash
# Dump from local
pg_dump medoru_dev \
  --table=kanji \
  --table=kanji_readings \
  --table=words \
  --table=word_kanjis \
  --table=lessons \
  --table=lesson_kanjis \
  --table=lesson_words \
  --table=badges \
  --data-only \
  > content_seed.sql

# Restore on production
psql medoru_prod < content_seed.sql
```

### Data NOT to Migrate
- Users (start fresh in production)
- User profiles/stats
- Classrooms (custom content)
- Custom tests
- Test sessions/answers
- Notifications

## Deployment Steps

### 1. Server Provisioning
```bash
# Ansible tasks:
- Create deploy user
- Install Erlang, Elixir, Node.js
- Install PostgreSQL
- Install Nginx
- Configure firewall (ufw: 22, 80, 443, 4000 local)
```

### 2. Database Setup
```bash
# Ansible tasks:
- Create medoru_prod database
- Create medoru user
- Set password from secrets
- Grant privileges
- Run migrations: mix ecto.migrate
- Seed content (kanji, words, lessons, badges)
```

### 3. Application Deployment
```bash
# Ansible tasks:
- Clone/pull from git
- Install deps: mix deps.get
- Compile: MIX_ENV=prod mix compile
- Build assets: mix assets.deploy
- Generate release: mix phx.gen.release
- Create systemd service file
- Start/restart service
```

### 4. Nginx + SSL
```bash
# Ansible tasks:
- Configure nginx site for medoru.net
- Reverse proxy to localhost:4000
- Certbot: obtain SSL certificate
- Auto-renewal cron job
- Force HTTPS redirect
```

## Nginx Configuration

```nginx
# /etc/nginx/sites-available/medoru
server {
    listen 80;
    server_name medoru.net www.medoru.net;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name medoru.net www.medoru.net;

    ssl_certificate /etc/letsencrypt/live/medoru.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/medoru.net/privkey.pem;

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Systemd Service

```ini
# /etc/systemd/system/medoru.service
[Unit]
Description=Medoru Phoenix Application
After=network.target postgresql.service

[Service]
Type=simple
User=medoru
WorkingDirectory=/opt/medoru
Environment=MIX_ENV=prod
Environment=PHX_HOST=medoru.net
Environment=DATABASE_URL=...
Environment=SECRET_KEY_BASE=...
Environment=GOOGLE_CLIENT_ID=...
Environment=GOOGLE_CLIENT_SECRET=...
ExecStart=/opt/medoru/bin/medoru start
ExecStop=/opt/medoru/bin/medoru stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## Checklist

### Pre-Deployment
- [ ] Server provisioned (VPS)
- [ ] Domain medoru.net purchased
- [ ] DNS A record pointing to server
- [ ] Real Google OAuth credentials obtained
- [ ] Ansible playbook written
- [ ] Content seed dump tested locally

### Deployment
- [ ] Run ansible playbook
- [ ] Verify PostgreSQL running
- [ ] Verify migrations complete
- [ ] Verify content seeded
- [ ] Verify systemd service running
- [ ] Verify nginx serving requests
- [ ] Verify SSL certificate valid
- [ ] Verify Google OAuth works (real credentials)

### Post-Deployment
- [ ] Create first admin user
- [ ] Smoke test all critical paths
- [ ] Monitor logs for errors
- [ ] Document any issues

## Files to Create

```
deploy/
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── production.yml
│   ├── group_vars/
│   │   └── all.yml (encrypted with ansible-vault)
│   ├── playbook.yml
│   └── roles/
│       ├── common/
│       │   └── tasks/main.yml
│       ├── postgres/
│       │   └── tasks/main.yml
│       ├── nginx/
│       │   ├── tasks/main.yml
│       │   └── templates/medoru.conf.j2
│       ├── app/
│       │   └── tasks/main.yml
│       └── certbot/
│           └── tasks/main.yml
├── scripts/
│   ├── dump_content.sh      # Dump kanji/words/lessons
│   └── restore_content.sh   # Restore to production
└── README.md                # Deployment instructions
```

## User Approval Required
- [ ] Review ansible playbook structure
- [ ] Confirm domain: medoru.net
- [ ] Confirm data migration scope (what to include/exclude)
- [ ] Approve deployment approach

## Notes
- PostgreSQL version: Match local (14+ recommended)
- Elixir/OTP versions: Match local development
- Use distillery or mix release for production builds
- Consider database backup strategy post-deployment
