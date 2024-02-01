#!/usr/bin/env bash

function abort
{
    echo -e "ERROR: $@"
    exit 1
}

function download
{
    echo "Target: ${1}"
    echo "Save location: ${2}"
    test -d "$(dirname $2)" || mkdir -p "$(dirname $2)"
    curl -L "${1}" -o "${2}"
}

function main
{
    Source="https://raw.githubusercontent.com/9Omori/stubload/main"
    download ${Source}/stubload.sh /usr/local/bin/stubload
    download ${Source}/stubload.conf /etc/efistub/stubload.conf
    chmod +x /usr/local/bin/stubload
}
main
