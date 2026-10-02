#!/usr/bin/env bash
# Creates the AWS resources OrderFlow needs in Floci and loads the seed data.
#
# Runs inside the amazon/aws-cli container (see docker-compose.yml), but also
# works from any machine with AWS CLI v2:
#   AWS_ENDPOINT_URL=http://localhost:4566 ./app/aws-init/init.sh
#
# Safe to run more than once: existing resources are kept, seed products are
# overwritten (stock goes back to the seed values).
set -euo pipefail

: "${AWS_ENDPOINT_URL:=http://localhost:4566}"
: "${AWS_DEFAULT_REGION:=us-east-1}"
: "${AWS_ACCESS_KEY_ID:=test}"
: "${AWS_SECRET_ACCESS_KEY:=test}"
export AWS_ENDPOINT_URL AWS_DEFAULT_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_PAGER=""

PRODUCTS_TABLE="${PRODUCTS_TABLE:-products}"
ORDERS_TABLE="${ORDERS_TABLE:-orders}"
ORDERS_BY_CUSTOMER_INDEX="${ORDERS_BY_CUSTOMER_INDEX:-customerEmail-index}"
ORDER_CREATED_QUEUE="${ORDER_CREATED_QUEUE:-order-created}"
BUCKET="${BUCKET:-orderflow}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="${SCRIPT_DIR}/seed/images"

log() { printf '[aws-init] %s\n' "$*"; }

# Waits until Floci answers, up to 60 seconds.
wait_for_floci() {
  local attempt
  for attempt in $(seq 1 60); do
    if aws dynamodb list-tables >/dev/null 2>&1; then
      log "Floci is up at ${AWS_ENDPOINT_URL}"
      return 0
    fi
    log "Waiting for Floci at ${AWS_ENDPOINT_URL} (${attempt}/60)..."
    sleep 1
  done
  log "Floci did not answer at ${AWS_ENDPOINT_URL}. Is the floci container running?"
  return 1
}

table_exists() {
  aws dynamodb describe-table --table-name "$1" >/dev/null 2>&1
}

create_tables() {
  if table_exists "$PRODUCTS_TABLE"; then
    log "Table ${PRODUCTS_TABLE} already exists"
  else
    aws dynamodb create-table \
      --table-name "$PRODUCTS_TABLE" \
      --attribute-definitions AttributeName=id,AttributeType=S \
      --key-schema AttributeName=id,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST >/dev/null
    log "Created table ${PRODUCTS_TABLE}"
  fi

  if table_exists "$ORDERS_TABLE"; then
    log "Table ${ORDERS_TABLE} already exists"
  else
    aws dynamodb create-table \
      --table-name "$ORDERS_TABLE" \
      --attribute-definitions \
        AttributeName=id,AttributeType=S \
        AttributeName=customerEmail,AttributeType=S \
        AttributeName=createdAt,AttributeType=S \
      --key-schema AttributeName=id,KeyType=HASH \
      --global-secondary-indexes \
        "IndexName=${ORDERS_BY_CUSTOMER_INDEX},KeySchema=[{AttributeName=customerEmail,KeyType=HASH},{AttributeName=createdAt,KeyType=RANGE}],Projection={ProjectionType=ALL}" \
      --billing-mode PAY_PER_REQUEST >/dev/null
    log "Created table ${ORDERS_TABLE} with index ${ORDERS_BY_CUSTOMER_INDEX}"
  fi
}

create_queue() {
  aws sqs create-queue --queue-name "$ORDER_CREATED_QUEUE" >/dev/null
  log "Queue ${ORDER_CREATED_QUEUE} ready"
}

create_bucket() {
  if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
    log "Bucket ${BUCKET} already exists"
  else
    aws s3api create-bucket --bucket "$BUCKET" >/dev/null
    log "Created bucket ${BUCKET}"
  fi
}

# put_product <id> <name> <description> <priceInCents> <stock>
put_product() {
  local id="$1" name="$2" description="$3" price="$4" stock="$5"
  local image_key="images/${id}.svg"

  aws s3api put-object \
    --bucket "$BUCKET" \
    --key "$image_key" \
    --body "${IMAGES_DIR}/${id}.svg" \
    --content-type "image/svg+xml" >/dev/null

  aws dynamodb put-item \
    --table-name "$PRODUCTS_TABLE" \
    --item "{
      \"id\": {\"S\": \"${id}\"},
      \"name\": {\"S\": \"${name}\"},
      \"description\": {\"S\": \"${description}\"},
      \"priceInCents\": {\"N\": \"${price}\"},
      \"stock\": {\"N\": \"${stock}\"},
      \"imageKey\": {\"S\": \"${image_key}\"}
    }" >/dev/null
}

seed_products() {
  # id | name | description | priceInCents | stock
  put_product prd-mechanical-keyboard "Mechanical Keyboard" "Hot-swappable keyboard with brown switches." 45990 25
  put_product prd-wireless-mouse "Wireless Mouse" "Silent ergonomic mouse with USB receiver." 12990 40
  put_product prd-4k-monitor "4K Monitor" "27-inch IPS monitor, 3840x2160." 189900 8
  put_product prd-usb-c-hub "USB-C Hub" "7-in-1 hub with HDMI and card reader." 8990 60
  put_product prd-noise-cancelling-headphones "Noise-Cancelling Headphones" "Over-ear headphones with 30-hour battery." 99900 12
  put_product prd-laptop-stand "Laptop Stand" "Adjustable aluminium stand." 15990 30
  put_product prd-hd-webcam "HD Webcam" "1080p webcam with dual microphones." 24990 15
  put_product prd-led-desk-lamp "LED Desk Lamp" "Dimmable lamp with three colour temperatures." 7990 50
  put_product prd-ergonomic-chair "Ergonomic Chair" "Mesh chair with lumbar support." 129900 3
  put_product prd-vintage-film-camera "Vintage Film Camera" "35mm rangefinder from the 1970s." 64900 0
  log "Seeded 10 products and their images"
}

main() {
  wait_for_floci
  create_tables
  create_queue
  create_bucket
  seed_products
  log "Done"
}

main "$@"
