#!/bin/sh

set -e

: "${ELASTICSEARCH_HOST?Need to set environment variable 'ELASTICSEARCH_HOST'}"
: "${ELASTICSEARCH_PORT?Need to set environment variable 'ELASTICSEARCH_PORT'}"
: "${USE_SSL?Need to set environment variable 'USE_SSL'}"

rules_directory=${RULES_FOLDER:-rules}
use_ssl=False
ELASTICSEARCH_VERIFY_SSL=False
elasticsearch_url="${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}"
CURL="curl --output /dev/null --silent --head --fail "

if [ "${USE_SSL}"=="True" ] || [ "${USE_SSL}"=="true" ]; then
  elasticsearch_url="https://$elasticsearch_url"
  use_ssl=True
fi

[ -z "${ELASTICSEARCH_CA_CERTS}" ] && ELASTICSEARCH_CA_CERTS=$(find /var/run/secrets -name admin-ca)
[ -z "${ELASTICSEARCH_CLIENT_CERT}" ] && ELASTICSEARCH_CLIENT_CERT=$(find /var/run/secrets -name admin-cert)
[ -z "${ELASTICSEARCH_CLIENT_KEY}" ] && ELASTICSEARCH_CLIENT_KEY=$(find /var/run/secrets -name admin-key)

if [ -n "${ELASTICSEARCH_CLIENT_CERT}" ]; then
  cat ${ELASTICSEARCH_CLIENT_KEY} ${ELASTICSEARCH_CLIENT_CERT} >/etc/ssl/client.pem
  CURL="${CURL} --cert /etc/ssl/client.pem"
  ELASTICSEARCH_CLIENT_CERT=/etc/ssl/client.pem
fi

if [ -n "${ELASTICSEARCH_CA_CERTS}" ]; then
  CURL="${CURL} --cacert ${ELASTICSEARCH_CA_CERTS}"
  ELASTICSEARCH_VERIFY_SSL=True
fi

# Update config files
for file in $(find . -name '*.yaml' -or -name '*.yml');
do
  cat $file | sed "s|es_host: [[:print:]]*|es_host: ${ELASTICSEARCH_HOST}|g" \
    | sed "s|es_port: [[:print:]]*|es_port: ${ELASTICSEARCH_PORT}|g" \
    | sed "s|use_ssl: [[:print:]]*|use_ssl: $use_ssl|g" \
    | sed "s|verify_certs: [[:print:]]*|verify_certs: ${ELASTICSEARCH_VERIFY_SSL}|g" \
    | sed "s|ca_certs: [[:print:]]*|ca_certs: ${ELASTICSEARCH_CA_CERTS}|g" \
    | sed "s|client_cert: [[:print:]]*|client_cert: ${ELASTICSEARCH_CLIENT_CERT}|g" \
    | sed "s|client_key: [[:print:]]*|client_key: ${ELASTICSEARCH_CLIENT_KEY}|g" \
    | sed "s|rules_folder: [[:print:]]*|rules_folder: $rules_directory|g" \
    > config 
    cat config > $file
    rm config
done
echo "-- config.yaml --"
cat config.yaml
echo

echo "Check if elasticsearch is reachable: '$elasticsearch_url'"
# Wait until Elasticsearch is online since otherwise Elastalert will fail.
until $($CURL $elasticsearch_url); do
  echo "Waiting for Elasticsearch..."
  sleep 2
done

# Check if the Elastalert index exists in Elasticsearch and create it if it does not.
if ! $($CURL $elasticsearch_url/elastalert_status); then
  echo "Creating Elastalert index in Elasticsearch..."
  elastalert-create-index --index elastalert_status --old-index "" || sleep 1000
else
  echo "Elastalert index already exists in Elasticsearch."
fi

echo "Starting Elastalert...$@"
exec $@
