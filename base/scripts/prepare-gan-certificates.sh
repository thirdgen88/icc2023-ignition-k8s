#!/usr/bin/env bash
set -eo pipefail
echo "Preparing Gateway Network Certificates"

# Global variable defaults
IGNITION_DATA_DIR="/data"
GAN_CA_SECRETS_DIR="/run/secrets/ignition-gan-ca"
GAN_SECRETS_DIR="/run/secrets/gan-tls"
METRO_KEYSTORE_ALIAS="metro-key"
METRO_KEYSTORE_PASSPHRASE="metro"
GWBK_LOCATION=""

###############################################################################
# Places GAN CA Certificate and GAN Client Keystores into place
###############################################################################
function main() {
  # Populate GAN CA Certificate into the trusted certs folder
  populateGanCaCertificate

  # Update the alias in the inbound GAN PKCS#12 keystore and place into `data/local`
  populateGanKeystore

  # Update the GWBK with the GAN CA Certificate trust
  if [ -n "${GWBK_LOCATION:-}" ]; then
    updateGwbk
  fi
}

###############################################################################
# Places the GAN Client Keystore into the Ignition data/local folder
###############################################################################
function populateGanKeystore() {
  info "Populating GAN Client Keystore into Ignition data/local/metro-keystore"

  # Replace any existing GAN client keystore with the updated one from the mounted secret
  rm -v -f "${IGNITION_DATA_DIR}/local/metro-keystore"
  cp "${GAN_SECRETS_DIR}/keystore.p12" "${IGNITION_DATA_DIR}/local/metro-keystore"

  # Modify the GAN client keystore to use the alias "metro-key" to align with Ignition defaults
  existing_alias=$(keytool -list -keystore "${IGNITION_DATA_DIR}/local/metro-keystore" -storepass ${METRO_KEYSTORE_PASSPHRASE} | grep PrivateKeyEntry | cut -d, -f 1)
  target_alias="${METRO_KEYSTORE_ALIAS}"
  if [ "${existing_alias}" != "${target_alias}" ]; then
    keytool -changealias -alias "${existing_alias}" -destalias "${target_alias}" \
      -keystore "${IGNITION_DATA_DIR}/local/metro-keystore" -storepass ${METRO_KEYSTORE_PASSPHRASE}
  fi
}

###############################################################################
# Places the GAN CA Certificate into the Ignition gateway network trusted certs
###############################################################################
function populateGanCaCertificate() {
  info "Populating GAN CA Certificate into Ignition gateway network trusted certs folders"

  # Copy the GAN Issuer CA certificate to trusted certs for server/client to establish root trust
  mkdir -v -p "${IGNITION_DATA_DIR}/gateway-network/server/security/pki/trusted/certs/"
  mkdir -v -p "${IGNITION_DATA_DIR}/gateway-network/client/security/pki/trusted/certs/"
  cp -v "${GAN_CA_SECRETS_DIR}/ca.crt" "${IGNITION_DATA_DIR}/gateway-network/server/security/pki/trusted/certs/ignition-gan-ca.crt"
  cp -v "${GAN_CA_SECRETS_DIR}/ca.crt" "${IGNITION_DATA_DIR}/gateway-network/client/security/pki/trusted/certs/ignition-gan-ca.crt"
}

###############################################################################
# Updates the GWBK with the GAN CA Certificate trust
###############################################################################
function updateGwbk() {
  info "Updating GWBK with GAN CA Certificate trust"

  # Target destination paths for the GAN CA certificate
  local dest_locations=( 
    "gateway-network/server/security/pki/trusted/certs/ignition-gan-ca.crt"
    "gateway-network/client/security/pki/trusted/certs/ignition-gan-ca.crt"
  )

  # Remove existing files in destination location (if present)
  zip -d "${GWBK_LOCATION}" "${dest_locations[@]}" || true
  
  # Add the GAN CA Certificate to the GWBK in client/server folders
  for dest in "${dest_locations[@]}"; do
    zip -j "${GWBK_LOCATION}" "${GAN_CA_SECRETS_DIR}/ca.crt" "${dest}"
    # NOTE: this seems to fail on macOS zipnote
    printf "@ ca.crt\n@=%s\n" "${dest}" | zipnote -w "${GWBK_LOCATION}"
  done

  debug "Zip contents:\n$(unzip -l "${GWBK_LOCATION}")"
}

###############################################################################
# Alias for printing to console/stdout
# Arguments:
#   <...> Content to print
###############################################################################
function info() {
  readarray -t message_arr <<< "${*}"
  for message_line in "${message_arr[@]}"; do
    printf "%s\n" "${message_line}"
  done
}

###############################################################################
# Outputs to stderr
###############################################################################
function debug() {
  # shellcheck disable=SC2236
  if [ ! -z ${verbose+x} ]; then
    >&2 echo "  DEBUG: $*"
  fi
}

###############################################################################
# Print usage information
###############################################################################
function usage() {
  >&2 echo "Usage: $0 -a <alias> -c <path/to/ca/secret> -s <path/to/gan/secret> -d <path/to/data/folder> [-g <path/to/gwbk>]"
  >&2 echo "  -a <alias> - The alias to use for the GAN client keystore (default: ${METRO_KEYSTORE_ALIAS})"
  >&2 echo "  -c <path/to/ca/secret> - The path to the mounted secret containing the GAN CA certificate (default: ${GAN_CA_SECRETS_DIR})"
  >&2 echo "  -s <path/to/gan/secret> - The path to the mounted secret containing the GAN client certs/keystore (default: ${GAN_SECRETS_DIR})"
  >&2 echo "  -d <path/to/data/folder> - The path to the Ignition data folder (default: ${IGNITION_DATA_DIR})"
  >&2 echo "  -g <path/to/gwbk> - Supply a GWBK to attempt to update with GAN CA trust"
  >&2 echo "  -h - Print this help message"
  >&2 echo "  -v - Enable verbose output"
}

# Argument Processing
while getopts ":hva:c:s:d:g:" opt; do
  case "$opt" in
  v)
    verbose=1
    ;;
  a)
    METRO_KEYSTORE_ALIAS="${OPTARG}"
    ;;
  c)
    GAN_CA_SECRETS_DIR="${OPTARG}"
    ;;
  s)
    GAN_SECRETS_DIR="${OPTARG}"
    ;;
  d)
    IGNITION_DATA_DIR="${OPTARG}"
    ;;
  g)
    GWBK_LOCATION="${OPTARG}"
    ;;
  h)
    usage
    exit 0
    ;;
  \?)
    usage
    echo "Invalid option: -${OPTARG}" >&2
    exit 1
    ;;
  :)
    usage
    echo "Invalid option: -${OPTARG} requires an argument" >&2
    exit 1
    ;;
  esac
done

# shift positional args based on number consumed by getopts
shift $((OPTIND-1))

# Perform argument checks
if [ ! -f "${GAN_CA_SECRETS_DIR}/ca.crt" ]; then
  >&2 echo "ERROR: GAN CA Certificate not found at ${GAN_CA_SECRETS_DIR}/ca.crt"
  usage
  exit 1
fi

if [ ! -f "${GAN_SECRETS_DIR}/keystore.p12" ]; then
  >&2 echo "ERROR: GAN Client Keystore not found at ${GAN_SECRETS_DIR}/keystore.p12"
  usage
  exit 1
fi

if [ ! -d "${IGNITION_DATA_DIR}" ]; then
  >&2 echo "ERROR: Ignition Data Directory not found at ${IGNITION_DATA_DIR}"
  usage
  exit 1
fi

if [ -n "${GWBK_LOCATION:-}" ] && [ ! -f "${GWBK_LOCATION}" ]; then
  >&2 echo "ERROR: GWBK not found at ${GWBK_LOCATION}"
  usage
  exit 1
fi

# check if zip and zipnote commands are installed and exit if gwbk is supplied
if [ -n "${GWBK_LOCATION:-}" ]; then
  if ! command -v zip &> /dev/null; then
    >&2 echo "ERROR: GWBK specified, but 'zip' command not found"
    exit 1
  fi
  if ! command -v zipnote &> /dev/null; then
    >&2 echo "ERROR: GWBK specified, but 'zipnote' command not found"
    exit 1
  fi
fi

main