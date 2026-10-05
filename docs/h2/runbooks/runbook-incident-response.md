# Runbook — Réponse aux incidents

**Projet** : yCogniCore Cloud
**Sprint** : H2 — BL-021

## Catégories
- N1 Critique : BDD inaccessible, backend down, faille sécurité
- N2 Majeur : service Docker down, latence > 2s
- N3 Modéré : logs anormaux, erreur endpoint

## Étape 1 — Constat

    docker ps --format "table {{.Names}}\t{{.Status}}"
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/actuator/health
    tail -50 /tmp/backend-run.log

## Étape 2 — Causes fréquentes
- `Connection refused` PostgreSQL → restart pg-ycc
- `Vault sealed` → vault/init.sh
- `401` en masse → rotation Vault

## Étape 3 — Actions

    docker restart pg-ycc vault-ycc redis-ycc minio-ycc
    lsof -t -i :8080 | xargs -r kill -9
    cd ~/projets/ycognicore-cloud/backend
    ./mvnw spring-boot:run 2>&1 | tee /tmp/backend-run.log

## Étape 4 — Post-mortem
Rédiger `docs/incidents/YYYYMMDD-<titre>.md` : chronologie, cause,
correctif, préventif.

**Fin du runbook**
