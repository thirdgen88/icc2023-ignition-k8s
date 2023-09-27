#!/usr/bin/env bash
set -eo pipefail
echo "Preparing Web Server TLS Certificates"

# Replace any existing TLS keystore with the updated one from the mounted secret
rm -v -f /data/local/ssl.pfx
cp /run/secrets/web-tls/keystore.p12 /data/local/ssl.pfx

# Modify the TLS keystore to use the alias "ignition" to align with Ignition defaults
existing_alias=$(keytool -list -keystore /data/local/ssl.pfx -storepass ignition | grep PrivateKeyEntry | cut -d, -f 1)
target_alias="ignition"
if [ "${existing_alias}" != "${target_alias}" ]; then
  keytool -changealias -alias "${existing_alias}" -destalias ${target_alias} \
    -keystore /data/local/ssl.pfx -storepass ignition
fi
