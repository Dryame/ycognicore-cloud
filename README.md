# yCogniCore Cloud

**Plateforme ERP SaaS multi-tenant**

![CI](https://github.com/Dryame/ycognicore-cloud/actions/workflows/ci.yml/badge.svg)
![Spring Boot](https://img.shields.io/badge/Spring%20Boot-4.1.1-green)
![Angular](https://img.shields.io/badge/Angular-22.2.0-red)
![Java](https://img.shields.io/badge/Java-21-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue)

## Structure

- `backend/` - Spring Boot 4.1.1 + Hibernate 7 (multi-tenant)
- `frontend/` - Angular 22 + Signals (zoneless)
- `db/` - Migrations Flyway (15 migrations)
- `infra/` - Docker (PostgreSQL + Redis + Vault + MinIO)
- `docs/` - BACKLOG + ADR + rapports journaliers

## Demarrage rapide

Services Docker :

    docker start pg-ycc vault-ycc redis-ycc minio-ycc

Backend :

    cd backend && ./mvnw spring-boot:run

Frontend :

    cd frontend && npx ng serve

## Documentation

- `docs/BACKLOG.md` - 42 points, 4 horizons
- `docs/adr/` - 17 decisions d'architecture
- `docs/rapports/` - Rapports journaliers
