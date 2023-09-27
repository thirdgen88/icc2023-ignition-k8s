#!/usr/bin/env bash
set -eo pipefail

# usage redundant-health-check.sh [flags] STATUS_ENDPOINT
#   ie: ./redundant-health-check.sh -r Good -s RUNNING http://localhost:8088/system/gwinfo

# Check for minimum of bash 4
if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
  echo "ERROR: bash version 4 or higher is required for this script, found version ${BASH_VERSINFO[0]}" >&2
  exit 1
fi

function main() {
  if [ ! -x "$(command -v curl)" ]; then
    echo "ERROR: curl is required for this health check" >&2
    exit 1
  fi

  debug "Status endpoint: ${status_endpoint}, expecting state: ${expected_context_state}, timeout: ${timeout_secs}."

  curl_output=$(curl -s --max-time "${timeout_secs}" -L -k -f "${status_endpoint}" 2>&1)

  debug "curl output: ${curl_output}"

  # Gather the fields from gwinfo into an associative array
  IFS=';' read -ra gwinfo_fields_raw <<< "$curl_output"
  declare -A gwinfo_fields=( )
  for field in "${gwinfo_fields_raw[@]}"; do
    IFS='=' read -ra field_parts <<< "$field"
    gwinfo_fields[${field_parts[0]}]=${field_parts[1]}
  done

  # Check ContextStatus and RedundantState fields and exit if no match
  if [ "${gwinfo_fields[ContextStatus]}" != "${expected_context_state}" ]; then
    echo "FAILED: ContextStatus is ${gwinfo_fields[ContextStatus]}, expected ${expected_context_state}" >&2
    exit 1
  elif [ "${gwinfo_fields[RedundantState]}" != "${expected_redundant_state}" ]; then
    # Check RedundantNodeActiveStatus field
    if [ "${gwinfo_fields[RedundantNodeActiveStatus]}" != "Active" ]; then
      echo "FAILED: Not Active and RedundantState is ${gwinfo_fields[RedundantState]}, expected ${expected_redundant_state}" >&2
      exit 1
    fi
  fi
  debug "SUCCESS"
  exit 0
}

function debug() {
  # shellcheck disable=SC2236
  if [ ! -z ${verbose+x} ]; then
    echo "DEBUG: $*"
  fi
}

# Argument Processing
while getopts ":vr:s:t:" opt; do
  case "$opt" in
  v)
    verbose=1
    ;;
  r)
    expected_redundant_state=${OPTARG}
    ;;
  s)
    expected_context_state=${OPTARG}
    ;;
  t)
    timeout_secs=${OPTARG}
    if ! [[ ${timeout_secs} =~ ^[0-9]+$ ]]; then
      echo "ERROR: timeout requires a number" >&2
      exit 1
    fi
    ;;
  \?)
    echo "Invalid option: -${OPTARG}" >&2
    exit 1
    ;;
  :)
    echo "Invalid option: -${OPTARG} requires an argument" >&2
    exit 1
    ;;
  esac
done

# shift positional args based on number consumed by getopts
shift $((OPTIND-1))

# remaining argument will be the status endpoint, also map in defaults for the other optionals
port=${GATEWAY_HTTP_PORT:-8088}
status_endpoint=${1:-"http://localhost:${port}/system/gwinfo"}
timeout_secs=${timeout_secs:-3}
expected_context_state=${expected_context_state:-RUNNING}
expected_redundant_state=${expected_redundant_state:-Good}

# pre-processing done, proceed with main call
main
