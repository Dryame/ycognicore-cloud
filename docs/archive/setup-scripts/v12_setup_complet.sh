#!/bin/bash
set -e
DB="${1:-ycc_tenant_demo001}"
echo "=== V12 CRM — SETUP ==="
psql -h localhost -U postgres -d "$DB" -f db/migration/tenant/V12__crm.sql
psql -h localhost -U postgres -d "$DB" -f db/scripts/test_v12_migration.sql 2>&1 | tail -10
echo "=== V12 TERMINE ==="
