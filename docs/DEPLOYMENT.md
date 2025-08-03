# SurveyShark Deployment Guide

This document provides step-by-step instructions for deploying SurveyShark to production using Kamal with Traefik and Let's Encrypt.

## Prerequisites

- A Linux server (Ubuntu 20.04+ recommended) with Docker installed
- A domain name pointing to your server
- SSH access to your server
- Docker registry access (Docker Hub, GitHub Container Registry, etc.)

## Server Setup

### 1. Prepare Your Server

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add deploy user
sudo adduser deploy
sudo usermod -aG docker deploy
sudo mkdir -p /home/deploy/.ssh
sudo cp ~/.ssh/authorized_keys /home/deploy/.ssh/
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys

# Create storage directory for SQLite
sudo mkdir -p /var/lib/survey-shark/storage
sudo chown -R deploy:deploy /var/lib/survey-shark

# Create Let's Encrypt directory
sudo mkdir -p /letsencrypt
sudo chown -R deploy:deploy /letsencrypt
```

### 2. Configure Kamal Secrets

Create the secrets file:

```bash
# On your local machine
mkdir -p .kamal
touch .kamal/secrets
chmod 600 .kamal/secrets
```

Add the following to `.kamal/secrets`:

```bash
KAMAL_REGISTRY_PASSWORD=your_registry_password_or_token
RAILS_MASTER_KEY=your_rails_master_key_from_config/master.key
OPENAI_API_KEY=your_openai_api_key
```

### 3. Update Configuration

Edit `config/deploy.yml` and update:

- `servers.web` - Replace with your server IP address
- `registry.username` - Your Docker registry username
- `traefik.args.certificatesResolvers.letsencrypt.acme.email` - Your email for Let's Encrypt
- `ssh.user` - Should be `deploy`

## Deployment Steps

### 1. Initial Setup

```bash
# Install Kamal gem (if not already installed)
gem install kamal

# Setup Kamal on the server (first time only)
kamal setup
```

### 2. Deploy Application

```bash
# Deploy the application
kamal deploy

# Check deployment status
kamal app logs
kamal traefik logs
```

### 3. Initial Admin Setup

After successful deployment, create the initial admin user:

```bash
# SSH into your server
ssh deploy@your-server-ip

# Run the admin setup task
docker exec -it survey-shark-web-1 bin/rails admin:setup

# Or set up admin via environment variables
docker exec -it survey-shark-web-1 \
  env ADMIN_EMAIL=admin@yourcompany.com ADMIN_PASSWORD=secure_password \
  bin/rails admin:setup
```

### 4. Verify Deployment

1. Visit `https://yourdomain.com/up` - should return `{"status":"ok"}`
2. Visit `https://yourdomain.com` - should redirect to admin login
3. Log in with your admin credentials
4. Create a test project and verify the full flow works

## Environment Variables

The following environment variables are required in production:

- `RAILS_MASTER_KEY` - Rails secret key (from `config/master.key`)
- `OPENAI_API_KEY` - OpenAI API key for LLM functionality
- `RAILS_ENV=production` - Set automatically
- `RAILS_LOG_TO_STDOUT=true` - For Docker logging
- `RAILS_SERVE_STATIC_FILES=true` - Serve assets directly

## SSL/TLS Configuration

The deployment uses Traefik with Let's Encrypt for automatic SSL certificate management:

- Certificates are automatically obtained and renewed
- HTTP traffic is redirected to HTTPS
- Certificates are stored in `/letsencrypt/acme.json` on the server

## Database Management

SurveyShark uses SQLite with the following configuration:

- Database file: `/rails/storage/production.sqlite3` (inside container)
- Persistent storage: `/var/lib/survey-shark/storage` (on host)
- WAL mode enabled for better concurrency
- Automatic migrations on container start

### Database Backup

```bash
# Create backup
docker exec survey-shark-web-1 sqlite3 /rails/storage/production.sqlite3 ".backup /rails/storage/backup-$(date +%Y%m%d-%H%M%S).sqlite3"

# Copy backup to host
docker cp survey-shark-web-1:/rails/storage/backup-*.sqlite3 ./
```

### Database Restore

```bash
# Copy backup to container
docker cp backup.sqlite3 survey-shark-web-1:/rails/storage/

# Restore database
docker exec survey-shark-web-1 sqlite3 /rails/storage/production.sqlite3 ".restore /rails/storage/backup.sqlite3"

# Restart application
kamal app restart
```

## Monitoring and Logs

### View Application Logs

```bash
# Real-time logs
kamal app logs -f

# Specific number of lines
kamal app logs --lines 100
```

### View Traefik Logs

```bash
# Traefik proxy logs
kamal traefik logs -f
```

### Health Checks

The application includes a health check endpoint at `/up` that verifies:

- Rails application is running
- Database connectivity
- Required environment variables are set

## Scaling and Updates

### Deploy Updates

```bash
# Deploy new version
kamal deploy

# Rollback if needed
kamal app rollback
```

### Scale Application

```bash
# Add more servers to config/deploy.yml under servers.web
# Then redeploy
kamal setup
kamal deploy
```

## Security Considerations

1. **Firewall Configuration**
   ```bash
   sudo ufw allow 22    # SSH
   sudo ufw allow 80    # HTTP (redirects to HTTPS)
   sudo ufw allow 443   # HTTPS
   sudo ufw enable
   ```

2. **Regular Updates**
   - Keep the server OS updated
   - Update Docker images regularly
   - Monitor security advisories for Ruby/Rails

3. **Backup Strategy**
   - Regular database backups
   - Store backups off-site
   - Test restore procedures

4. **Access Control**
   - Use strong passwords for admin accounts
   - Consider IP restrictions for admin access
   - Monitor access logs

## Troubleshooting

### Common Issues

1. **SSL Certificate Issues**
   ```bash
   # Check certificate status
   kamal traefik logs | grep -i certificate
   
   # Restart Traefik
   kamal traefik restart
   ```

2. **Database Connection Issues**
   ```bash
   # Check storage permissions
   ls -la /var/lib/survey-shark/storage/
   
   # Fix permissions if needed
   sudo chown -R deploy:deploy /var/lib/survey-shark/
   ```

3. **Application Won't Start**
   ```bash
   # Check application logs
   kamal app logs --lines 50
   
   # Verify environment variables
   kamal app exec 'env | grep RAILS'
   ```

### Getting Help

- Check the application logs first: `kamal app logs`
- Verify health check: `curl https://yourdomain.com/up`
- Check Kamal documentation: https://kamal-deploy.org/
- Review Rails deployment guides: https://guides.rubyonrails.org/

## Production Checklist

Before going live:

- [ ] Domain name configured and DNS propagated
- [ ] SSL certificate obtained and working
- [ ] Admin user created and tested
- [ ] Sample project created and full user flow tested
- [ ] Database backups configured
- [ ] Monitoring and alerting set up
- [ ] Security measures implemented (firewall, etc.)
- [ ] Performance testing completed
- [ ] Documentation updated with your specific configuration

## Support

For issues specific to SurveyShark:

1. Check the application logs for error messages
2. Verify all required environment variables are set
3. Test the health check endpoint
4. Review this deployment guide for missed steps

For Kamal-specific issues, refer to the official Kamal documentation at https://kamal-deploy.org/