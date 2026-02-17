# Coolify Setup & Configuration Guide

## Wat is Coolify?

Coolify is een self-hosted PaaS platform dat:
- Docker services managed
- Automatische SSL/HTTPS setup
- Git webhooks voor auto-deployment
- Monitoring & logging
- Backup & restore functies

**Voordelen voor jouw setup:**
- 1-click deployment
- Automatische updates bij git push
- Geen handmatige Docker-compose commands
- Web UI voor monitoring
- Geschikt voor kleine teams

## Pre-requisites

Op je VPS moet je hebben:
- Docker & Docker Compose
- Ubuntu 20.04+ (of andere Linux)
- Min 2GB RAM, 10GB disk
- Open ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 3000 (Coolify UI)

## Installatie Stap 1: Coolify Installeren

```bash
# SSH naar je VPS
ssh root@your-vps-ip

# Download & installeer Coolify
curl -fsSL https://get.coollabs.io/docker-compose.yml -o docker-compose.yml

# Start Coolify
docker compose up -d

# Check als het draait
docker ps | grep coolify
```

Coolify zou nu beschikbaar moeten zijn op: `http://your-vps-ip:3000`

## Installatie Stap 2: Eerste Keer Setup in Coolify UI

1. **Open** http://your-vps-ip:3000 in browser
2. **Create Account** met email & sterke password
3. **Create Team** (of skip en volg automatische setup)
4. Je bent nu op de Coolify homepage

## Installatie Stap 3: GitHub Integration

### 3.1 GitHub App Toevoegen
1. In Coolify: Settings → Git Providers
2. Klik "Add GitHub"
3. Je wordt doorgestuurd naar GitHub
4. Authorize Coolify App
5. Selecteer de repository (valor-begrippen)

### 3.2 GitHub Secrets (optioneel voor webhook authenticity)
Na GitHub app: Coolify geeft je een webhook URL
- Deze voeg je toe aan GitHub repo → Settings → Webhooks
- Coolify zal ook webhook endpoint automatisch registreren

## Installatie Stap 4: Project Aanmaken

### 4.1 Nieuw Project maken
1. Coolify Dashboard → "New Project"
2. Kies: **Docker Compose**
3. Vul in:
   - **Name**: "Skosmos Valor Ecosystem"
   - **Description**: "Skosmos frontend + Fuseki backend"
   - **Git Source**: Select repository
   - **Branch**: `main`
   - **Dockerfile Path**: `docker-compose.prod.yml`
   - **Base Directory**: `/` (root)

### 4.2 Environment Variables
1. Project → Settings → Environment
2. **Add Environment Variable**:
   ```
   DOMAIN = begrippen.valor-ecosystem.nl
   JAVA_OPTIONS = -Xmx2g -Xms1g
   FUSEKI_PORT = 9030
   CACHE_PORT = 9031
   SKOSMOS_PORT = 9090
   ```

3. **Add Secret Variable** (voor sensitive data):
   ```
   DB_PASSWORD = your-secure-password
   ```
   (Secrets worden niet gelogged)

## Installatie Stap 5: Webhook Configuration

Dit zorgt voor automatische deployment bij git push!

### 5.1 In Coolify Project
1. Project → Settings → Webhooks
2. Kopier de Webhook URL (iets zoals: `https://coolify.io/api/webhooks/...`)
3. Test webhook: "Test Webhook" knop

### 5.2 In GitHub
1. Repository → Settings → Webhooks
2. **Add Webhook**:
   - **Payload URL**: (paste je Coolify webhook URL)
   - **Content type**: application/json
   - **Events**: 
     - [ ] Just the push event
     - [x] Push events
   - **Active**: ✓
   - **SSL verification**: ✓ (if https)

3. GitHub zal een test sturen - Coolify zou moeten reageren met 200 OK

## First Deployment

### Option A: Via Coolify UI (Recommended)
1. Project → **Deploy** knop (grote rode knop rechtsboven)
2. Monitor logs in real-time terwijl Coolify:
   - Code uit git pullt
   - Docker images bouwt
   - Containers start
   - Health checks run
3. Wacht tot status = "Running ✓"

### Option B: Via Git (Automatic)
1. Maak change in je code
2. `git push origin main`
3. GitHub stuurt webhook naar Coolify
4. Coolify start automatische deployment
5. Check project dashboard - status update in real-time

### Option C: Via Coolify API (Advanced)
```bash
# Trigger deployment via curl
curl -X POST https://coolify-domain/api/webhooks/your-webhook-token \
  -H "Content-Type: application/json" \
  -d '{"ref":"refs/heads/main"}'
```

## Monitoring & Logging

### Logs Bekijken
In Coolify Project:
1. **Logs** tab → select service
2. Real-time log streaming
3. Filter op berichten
4. Downloadable logs

### Health Status
- **Running ✓** = All good
- **Restarting** = Service recovering
- **Exit** = Service stopped/crashed
- **Paused** = Manually paused

### Metrics (Advanced)
Project → Metrics:
- CPU usage per service
- Memory usage
- Network I/O
- Container status

## Managing Services

### Starting/Stopping
1. Project → Services list
2. Per service: Start/Stop/Restart icoontjes
3. Of: **Pull & Deploy** = pull latest code + rebuild + restart all

### Viewing Configurations
Project → Configuration:
- Docker Compose file (read-only)
- Environment variables
- Mounted volumes
- Port mappings
- Health checks

### Editing Environment Variables
Project → Settings → Environment:
1. Klik pencil-icon op variable
2. Edit value
3. **Save & Deploy** (auto redeploy!)

## Troubleshooting in Coolify

### Services falen during Deploy
1. **Check logs**: Project → Logs → select service
2. Zoek naar error messages
3. Bekijk volumes mounted correct zijn
4. Controleer memory/disk beschikbaar

```bash
# Via SSH/terminal
docker ps -a | grep valor
docker logs valor-skosmos
docker logs valor-fuseki
```

### Webhook werkt niet
1. GitHub → Webhooks → select webhook
2. Klik "View" → "Recent Deliveries"
3. Check response code (200 = ok)
4. Response payload lezen
5. In Coolify: Settings → Git Log voor meer details

### Project status "Exited"
```bash
# SSH check
docker ps -a | grep valor

# View exit code
docker inspect valor-skosmos | grep -A 2 '"State"'

# Logs specifiek
docker logs valor-skosmos 2>&1 | tail -20
```

### Port conflict
Als port 80/443 al in gebruik:
1. Project → Settings → Port
2. Forward to different external port
3. Traefik labels bepalen routing

## Backups via Coolify

### Database Backups
Project → Settings → Backups:
1. **Automatic Backups**: Enable
2. **Schedule**: Daily 2 AM
3. **Retention**: 30 days

### Manual Backup
Project → Services → volume → Backup

### Restore from Backup
Project → Settings → Backups → select backup → Restore

```bash
# Via terminal
docker run --rm -v valor-begrippen_fuseki-data:/data \
  -v ./backups:/backup \
  alpine tar -tzf /backup/fuseki-data.tar.gz | head
```

## Advanced Configuration

### Custom Domains
Project → Settings → Domain:
- Add custom domain
- Coolify manages SSL via Let's Encrypt
- Point DNS A record to your VPS IP

### Reverse Proxy (Traefik Integration)
Coolify kan werken met bestaande Traefik:
1. Settings → Server → Traefik
2. Enable Traefik integration
3. Services worden auto-geregistreerd bij Traefik

### Resource Limits
Project → Settings → Resources:
- **CPU Limit**: e.g., 2 cores
- **Memory Limit**: e.g., 2GB
- Prevents runaway processes

### Network Policies
Project → Networks:
- Define internal/external networks
- Service-to-service communication
- External routing rules

## Integration Examples

### With GitHub Actions
Coolify kan triggered worden via GitHub Actions:

```yaml
- name: Trigger Coolify deployment
  run: |
    curl -X POST ${{ secrets.COOLIFY_WEBHOOK }} \
      -H "Content-Type: application/json" \
      --data "{\"ref\":\"${{ github.ref }}\"}"
```

Voeg bij GitHub repo → Settings → Secrets:
```
COOLIFY_WEBHOOK = https://your-coolify.com/api/webhooks/...
```

### With Slack Notifications
Project → Settings → Integrations:
- Slack webhook voor deployment notifications
- Receive alerts op deployment status

## Performance Tuning

### Optimize Deployment Speed
1. Project → Settings → Build Strategy
   - Minimal = Faster builds (no cache busting)
   - Standard = Normal (recommended)
   - Full = Fresh everything

2. Use `.dockerignore` in repo:
   ```
   .git
   .github
   node_modules
   vendor
   tests
   ```

### Optimize Runtime Performance
1. Set resource limits (zie hierboven)
2. Enable Traefik caching via labels
3. Use multi-stage Docker builds
4. Monitor via Metrics tab

## Security Best Practices

1. **Strong Passwords**:
   - Coolify dashboard
   - GitHub token/app
   - Secret variables

2. **Network**:
   - Only expose 80/443 to public
   - Keep 3000 (Coolify UI) private or firewalled
   - Use VPN for Coolify admin access

3. **Secrets**:
   - Use "Secret variable" type in Coolify
   - Don't commit secrets to git
   - Rotate periodically

4. **Access Control**:
   - Project → Settings → Team
   - Add team members
   - Set permission levels

5. **Audit Logs**:
   - Settings → Audit Logs
   - See who deployed what when
   - Track configuration changes

## Useful Commands

```bash
# SSH access & monitoring
docker ps -a
docker logs -f [container]
docker stats

# Manual deployment trigger
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

# Check Coolify status
docker compose -f docker-compose.yml ps
```

## Coolify Documentation

- [Official Docs](https://coolify.io/docs)
- [GitHub Issues](https://github.com/coollabsio/coolify)
- [Discord Community](https://discord.gg/coolify)

## Handige Links voor je Setup

- **Git repo**: https://github.com/[username]/valor-begrippen
- **Coolify URL**: http://[your-vps-ip]:3000
- **Skosmos URL**: https://begrippen.valor-ecosystem.nl (na deployment)
- **Fuseki**: http://[your-vps-ip]:9030 (internal)
- **Logs**: In Coolify project dashboard
