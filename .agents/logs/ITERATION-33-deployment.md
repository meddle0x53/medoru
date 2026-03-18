# Iteration 33: Deployment & Production Setup

**Status**: 🚧 IN PROGRESS  
**Started**: 2026-03-18  
**Priority**: 🔴 HIGH  
**Domain**: medoru.net  
**Server IP**: 178.104.91.176

## Overview

Deploy Medoru to production server at medoru.net using Ansible for automated infrastructure setup.

## Completed ✅

### 1. Ansible Deployment Infrastructure
**Files Created:**
- `deployment/inventory/production` - Server inventory (medoru.net)
- `deployment/group_vars/medoru.yml` - Production variables
- `deployment/setup.yml` - Initial server setup playbook
- `deployment/update.yml` - Application update playbook
- `deployment/build-release.sh` - Release build script
- `deployment/deploy.sh` - Deployment helper script
- `deployment/README.md` - Deployment documentation

### 2. Server Roles

#### Common Role
- ✅ Firewall (UFW) - ports 22, 80, 443 open
- ✅ Essential packages installed
- ✅ Medoru user created
- ✅ Application directories created

#### PostgreSQL Role
- ✅ PostgreSQL 16 installed (server + client)
- ✅ Database `medoru_prod` created
- ✅ User `meddle` with CREATEDB privileges
- ✅ python3-psycopg2 installed

#### Nginx Role
- ✅ Nginx installed
- ✅ SSL reverse proxy configured
- ✅ HTTP → HTTPS redirect
- ✅ WebSocket support
- ✅ Security headers (HSTS, X-Frame-Options, etc.)

#### Certbot Role
- ✅ Certbot installed
- ✅ Self-signed certificate fallback (due to DNSSEC issues)
- ⚠️ Let's Encrypt certificate pending DNS fix

#### Medoru Role
- ✅ Systemd service configured
- ✅ Environment file template
- ✅ Service directories created
- ✅ Service enabled

### 3. Environment Variables Support
Setup now uses environment variables:
- `DB_PASSWORD` - PostgreSQL password
- `SECRET_KEY_BASE` - Phoenix secret
- `GOOGLE_CLIENT_ID` - OAuth client ID
- `GOOGLE_CLIENT_SECRET` - OAuth client secret

## In Progress 🚧

### DNS Issues
**Problem**: Domain `medoru.net` nameservers changed to:
- NS1.REGISTRANT-VERIFICATION.COM
- NS2.REGISTRANT-VERIFICATION.COM

**Impact**: 
- Domain points to wrong IP (212.123.41.108 instead of 178.104.91.176)
- Let's Encrypt SSL certificate cannot be issued
- Site not accessible via domain

**Status**: Under investigation - likely domain verification issue with registrar (Ascio Technologies)

## Pending ⏳

1. **Fix DNS/nameservers**
   - Restore correct nameservers
   - Point A record to 178.104.91.176

2. **Obtain SSL Certificate**
   - Once DNS is fixed, run certbot
   - Replace self-signed certificate

3. **Deploy Application**
   - Build release
   - Copy to server
   - Restore database
   - Start service

## Commands

```bash
# Build release
./deployment/build-release.sh

# Setup server (with env vars)
DB_PASSWORD=xxx SECRET_KEY_BASE=yyy GOOGLE_CLIENT_ID=zzz GOOGLE_CLIENT_SECRET=www \
  ansible-playbook -i deployment/inventory/production deployment/setup.yml -K

# Deploy update
ansible-playbook -i deployment/inventory/production deployment/update.yml -K
```

## Blockers

- 🔴 **DNS/nameserver issue** - Domain not pointing to correct server

## Next Steps

1. Contact domain registrar (Ascio) or DNS provider
2. Restore correct nameserver configuration
3. Verify domain points to 178.104.91.176
4. Re-run certbot to obtain SSL certificate
5. Deploy application release
6. Restore database from dump
