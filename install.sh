#!/usr/bin/env bash

function abort
{
    echo -e "ERROR: $@"
    exit 1
}

function download
{
    echo "Target: $1"
    echo "Save location: $2"
    test -d "$(dirname $2)" || mkdir -p "$(dirname $2)"
    curl -L "$1" -o "$2"
}

function verify
{
    echo "Checking $1 against $2"
    if ! cmp -s <(sha512sum $1 | awk '{print $1}') <(curl -Ls $2 | sha512sum | awk '{print $1}'); then {
        rm -f $1
        abort "$1: Failed sha512sum check!"
    } else {
        echo "$1: Passed sha512sum check."
    } fi
}

function set_perm
{
    if [ -f "$1" ]; then
    {
        chmod +x "$1"
    } fi

    if [ -d "$1" ]; then
    {
        chown -R root:root "$1"
        chmod -R 700 "$1"
    } fi
}

function main
{
    if ! test -w /usr/local/bin -a -w /etc; then {
        abort "/usr/local/bin: Write permission denied."
    } fi

    Source="https://raw.githubusercontent.com/9Omori/stubload/main"

    download $Source/stubload.sh /usr/local/bin/stubload
    test "$DONT_DOWNLOAD_CONFIG" || download $Source/stubload.conf /etc/efistub/stubload.conf

    verify /usr/local/bin/stubload $Source/stubload.sh

    set_perm "/usr/local/bin/stubload"
    set_perm "/etc/efistub"
}
main
