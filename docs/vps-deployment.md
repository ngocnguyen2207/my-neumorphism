# VPS Deployment Guide

This project uses GitHub Actions to automatically deploy to your VPS server whenever you push to the `master` branch.

## Prerequisites on VPS

1. **Docker and Docker Compose installed**
2. **nginx-proxy network** (for reverse proxy setup):
   ```bash
   docker network create proxy-network
   ```

3. **(Optional) nginx-proxy with Let's Encrypt** for automatic SSL:
   ```bash
   docker run -d \
     --name nginx-proxy \
     --network proxy-network \
     -p 80:80 -p 443:443 \
     -v /var/run/docker.sock:/tmp/docker.sock:ro \
     -v nginx-certs:/etc/nginx/certs \
     -v nginx-vhost:/etc/nginx/vhost.d \
     -v nginx-html:/usr/share/nginx/html \
     nginxproxy/nginx-proxy

   docker run -d \
     --name nginx-proxy-acme \
     --network proxy-network \
     --volumes-from nginx-proxy \
     -v /var/run/docker.sock:/var/run/docker.sock:ro \
     -v nginx-acme:/etc/acme.sh \
     nginxproxy/acme-companion
   ```

## Setup Steps

### 1. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `VPS_HOST` | Your VPS IP address or domain | `123.45.67.89` or `vps.example.com` |
| `VPS_USERNAME` | SSH username | `root` or `deploy` |
| `VPS_SSH_KEY` | Private SSH key for authentication | Contents of `~/.ssh/id_rsa` |
| `VPS_PORT` | SSH port (optional, defaults to 22) | `22` |
| `VPS_PROJECT_PATH` | Path to project on VPS | `/home/deploy/portfolio` |

### 2. Generate SSH Key (if you don't have one)

On your **local machine**:
```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/vps_deploy_key
```

Copy the **private key** to GitHub Secrets (`VPS_SSH_KEY`):
```bash
cat ~/.ssh/vps_deploy_key
```

Copy the **public key** to your VPS:
```bash
ssh-copy-id -i ~/.ssh/vps_deploy_key.pub your-user@your-vps-ip
```

Or manually add it to `~/.ssh/authorized_keys` on your VPS.

### 3. Setup Project Directory on VPS

SSH into your VPS and create the project directory:

```bash
ssh your-user@your-vps-ip

# Create project directory
mkdir -p ~/portfolio
cd ~/portfolio

# Copy docker-compose.yml and .env files
# You can either git clone or manually create these files
```

Create `.env` file on VPS:
```bash
cat > .env << 'EOF'
DOMAIN_NAME=www.sudo-ngocnguyen.de
VIRTUAL_PORT=80
LETSENCRYPT_EMAIL=ngoc.nguyen2207@gmail.com
EOF
```

Copy `docker-compose.yml` to your VPS:
```bash
# From your local machine
scp docker-compose.yml your-user@your-vps-ip:~/portfolio/
```

### 4. Update docker-compose.yml for GHCR

Update your `docker-compose.yml` on the VPS to use the GitHub Container Registry image:

```yaml
version: '3.9'

services:
  portfolio:
    image: ghcr.io/ronierichardman/my-neumorphism:latest
    container_name: portfolio
    restart: unless-stopped
    expose:
      - "${VIRTUAL_PORT}"
    networks:
      - proxy-network
    environment:
      - VIRTUAL_HOST=${DOMAIN_NAME},www.${DOMAIN_NAME}
      - VIRTUAL_PORT=${VIRTUAL_PORT}
      - LETSENCRYPT_HOST=${DOMAIN_NAME},www.${DOMAIN_NAME}
      - LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
      - TZ=Europe/Berlin

networks:
  proxy-network:
    external: true
```

### 5. Make GitHub Container Registry Public

1. Go to your GitHub repository
2. Click on "Packages" on the right sidebar
3. Click on your package (my-neumorphism)
4. Go to "Package settings"
5. Scroll down and click "Change visibility" → "Public"

Or authenticate Docker on your VPS:
```bash
echo YOUR_GITHUB_PAT | docker login ghcr.io -u ronierichardman --password-stdin
```

### 6. Test Deployment

Push to master branch:
```bash
git add .
git commit -m "Setup GitHub Actions deployment"
git push origin master
```

Monitor the workflow:
- Go to your repository → Actions tab
- Watch the deployment progress

### 7. Verify Deployment

On your VPS:
```bash
cd ~/portfolio
docker-compose ps
docker logs portfolio
```

Visit your website: https://www.sudo-ngocnguyen.de

## Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connection from local machine
ssh -i ~/.ssh/vps_deploy_key your-user@your-vps-ip

# Check SSH key permissions (should be 600)
chmod 600 ~/.ssh/vps_deploy_key
```

### Docker Permission Issues
```bash
# Add user to docker group on VPS
sudo usermod -aG docker $USER
# Logout and login again
```

### Check Logs
```bash
# On VPS
docker logs portfolio
docker-compose logs -f
```

### Manual Deployment
If GitHub Actions fails, you can manually deploy:
```bash
# On VPS
cd ~/portfolio
docker pull ghcr.io/ronierichardman/my-neumorphism:latest
docker-compose down
docker-compose up -d
```

## Security Best Practices

1. ✅ Use a dedicated deploy user (not root)
2. ✅ Use SSH keys (not passwords)
3. ✅ Restrict SSH key to specific commands if possible
4. ✅ Keep your VPS and Docker updated
5. ✅ Use firewall rules (ufw/iptables)
6. ✅ Enable automatic security updates

## Workflow Triggers

The deployment will automatically run when:
- You push to the `master` branch
- You manually trigger it from Actions tab

## What the Workflow Does

1. ✅ Checks out your code
2. ✅ Builds Docker image with all assets
3. ✅ Pushes image to GitHub Container Registry
4. ✅ SSHs into your VPS
5. ✅ Pulls the latest image
6. ✅ Restarts the container with zero downtime (if using nginx-proxy)
7. ✅ Cleans up old images

## Cost & Performance

- ✅ Free GitHub Actions minutes (2000/month for public repos)
- ✅ Docker layer caching speeds up builds
- ✅ Only changed layers are transferred
- ✅ VPS runs optimized nginx serving static files
