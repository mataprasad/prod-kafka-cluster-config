#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="${CERT_DIR:-certs}"

create_secret() {
  local secret_name="$1"
  local file_path="$2"

  if [[ ! -r "$file_path" ]]; then
    echo "Missing certificate file: $file_path" >&2
    exit 1
  fi

  if docker secret inspect "$secret_name" >/dev/null 2>&1; then
    echo "Secret already exists, skipping: $secret_name"
    return
  fi

  docker secret create "$secret_name" "$file_path"
}

create_secret broker_1_keystore_pem "$CERT_DIR/broker-1.keystore.pem"
create_secret broker_1_keystore_key "$CERT_DIR/broker-1.keystore.key"
create_secret broker_1_truststore_pem "$CERT_DIR/ca.truststore.pem"

create_secret broker_2_keystore_pem "$CERT_DIR/broker-2.keystore.pem"
create_secret broker_2_keystore_key "$CERT_DIR/broker-2.keystore.key"
create_secret broker_2_truststore_pem "$CERT_DIR/ca.truststore.pem"

create_secret broker_3_keystore_pem "$CERT_DIR/broker-3.keystore.pem"
create_secret broker_3_keystore_key "$CERT_DIR/broker-3.keystore.key"
create_secret broker_3_truststore_pem "$CERT_DIR/ca.truststore.pem"

create_secret controller_1_keystore_pem "$CERT_DIR/controller-1.keystore.pem"
create_secret controller_1_keystore_key "$CERT_DIR/controller-1.keystore.key"
create_secret controller_1_truststore_pem "$CERT_DIR/ca.truststore.pem"

create_secret controller_2_keystore_pem "$CERT_DIR/controller-2.keystore.pem"
create_secret controller_2_keystore_key "$CERT_DIR/controller-2.keystore.key"
create_secret controller_2_truststore_pem "$CERT_DIR/ca.truststore.pem"

create_secret controller_3_keystore_pem "$CERT_DIR/controller-3.keystore.pem"
create_secret controller_3_keystore_key "$CERT_DIR/controller-3.keystore.key"
create_secret controller_3_truststore_pem "$CERT_DIR/ca.truststore.pem"
