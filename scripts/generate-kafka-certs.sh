#!/usr/bin/env bash
set -euo pipefail

# Generates a local CA and PEM certificates for the 3-broker + 3-controller
# Docker Swarm Kafka stack.
#
# Usage:
#   KAFKA_1_HOST=10.0.0.11 KAFKA_2_HOST=10.0.0.12 KAFKA_3_HOST=10.0.0.13 CERT_PASSWORD=changeit ./scripts/generate-kafka-certs.sh
#
# Optional:
#   CERT_DIR=certs
#   CERT_DAYS=825
#   CA_CN=kafka-swarm-ca
#   CERT_PASSWORD=changeit
#
# If CERT_PASSWORD is set, broker private keys are encrypted and you must export
# the same value as KAFKA_CERTIFICATE_PASSWORD before docker stack deploy.

CERT_DIR="${CERT_DIR:-certs}"
CERT_DAYS="${CERT_DAYS:-825}"
CA_CN="${CA_CN:-kafka-swarm-ca}"
CERT_PASSWORD="${CERT_PASSWORD:-}"

KAFKA_1_HOST="${KAFKA_1_HOST:-broker-1.local}"
KAFKA_2_HOST="${KAFKA_2_HOST:-broker-2.local}"
KAFKA_3_HOST="${KAFKA_3_HOST:-broker-3.local}"
CONTROLLER_1_HOST="${CONTROLLER_1_HOST:-controller-1}"
CONTROLLER_2_HOST="${CONTROLLER_2_HOST:-controller-2}"
CONTROLLER_3_HOST="${CONTROLLER_3_HOST:-controller-3}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

add_san_entry() {
  local value="$1"
  if [[ -n "${SEEN_SANS[$value]:-}" ]]; then
    return
  fi
  SEEN_SANS["$value"]=1

  if [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ "$value" == *:* ]]; then
    echo "IP.$SAN_IP_INDEX = $value" >> "$SAN_FILE"
    SAN_IP_INDEX=$((SAN_IP_INDEX + 1))
  else
    echo "DNS.$SAN_DNS_INDEX = $value" >> "$SAN_FILE"
    SAN_DNS_INDEX=$((SAN_DNS_INDEX + 1))
  fi
}

generate_node_cert() {
  local node_label="$1"
  local service_name="$2"
  local advertised_host="$3"
  local key_file="$CERT_DIR/$service_name.keystore.key"
  local csr_file="$CERT_DIR/$service_name.csr"
  local cert_file="$CERT_DIR/$service_name.keystore.pem"
  local ext_file="$CERT_DIR/$service_name.ext"

  SAN_FILE="$ext_file"
  SAN_DNS_INDEX=1
  SAN_IP_INDEX=1
  declare -gA SEEN_SANS=()

  {
    echo "subjectAltName = @alt_names"
    echo "extendedKeyUsage = serverAuth, clientAuth"
    echo "[alt_names]"
  } > "$ext_file"

  add_san_entry "$service_name"
  add_san_entry "$advertised_host"
  add_san_entry "localhost"
  add_san_entry "127.0.0.1"

  if [[ -n "$CERT_PASSWORD" ]]; then
    openssl genrsa -aes256 -passout "pass:$CERT_PASSWORD" -out "$key_file" 4096
    openssl req -new \
      -key "$key_file" \
      -passin "pass:$CERT_PASSWORD" \
      -out "$csr_file" \
      -subj "/CN=$service_name"
  else
    openssl genrsa -out "$key_file" 4096
    openssl req -new \
      -key "$key_file" \
      -out "$csr_file" \
      -subj "/CN=$service_name"
  fi

  openssl x509 -req \
    -in "$csr_file" \
    -CA "$CERT_DIR/ca.crt" \
    -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial \
    -out "$cert_file" \
    -days "$CERT_DAYS" \
    -sha256 \
    -extfile "$ext_file"

  rm -f "$csr_file" "$ext_file"
  cp "$CERT_DIR/ca.crt" "$CERT_DIR/ca.truststore.pem"

  echo "Generated $node_label cert:"
  echo "  $cert_file"
  echo "  $key_file"
}

require_command openssl

mkdir -p "$CERT_DIR"
chmod 700 "$CERT_DIR"

if [[ -e "$CERT_DIR/ca.key" || -e "$CERT_DIR/ca.crt" ]]; then
  echo "Refusing to overwrite existing CA files in $CERT_DIR" >&2
  echo "Move or delete $CERT_DIR/ca.key and $CERT_DIR/ca.crt to regenerate." >&2
  exit 1
fi

openssl genrsa -out "$CERT_DIR/ca.key" 4096
openssl req -x509 \
  -new \
  -nodes \
  -key "$CERT_DIR/ca.key" \
  -sha256 \
  -days "$CERT_DAYS" \
  -out "$CERT_DIR/ca.crt" \
  -subj "/CN=$CA_CN"

generate_node_cert "broker 1" broker-1 "$KAFKA_1_HOST"
generate_node_cert "broker 2" broker-2 "$KAFKA_2_HOST"
generate_node_cert "broker 3" broker-3 "$KAFKA_3_HOST"
generate_node_cert "controller 1" controller-1 "$CONTROLLER_1_HOST"
generate_node_cert "controller 2" controller-2 "$CONTROLLER_2_HOST"
generate_node_cert "controller 3" controller-3 "$CONTROLLER_3_HOST"

chmod 600 "$CERT_DIR"/*.key
chmod 644 "$CERT_DIR"/*.pem "$CERT_DIR"/*.crt

cat <<EOF

Created Kafka TLS files in: $CERT_DIR

Create Docker Swarm secrets:
  ./scripts/create-kafka-tls-secrets.sh

Client truststore:
  $CERT_DIR/ca.truststore.pem
EOF
