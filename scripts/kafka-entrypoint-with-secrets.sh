#!/usr/bin/env bash
set -euo pipefail

read_secret() {
  local path="$1"
  if [[ ! -r "$path" ]]; then
    echo "Required Docker secret is missing or unreadable: $path" >&2
    exit 1
  fi
  tr -d '\r\n' < "$path"
}

export KAFKA_CLIENT_PASSWORDS
KAFKA_CLIENT_PASSWORDS="$(read_secret /run/secrets/kafka_client_password)"

export KAFKA_INTER_BROKER_PASSWORD
KAFKA_INTER_BROKER_PASSWORD="$(read_secret /run/secrets/kafka_inter_broker_password)"

export KAFKA_CONTROLLER_PASSWORD
KAFKA_CONTROLLER_PASSWORD="$(read_secret /run/secrets/kafka_controller_password)"

export KAFKA_CERTIFICATE_PASSWORD
KAFKA_CERTIFICATE_PASSWORD="$(read_secret /run/secrets/kafka_certificate_password)"

exec /opt/bitnami/scripts/kafka/entrypoint.sh /opt/bitnami/scripts/kafka/run.sh
