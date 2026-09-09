#!/usr/bin/env bash
set -e

echo "=== Spin-up Ephemeral Staging Environment ==="
podman-compose -f podman-compose.yml up -d || docker compose -f podman-compose.yml up -d

echo "Waiting for PostgreSQL and Nginx gateway to be ready..."
sleep 5

echo "Executing Staging Smoke Tests..."
curl -f http://localhost:80/healthz || { echo "Health check failed!"; exit 1; }

echo "Verifying Database Connection..."
docker exec campfire-postgres pg_isready -U campfire_user -d campfire_db || podman exec campfire-postgres pg_isready -U campfire_user -d campfire_db

echo "=== Ephemeral Tests Passed: Tearing Down Staging Stack ==="
podman-compose -f podman-compose.yml down -v || docker compose -f podman-compose.yml down -v
echo "Zero cloud cost incurred."