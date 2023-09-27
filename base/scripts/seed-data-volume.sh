#!/usr/bin/env bash
set -eo pipefail

if [ ! -f /data/.ignition-seed-complete ]; then
    echo "Seeding Ignition Data Volume"
    touch /data/.ignition-seed-complete
    cp -dpR /usr/local/bin/ignition/data/* /data/
fi
