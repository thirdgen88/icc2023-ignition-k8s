#!/usr/bin/env bash
set -eo pipefail

# Helper script to simply invoke args passed on the CLI
for arg in "$@"; do
  eval "$arg"
done