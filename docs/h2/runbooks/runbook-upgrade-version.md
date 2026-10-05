# Runbook — Mise à jour de version (zero-downtime)

**Projet** : yCogniCore Cloud
**Sprint** : H2 — BL-021

## Prérequis
- Version taggée (`vX.Y.Z`)
- Tests E2E OK en staging
- Backup récent (< 1h)

## Étapes

### 1. Backup pré-déploiement

    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    pg_dump -h localhost -U postgres -d ycc_control_plane \
      | gzip > /backups/ycc_control_plane_${BACKUP_DATE}.sql.gz

### 2. Pull nouvelle version

    cd ~/projets/ycognicore-cloud
    git fetch --tags && git checkout vX.Y.Z

### 3. Compiler

    cd backend && ./mvnw clean package -DskipTests
    cd ../frontend && npm ci && npx ng build --configuration production

### 4. Redémarrer backend

    lsof -t -i :8080 | xargs -r kill -9
    cd ../backend
    nohup java -jar target/backend-0.0.1-SNAPSHOT.jar > /tmp/backend-run.log 2>&1 &

### 5. Vérifier

    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/actuator/health

## Rollback

    git checkout vX.Y.(Z-1)
    cd backend && ./mvnw clean package -DskipTests
    lsof -t -i :8080 | xargs -r kill -9
    nohup java -jar target/backend-0.0.1-SNAPSHOT.jar > /tmp/backend-run.log 2>&1 &

## Checklist
- [ ] Backend démarré
- [ ] Flyway OK
- [ ] Health check 200
- [ ] Login Superadmin OK

**Fin du runbook**
