# =====================================================================
# Makefile — Commandes infra yCogniCore Cloud
# Usage : make -C infra <cible>
# =====================================================================

.PHONY: help up down restart logs ps init test clean

help:
	@echo "Commandes disponibles :"
	@echo "  make up       — Démarre les 4 services"
	@echo "  make down     — Arrête les services"
	@echo "  make restart  — Redémarre"
	@echo "  make logs     — Affiche les logs (Ctrl+C pour quitter)"
	@echo "  make ps       — État des services"
	@echo "  make init     — Initialise Vault + MinIO"
	@echo "  make test     — Test de connectivité"
	@echo "  make clean    — ⚠️ Supprime les volumes (DANGEREUX)"

up:
	docker compose -f docker-compose.yml up -d
	@echo ""
	@echo "Attente du démarrage (10s)..."
	@sleep 10
	@docker compose -f docker-compose.yml ps

down:
	docker compose -f docker-compose.yml down

restart:
	docker compose -f docker-compose.yml restart

logs:
	docker compose -f docker-compose.yml logs -f

ps:
	docker compose -f docker-compose.yml ps

init:
	@echo "=== Initialisation Vault ==="
	bash vault/init.sh
	@echo ""
	@echo "=== Initialisation MinIO ==="
	bash minio/init.sh

test:
	@echo "=== Test des services ==="
	@docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "pg-ycc|redis-ycc|vault-ycc|minio-ycc"

clean:
	@echo "⚠️  Suppression des volumes (données perdues)"
	@read -p "Confirmer ? (yes/no) " c; \
	if [ "$$c" = "yes" ]; then \
		docker compose -f docker-compose.yml down -v; \
		echo "✅ Volumes supprimés"; \
	else \
		echo "Annulé"; \
	fi
