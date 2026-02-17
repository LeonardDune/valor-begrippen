# Quick Start: Skosmos op VPS via Coolify

## TL;DR - De 5 Stappen Plan

### Stap 1: GitHub Voorbereiding
```bash
# Clone/open je fork van de repo
cd valor-begrippen

# Zorg dat deze bestanden in je repo zitten (zouden al gegenereerd zijn):
ls -la docker-compose.prod.yml   # ✓
ls -la .env.prod.example         # ✓
ls -la DEPLOYMENT.md             # ✓
ls -la deploy.sh                 # ✓

# Push alles naar je main branch
git add .
git commit -m "Add production docker-compose and deployment setup"
git push origin main
```

### Stap 2: VPS Voorbereiding (eenmalig)
```bash
# SSH naar je VPS
ssh root@your-vps-ip

# Zorg dat het frontend Docker netwerk bestaat (nodig voor Skosmos/Fuseki/Varnish)
docker network create frontend 2>/dev/null || echo "Frontend netwerk bestaat al"

# Controleer dat het netwerk aanwezig is
docker network ls | grep frontend
```

**Notitie:** Coolify moet al draaiend zijn. Als het frontend netwerk al bestaat (via bestaande Traefik/setup), hoef je niets extra te doen.

### Stap 3: Coolify Project Setup (UI)
1. **Open Coolify**: http://your-vps-ip:3000
2. **New Project** → Docker Compose
3. **Vul in**:
   - Name: `Skosmos valor-ecosystem`
   - Git Repo: `https://github.com/YOUR-USERNAME/valor-begrippen`
   - Branch: `main`
   - Compose File: `docker-compose.prod.yml`

4. **Environment Variables** toevoegen:
   ```
   DOMAIN=begrippen.valor-ecosystem.nl
   JAVA_OPTIONS=-Xmx2g -Xms1g
   ```

5. **Webhooks instellen**:
   - Coolify: Project → Settings → Webhooks → copy URL
   - GitHub: Repo → Settings → Webhooks → Add webhook
     - URL: (paste webhook)
     - Events: Push events
     - Content type: application/json

### Stap 4: Configuratie Files (Optioneel Aanpassen)
Deze bestanden zijn al in je repo en worden automatisch gebruikt:
- `dockerfiles/config/config-docker-compose.ttl` - Skosmos config
- `dockerfiles/config/skosmos.ttl` - Fuseki config  
- `dockerfiles/config/varnish-default.vcl` - Cache config

**Wat je waarschijnlijk wilt doen:**

De belangrijkste file is `config-docker-compose.ttl` - dit bepaalt welke vocabularies beschikbaar zijn. Pas deze aan voordat je deployed:

```bash
# Lokaal (op je laptop/dev machine) VOOR je pusht naar GitHub:
nano dockerfiles/config/config-docker-compose.ttl

# Voeg je vocabularies toe, bijv:
# :my-vocab a skosmos:Vocabulary ;
#   skosmos:label "Mijn Woordenlijst"@nl ;
#   skosmos:sparqlEndpoint <http://fuseki-cache/> ;
#   ...

git add dockerfiles/config/config-docker-compose.ttl
git commit -m "Configure vocabularies"
git push origin main
```

Zodra je pusht, zal Coolify automatisch alles deployen met de nieuwe config.

### Stap 5: Deploy en Test
```bash
# In Coolify: Click "Deploy" button
# Monitor logs in real-time

# Of via SSH:
ssh root@your-vps-ip
docker ps | grep valor    # Services moeten draaien
docker logs valor-skosmos # Check Skosmos logs

# Test
curl https://begrippen.valor-ecosystem.nl
```

## DNS Setup
Zorg dat je DNS record wijst naar je VPS:
```
A record: begrippen.valor-ecosystem.nl → [your-vps-ip]
```

DNS check:
```bash
nslookup begrippen.valor-ecosystem.nl
# Zou je VPS IP moeten tonen
```

## Automatische Updates
Zodra je code naar `main` branch pusht:
1. GitHub → trigger webhook
2. Coolify → pull code, build Docker images
3. Docker Compose → update services
4. Services auto-restart met 0 downtime

## Key Configuratie Files

| File | Doel |
|------|------|
| `docker-compose.prod.yml` | Production orchestration |
| `.env.prod.example` | Environment variables template |
| `dockerfiles/config/config-docker-compose.ttl` | Skosmos configuration (BELANGRIJK!) |
| `dockerfiles/config/skosmos.ttl` | Fuseki SPARQL endpoint config |
| `dockerfiles/config/varnish-default.vcl` | Cache rules |

## Configuratie van je Vocabularies

Het meest cruciale onderdeel na deployment is `config-docker-compose.ttl`. Dit bestand bepaalt:
- Welke vocabularies beschikbaar zijn
- In welke talen
- Vanuit welke SPARQL endpoint (Fuseki)

Voorbeeld entry in config-docker-compose.ttl:
```ttl
:my-vocab a skosmos:Vocabulary ;
  skosmos:language "nl", "en" ;
  skosmos:label "Mijn Woordenlijst"@nl ;
  dcat:title "My Vocabulary"@en ;
  skosmos:sparqlEndpoint <http://fuseki-cache/> ;
  skosmos:defaultLanguage "nl" ;
  .
```

## Troubleshooting

### Services tarten niet?
```bash
# SSH naar VPS
docker logs valor-skosmos
docker logs valor-fuseki
docker logs valor-fuseki-cache
```

### Traefik werkt niet / geen SSL?
```bash
# Check Traefik logs
docker logs [traefik-container-id]

# DNS check
nslookup begrippen.valor-ecosystem.nl
nslookup -type=A begrippen.valor-ecosystem.nl

# Firewall check (poort 443 open?)
telnet your-vps-ip 443
```

### Fuseki is niet bereikbaar via cache?
```bash
# Test verbinding
docker exec valor-skosmos curl http://fuseki-cache/
docker exec valor-fuseki curl http://localhost:3030/
```

### Update werkt niet na git push?
- Check GitHub webhook in Coolify is gekoppeld
- Verifieer webhook secret (als ingesteld)
- Check Coolify project settings
- Trigger manual deploy in Coolify UI

## Performance Tuning

Voor grotere vocabularies, anpassen in `.env.prod`:
```bash
# Meer Java geheugen voor Fuseki
JAVA_OPTIONS=-Xmx4g -Xms2g

# Meer PHP geheugen
PHP_MEMORY_LIMIT=1G

# In docker-compose.prod.yml aanpassen:
VARNISH_MAX_MEMORY=512m  # Cache groter
```

## Backups

Persistente data in volumes:
- `valor-begrippen_fuseki-data` - Databases
- `valor-begrippen_fuseki-logs` - Logs

Backup maken:
```bash
docker run --rm -v valor-begrippen_fuseki-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/fuseki-$(date +%Y%m%d).tar.gz -C /data .
```

## Documentatie

- **Deployment:** [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Deployment Script:** `./deploy.sh`
- **Skosmos Wiki:** https://github.com/NatLibFi/Skosmos/wiki
- **Fuseki Docs:** https://jena.apache.org/documentation/fuseki2/
