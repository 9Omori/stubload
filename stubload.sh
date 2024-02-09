#!/usr/bin/bash

# GPLv3
# Copyright (C) 2024 9Omori (GitHub)
#
# stubload is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3
# as published by the Free Software Foundation.
#
# stubload is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with stubload; if not, see <http://www.gnu.org/licenses/>.

function bool
{
    ( (test "$1" == "true") || (test "$1" = '1') )
}

function println
{
    printf "$@\n"
}

function fprintln
{
    println "${0##*/}: $@"
}

function eprintln
{
    fprintln "${FRED}err:${FNONE} $@"
    (bool "$FORCE_COMPLETE") || exit 1
}

function execq
{
    command -v "$1" >/dev/null
}

function help
{
    println "Usage: ${0##*/} <-h|-v|-V|-s|-l|-c|-r> [--debug|--force]"
    println ""
    println " -h   Print help prompt"
    println " -v   Enable verbose output"
    println " -V   Print current version"
    println " -s   Gain root permissions by sudo/doas"
    println " -l   List boot entries"
    println " -c   Create boot entries"
    println " -r   Remove boot entries"
    println ""
    println " --debug   Add extra information for debugging"
    println " --force   Force continue regardless of warnings/errors"
    println ""
}

function sanity_check
{
    function root_check
    {
        # id -u -- Print current user's UID (root = 0)
        if ! ( (test "$(id -u)" = '0') || (test "$USER" == "root") ); then {
            eprintln "insufficient permissions"
        } fi
    }
    function uefi_check
    {
        # /sys/firmware/efi -- Kernel interface to EFI variables
        if ! ( (efibootmgr >/dev/null) && (test -d "/sys/firmware/efi") ); then {
            eprintln "failed to read EFI variables, either your device is unsupported or you need to mount EFIvars"
        } fi
    }
    root_check; uefi_check
    (test -d "$CONFIG_DIR") || mkdir -v $CONFIG_DIR
}

function debug
{
    :
}

function set_debug
{
    function debug
    {
        println "${FCYAN}debug:${FNONE} $@"
    }
}

function config
{
    # '.' -- POSIX compatible equivilent to bash's 'source'
    parse_config
    debug "CONFIG_FILE = $CONFIG_FILE"
    . "$CONFIG_FILE" || eprintln "$CONFIG_FILE: failed to access configuration file."
}

function parse_config
{
    function dir { BOOT_DIR="$1" ;}
    function label { LABEL="$1" ;}
    function target { TARGET="$1" ;}
    function cmdline { UNICODE="$1" ;}
    function ramdisk { RAMDISK="\\$1" ;} 
}

function gain_root
{
    if (execq "sudo"); then {
        debug "-- s: using sudo"
    } elif (execq "doas"); then {
        debug "-- s: using doas"
        alias sudo=doas
    } else {
        eprintln "sudo/doas not found"
    } fi
    if ! ( (test "$(id -u)" = '0') || (test "$USER" == "root") ); then {
        SHORTARGV=( $(sed 's/s//' <<<"${SHORTARGV[@]}" | tr -d "[:space:]") )
        debug "SHORTARGV = ${SHORTARGV[@]}"
        sudo $0 -"${SHORTARGV[@]}"
        exit $?
    } fi
}

function entry_exists
{
    grep -q " $LABEL" <(efibootmgr)
}

function create_entry
{
    sanity_check; config
    cd $CONFIG_DIR

    let x=1
    until ! (execq entry_$x); do {
        debug "X = $x"
        entry_$x; let x++

        # '//p*' -- Remove 'p' & everything after 'p'
        # '//*p' -- Remove 'p' & everything before 'p'
        PART="$(grep " $BOOT_DIR " /proc/mounts | awk '{print $1}')"
        DISK="${PART//p*}"
        PART_NUM="${PART//*p}"

        debug "DISK = $DISK"
        debug "PART_NUM = $PART_NUM"
        debug "LABEL = $LABEL"
        debug "TARGET = $TARGET"
        debug "UNICODE = initrd=$RAMDISK $UNICODE"
        efibootmgr -c -d "$DISK" -p "$PART_NUM" -L "$LABEL" -l "$TARGET" -u "initrd=$RAMDISK $UNICODE" | grep "$LABEL" >>$LOG

        unset "PART" "DISK" "PART_NUM" "UNICODE" "RAMDISK" "CMDLINE" "TARGET"
        if (entry_exists); then {
            fprintln "$LABEL: added entry successfully"
        } else {
            eprintln "$LABEL: failed to add entry"
        } fi
    } done
}

function remove_entry
{
    sanity_check; config

    let x=1
    until ! (execq entry_$x); do {
        debug "X = $x"
        entry_$x; let x++
        until ! (entry_exists); do {
            # -n 1p       -- Print first line only
            # s/ .*//g    -- Print first string only
            # s/[^0-9]//g -- Print only numbers
            FNTARGET="$(grep "$LABEL" <(efibootmgr) | sed -n '1p' | sed 's/ .*//g; s/[^0-9]//g')"
            debug "FNTARGET = $FNTARGET"
            debug "LABEL = $LABEL"
            (test "$FNTARGET") && efibootmgr -B -b "$FNTARGET" | grep "$LABEL" >>$LOG
        } done
        if (entry_exists); then {
            eprintln "$LABEL: failed to remove entry"
        } else {
            fprintln "$LABEL: removed entry"
        } fi
    } done
}

function list_entry
{
    sanity_check; config

    let x=1
    until ! (execq entry_$x); do {
        debug "X = $x"
        entry_$x; let x++
        grep -q " $LABEL" <(efibootmgr) && println "$(($x-1))* $LABEL"
    } done
}

function version
{
    VERSION="0.1.2"
    println "stubload version $VERSION"
    println "Licensed under the GPLv3 <https://www.gnu.org/licenses/>"
    debug "Build sha1sum: $(sed 's/ .*//g' <(sha1sum <$0))"
}

function parse_arg
{
    # 's/-//g'   -- Removes all '-' from arguments
    # 's/./& /g' -- Add space between each character
    SHORTARGV=$(
        for ARG in $@; do {
            case "$ARG" in
                "--"*) false ;;
                "-"*) sed 's/./& /g; s/-//g' <<<"$ARG" ;;
            esac
        } done
    )
    SHORTARGV=( $SHORTARGV )

    LONGARGV=$(
        for ARG in $@; do {
            case "$ARG" in
                "--"*) sed 's/--//g' <<<"$ARG" ;;
            esac
        } done
    )
    LONGARGV=( $LONGARGV )

    for LONGARG in ${LONGARGV[@]}; do {
        case "$LONGARG" in
            "force") FORCE_COMPLETE=true ;;
            "debug") set_debug ;;
            *) eprintln "invalid argument -- $LONGARG" ;;
        esac
    } done

    for SHORTARG in ${SHORTARGV[@]}; do {
        case "$SHORTARG" in
            "v") VERBOSE=true ;;
            "n") DONT_REPEAT=true ;;
            "s") ARGX[0]="gain_root" ;;
            "V") ARGX[1]="version" ;;
            "h") ARGX[1]="help" ;;
            "l") ARGX[1]="list_entry" ;;
            "r") ARGX[1]="remove_entry" ;;
            "c") ARGX[2]="create_entry" ;;
            *) eprintln "invalid argument -- $SHORTARG" ;;
        esac
    } done

    if (test ${#ARGX[@]} -lt 1); then {
        eprintln "insufficient arguments provided"
    } fi
}

function main
{
    FNONE="\e[0m"
    FRED="\e[1;31m"
    FCYAN="\e[1;36m"

    CONFIG_FILE="/etc/efistub/stubload.conf"
    CONFIG_DIR="$(dirname $CONFIG_FILE)"

    parse_arg "$@"
    bool "$VERBOSE" && LOG="/dev/stdout" || LOG="/dev/null"

    for exec in ${ARGX[@]}; do
        $exec
    done

    exit 0
}
main "$@"
