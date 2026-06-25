#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/repair-shop-saas}"
APP_USER="${APP_USER:-repairshop}"
SERVICES_DEFAULT="auth-service master-data-service shop-service ticket-service"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1. Run deploy/aws/install-ec2.sh on the EC2 instance first." >&2
    exit 1
  fi
}

random_secret() {
  openssl rand -base64 48 | tr -d '\n'
}

docker_compose() {
  if sudo docker compose version >/dev/null 2>&1; then
    sudo docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    sudo docker-compose "$@"
  else
    echo "Docker Compose is not installed. Run deploy/aws/install-ec2.sh on the EC2 instance first." >&2
    exit 1
  fi
}

ensure_env_file() {
  if [[ -f "$APP_DIR/.env" ]]; then
    return
  fi

  db_password="$(openssl rand -hex 16)"
  jwt_secret="$(random_secret)"

  sudo tee "$APP_DIR/.env" >/dev/null <<EOF
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=repairshop
DB_USER=postgres
DB_PASSWORD=$db_password
JWT_SECRET=$jwt_secret
JWT_EXPIRY_MS=86400000
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
CLOUDINARY_FOLDER=ggfix/master
JAVA_OPTS="-Xms64m -Xmx160m"
SERVICES="$SERVICES_DEFAULT"
EOF
}

prepare_layout() {
  if ! id "$APP_USER" >/dev/null 2>&1; then
    sudo useradd --system --home-dir "$APP_DIR" --shell /sbin/nologin "$APP_USER"
  fi

  sudo mkdir -p "$APP_DIR/bin" "$APP_DIR/services" "$APP_DIR/postgres/init"
  sudo install -m 0755 "$SCRIPT_DIR/run-service.sh" "$APP_DIR/bin/run-service"
  sudo install -m 0644 "$SCRIPT_DIR/repair-shop-saas@.service" /etc/systemd/system/repair-shop-saas@.service
  sudo install -m 0644 "$SCRIPT_DIR/docker-compose.yml" "$APP_DIR/docker-compose.yml"

  sudo rm -rf "$APP_DIR/postgres/init"
  sudo mkdir -p "$APP_DIR/postgres/init"
  sudo cp -R "$PAYLOAD_DIR/postgres/init/." "$APP_DIR/postgres/init/"
}

load_env() {
  set -a
  # shellcheck disable=SC1091
  source "$APP_DIR/.env"
  set +a
  SERVICES="${SERVICES:-$SERVICES_DEFAULT}"
}

copy_jars() {
  for service in $SERVICES; do
    source_jar="$PAYLOAD_DIR/services/$service/$service.jar"
    if [[ ! -f "$source_jar" ]]; then
      echo "Deployment bundle is missing $source_jar" >&2
      exit 1
    fi

    sudo mkdir -p "$APP_DIR/services/$service"
    sudo install -m 0644 "$source_jar" "$APP_DIR/services/$service/$service.jar"
  done

  sudo chown -R "$APP_USER:$APP_USER" "$APP_DIR"
}

start_postgres() {
  docker_compose --env-file "$APP_DIR/.env" -f "$APP_DIR/docker-compose.yml" up -d postgres

  for _ in $(seq 1 40); do
    status="$(sudo docker inspect -f '{{.State.Health.Status}}' repairshop-postgres 2>/dev/null || true)"
    if [[ "$status" == "healthy" ]]; then
      return
    fi
    sleep 3
  done

  echo "Postgres did not become healthy in time." >&2
  sudo docker logs repairshop-postgres || true
  exit 1
}

restart_services() {
  sudo systemctl daemon-reload

  for service in $SERVICES; do
    sudo systemctl enable "repair-shop-saas@$service"
    sudo systemctl restart "repair-shop-saas@$service"
  done

  for service in $SERVICES; do
    for _ in $(seq 1 30); do
      if sudo systemctl is-active --quiet "repair-shop-saas@$service"; then
        echo "$service is active"
        break
      fi

      if sudo systemctl is-failed --quiet "repair-shop-saas@$service"; then
        sudo systemctl --no-pager --full status "repair-shop-saas@$service" || true
        exit 1
      fi

      sleep 2
    done
  done
}

require_command java
require_command docker
require_command openssl

prepare_layout
ensure_env_file
load_env
copy_jars
start_postgres
restart_services

echo "Deployment complete."
