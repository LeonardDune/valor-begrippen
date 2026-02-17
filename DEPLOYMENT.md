# Coolify Deployment Guide

## Overview
Dit document beschrijft hoe je de Skosmos applicatie met Coolify op je VPS deployt met automatische updates via GitHub webhooks.

## Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                      VPS (valor-ecosystem.nl)                │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    Traefik (Reverse Proxy)            │   │
│  │    - SSL/TLS termination (Let's Encrypt)             │   │
│  │    - Routing to services                             │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ▲                                    │
│          ┌───────────────┼───────────────┐                  │
│          │               │               │                  │
│  ┌───────▼──────┐ ┌──────▼──────┐ ┌─────▼─────────┐        │
│  │   Skosmos    │ │   Fuseki    │ │ Varnish Cache │        │
│  │  (Frontend)  │ │  (Triple    │ │   (for        │        │
│  │   (PHP)      │ │   Store)    │ │   Fuseki)     │        │
│  └──────────────┘ └─────────────┘ └───────────────┘        │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Persistent Volumes                      │   │
│  │  - Fuseki databases                                 │   │
│  │  - Application logs                                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘

GitHub → Coolify → Docker Compose → Services
  (Push to main branch)
```

## Prerequisites
- VPS met Docker en Coolify geïnstalleerd
- GitHub account met schrijftoegang tot deze repo
- Domain `begrippen.valor-ecosystem.nl` dat wijst naar je VPS IP

## Stap 1: Voorbereiding op je VPS

### 1.1 Als Traefik nog niet draait
```bash
# Maak het frontend netwerk aan (gebruikt door Traefik en services)
docker network create frontend
```

### 1.2 Coolify installeren (als nog niet gedaan)
```bash
# Volg de instructions van https://coolify.io/docs/installation
curl -fsSL https://get.coollabs.io/docker-compose.yml -o docker-compose.yml
docker compose up -d
```

## Stap 2: Coolify Project Instellen

### 2.1 Inloggen in Coolify
1. Open http://your-vps-ip:3000 in je browser
2. Stel je account in

### 2.2 Git Repository Verbinden
1. Ga naar Settings → Git Providers
2. Voeg GitHub toe (je krijgt instructions)
3. Authorize Coolify op GitHub

### 2.3 Nieuw Deployment Project Maken
1. Klik op "New Project"
2. Selecteer "Docker Compose"
3. Naam: "Skosmos valor-ecosystem"
4. Vul in:
   - **Git Repository**: `https://github.com/[your-username]/valor-begrippen`
   - **Branch**: `main`
   - **Docker Compose File Path**: `docker-compose.prod.yml`

### 2.4 Environment Variabelen Instellen
1. Ga naar het project → Settings → Environment Variables
2. Voeg de volgende toe:
   ```
   DOMAIN=begrippen.valor-ecosystem.nl
   JAVA_OPTIONS=-Xmx2g -Xms1g
   ```
3. Pas meer aan naar behoefte (zie `.env.prod.example`)

### 2.5 Webhook voor Automatische Deployment
1. In Coolify: Project Settings → Webhooks
2. Kopieer de webhook URL
3. In GitHub:
   - Ga naar repo → Settings → Webhooks
   - Klik "Add webhook"
   - URL: (paste je Coolify webhook URL)
   - Events: "Push events"
   - Content type: "application/json"
   - Klik "Add webhook"

## Stap 3: Eerste Deployment

### 3.1 Via Coolify UI
1. Klik in Coolify op "Deploy"
2. Monitor de logs in real-time
3. Wacht tot alle services healthy zijn

### 3.2 Controleer Deployment
```bash
# SSH naar je VPS
ssh user@your-vps-ip

# Check of services draaien
docker ps | grep valor

# Check logs
docker logs valor-skosmos
docker logs valor-fuseki
docker logs valor-fuseki-cache
```

## Stap 4: Domain en SSL Setup

### 4.1 DNS Record
Zorg dat `begrippen.valor-ecosystem.nl` wijst naar je VPS IP:
```
A record: begrippen.valor-ecosystem.nl → [your-vps-ip]
```

### 4.2 Traefik Configuration (als je Traefik op de VPS hebt)

Als je een bestaande Traefik setup hebt, zit automatische SSL erin via de labels in docker-compose.prod.yml

Zorg dat je Traefik:
- Een `frontend` netwerk gebruikt die je services kunnen bereiken
- Let's Encrypt certificate resolver geconfigureerd heeft

Voorbeeld minimale Traefik docker-compose.yml:
```yaml
version: '3.8'
services:
  traefik:
    image: traefik:v3.0
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./letsencrypt:/letsencrypt
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencrypt.acme.email=your-email@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    networks:
      - frontend

networks:
  frontend:
    driver: bridge
```

## Stap 5: Onderhoud & Monitoring

### 5.1 Logs Bekijken
In Coolify dashboard kun je live logs zien van alle services.

### 5.2 Database Backups
Bij volumes `fuseki-data` en `fuseki-logs` worden opgeslagen. Maak regelmatig backups:

```bash
# SSH naar VPS
docker run --rm -v valor-begrippen_fuseki-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/fuseki-data-$(date +%Y%m%d).tar.gz -C /data .
```

### 5.3 Updates toepassen
Zodra je code naar `main` branch pusht:
1. GitHub webhook triggered Coolify
2. Coolify clone bij de nieuwste code
3. Docker images worden opnieuw gebouwd
4. Containers worden geupdate (zero-downtime via health checks)

## Troubleshooting

### Services starten niet
```bash
docker logs valor-skosmos
docker logs valor-fuseki
docker logs valor-fuseki-cache
```

### Verbindingsproblemen tussen services
```bash
# Check netwerk connectivity
docker exec valor-skosmos curl http://fuseki-cache/
docker exec valor-fuseki curl http://localhost:3030/
```

### SSL/HTTPS niet werkend
- Check DNS: `nslookup begrippen.valor-ecosystem.nl`
- Check Traefik logs: `docker logs [traefik-container-id]`
- Controleer firewall port 443

### Performance issues
Ajust in `.env`:
```
JAVA_OPTIONS=-Xmx4g -Xms2g  # Voor grotere datasets
PHP_MEMORY_LIMIT=1G         # Voor meer geheugen in PHP
```

## Nuttige Commands

```bash
# Maak SSH verbinding
ssh user@your-vps-ip

# View alle containers
docker ps

# Bekijk logs van een service
docker logs -f valor-skosmos

# Herstart een service
docker restart valor-skosmos

# Docker Compose status
cd /path/to/deployed/project
docker compose -f docker-compose.prod.yml ps

# Volumes bekijken
docker volume ls | grep valor

# Volume inspectie
docker volume inspect valor-begrippen_fuseki-data
```

## Additional Resources
- [Coolify Documentation](https://coolify.io/docs)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Skosmos Documentation](https://github.com/NatLibFi/Skosmos/wiki)
- [Apache Jena Fuseki](https://jena.apache.org/documentation/fuseki2/)
