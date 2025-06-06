# Production Deployment Guide

This guide covers deploying the WebDNA application to production at `https://dev.goodvaluation.com/theprogram`.

## Architecture Overview

The production setup uses:
- **Cloudflare** for DNS and SSL termination
- **Nginx** as a reverse proxy
- **Apache + WebDNA** as the application server
- **PostgreSQL** for database
- **Docker Compose** for orchestration

## Prerequisites

1. Server with Docker and Docker Compose installed
2. Domain configured in Cloudflare (dev.goodvaluation.com)
3. Cloudflare SSL mode set to "Full"
4. Port 80 and 443 open on server firewall

## Deployment Steps

### 1. Clone Repository

```bash
git clone <repository-url> /opt/theprogram5
cd /opt/theprogram5
```

### 2. Configure Environment

```bash
cd deploy
cp .env.example .env
```

Edit `.env` with your production values:
```env
DB_PASSWORD=your_secure_password_here
HOST_UID=1000  # Match your server user
HOST_GID=1000  # Match your server group
```

### 3. Generate SSL Certificate

For Cloudflare "Full" mode, generate a self-signed certificate:

```bash
./generate-ssl-cert.sh
```

### 4. Update Cloudflare IPs

```bash
./update-cloudflare-ips.sh
```

Set up a cron job to update weekly:
```bash
crontab -e
# Add: 0 3 * * 0 /opt/theprogram5/deploy/update-cloudflare-ips.sh
```

### 5. Build and Start Services

```bash
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d
```

### 6. Verify Deployment

```bash
./health-check.sh
```

Check logs:
```bash
docker-compose -f docker-compose.prod.yml logs -f
```

## Cloudflare Configuration

1. **DNS Settings**:
   - Create A record: `dev.goodvaluation.com` → Your server IP
   - Enable proxy (orange cloud)

2. **SSL/TLS Settings**:
   - SSL mode: Full
   - Always Use HTTPS: On
   - Automatic HTTPS Rewrites: On

3. **Page Rules** (optional):
   - `dev.goodvaluation.com/theprogram/*`
     - Cache Level: Standard
     - Security Level: Medium

## Maintenance

### Update Application

```bash
cd /opt/theprogram5
git pull
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d
```

### View Logs

```bash
# All services
docker-compose -f docker-compose.prod.yml logs -f

# Specific service
docker-compose -f docker-compose.prod.yml logs -f webdna-server
```

### Backup Database

```bash
docker-compose -f docker-compose.prod.yml exec postgres \
  pg_dump -U webdna_user webdna_main > backup_$(date +%Y%m%d).sql
```

### Monitor Performance

```bash
# Check resource usage
docker stats

# Monitor Apache
docker-compose -f docker-compose.prod.yml exec webdna-server \
  tail -f /var/log/apache2/access.log
```

## Troubleshooting

### WebDNA Not Starting

1. Check logs: `docker-compose -f docker-compose.prod.yml logs webdna-server`
2. Verify WebCatalog: `docker-compose -f docker-compose.prod.yml exec webdna-server curl http://localhost/WebCatalog`

### SSL Issues

1. Verify Cloudflare SSL mode is "Full"
2. Check certificate: `openssl x509 -in nginx/ssl/cert.pem -text -noout`
3. Test nginx config: `docker-compose -f docker-compose.prod.yml exec nginx nginx -t`

### Database Connection Issues

1. Check PostgreSQL: `docker-compose -f docker-compose.prod.yml exec postgres pg_isready`
2. Verify credentials in `.env`
3. Test connection: `docker-compose -f docker-compose.prod.yml exec postgres psql -U webdna_user -d webdna_main`

## Security Checklist

- [ ] Change default database password
- [ ] Restrict server firewall to ports 80, 443, and SSH
- [ ] Enable Cloudflare firewall rules
- [ ] Set up fail2ban for SSH
- [ ] Configure regular backups
- [ ] Monitor logs for suspicious activity
- [ ] Keep Docker and system packages updated

## Performance Optimization

1. **Enable Cloudflare Caching**:
   - Set appropriate cache headers
   - Use Page Rules for static assets

2. **Monitor Resources**:
   ```bash
   # Add to monitoring/scripts/
   ./monitoring/scripts/performance_dashboard.sh
   ```

3. **Database Optimization**:
   - Regular VACUUM operations
   - Monitor slow queries
   - Adjust PostgreSQL settings based on load

## Support

For issues specific to:
- **WebDNA**: Check `/var/log/apache2/webdna-error.log`
- **Apache**: Check `/var/log/apache2/error.log`
- **Nginx**: Check nginx container logs
- **Database**: Check PostgreSQL container logs