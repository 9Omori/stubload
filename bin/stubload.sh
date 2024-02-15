#!/usr/bin/env bash

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

function bool()
{
    ( (test "$1" == "true") || (test "$1" = '1') )
}

function err()
{
    echo "${FRED}error:${FNONE} $1"
    exit $2
}

function warn()
{
    echo "${FYELLOW}warning:${FNONE} $1"
    return $2
}

function execq()
{
    command -v "$1" >/dev/null
}

function help()
{
    echo "Usage: $(basename $0) [OPTION]..."
    echo ""
    echo " -h, --help      print this help & exit"
    echo " -v, --verbose   verbose output"
    echo " -d, --debug     add extra information for debugging"
    echo " -V, --version   print version"
    echo " -s, --sudo      gain permissions by sudo/doas"
    echo " -l, --list      list entries"
    echo " -c, --create    create entries"
    echo " -r, --remove    remove entries"
    echo ""
    echo " --force         continue & ignore errors"
    echo " --colour[=y/n]  toggle colour output"
    echo ""
}

function sanity_check()
{
    # id -u -- print current user's UID (root = 0)
    if ! ( (test "$(id -u)" = '0') || (test "$USER" == "root") ); then {
        err "insufficient permissions" 77
    } fi

    # /sys/firmware/efi -- kernel interface to EFI variables
    if ! ( (efibootmgr >/dev/null) && (test -d "/sys/firmware/efi") ); then {
        err "failed to read EFI variables, either your device is unsupported or you need to mount EFIvars" 72
    } fi
    
    if (test -f "$CONFIG_FILE"); then {
        warn "$CONFIG_FILE: configuration file is missing" 72
    } fi
    (test -d "$CONFIG_DIR") || mkdir -v $CONFIG_DIR
}

function debug()
{
    :
}

function set_debug()
{
    function debug()
    {
        echo "${FCYAN}(debug):${FNONE} $@"
    }
}

function colour()
{
    FNONE="$(tput setaf 9)"

    case "$1" in
        ""|"y"|"yes")
        {
            FRED="$(tput setaf 1)"
            FCYAN="$(tput setaf 6)"
            FYELLOW="$(tput setaf 3)"
        } ;;
        "n"|"no")
        {
            unset "FRED" "FCYAN" "FYELLOW"
        } ;;
    esac
}

function config()
{
    function dir() { BOOT_DIR="$1" ;}
    function label() { LABEL="$1" ;}
    function target() { TARGET="$1" ;}
    function cmdline() { UNICODE="$1" ;}
    function ramdisk() { RAMDISK="\\${1///}" ;}

    debug "CONFIG_FILE = $CONFIG_FILE"

    # '.' -- POSIX compatible equivilent to bash's 'source'
    . "$CONFIG_FILE" || err "$CONFIG_FILE: failed to access configuration file" 72
}

function gain_root()
{
    if (execq "sudo"); then {
        SUDO=sudo
    } elif (execq "doas"); then {
        SUDO=doas
    } fi
    debug "SUDO = $SUDO"

    RAWARGV=( $(sed 's/--sudo//g; s/-s/-/g' <<<"${RAWARGV[@]}") )
    debug "RAWARGV = ${RAWARGV[@]}"

    if ! ( (test "$(id -u)" = '0') || (test "$USER" == "root") ); then {
        $SUDO $0 "${RAWARGV[@]}"
        exit $?
    } fi
}

function entry_exists()
{
    grep -q " $LABEL" <(efibootmgr)
}

function create_entry()
{
    sanity_check; config
    cd $CONFIG_DIR

    let x=1
    until ! (execq entry_$x); do {
        entry_$x; let x++

        # '//p*' -- remove 'p' & everything after 'p'
        # '//*p' -- remove 'p' & everything before 'p'
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
            echo "$LABEL: added entry successfully"
        } else {
            err "$LABEL: failed to add entry" 1
        } fi
    } done
}

function remove_entry()
{
    sanity_check; config

    let x=1
    until ! (execq entry_$x); do {
        entry_$x; let x++
        until ! (entry_exists); do {
            # -n 1p       -- print first line only
            # s/ .*//g    -- print first string only
            # s/[^0-9]//g -- print only numbers
            FNTARGET="$(grep "$LABEL" <(efibootmgr) | sed -n '1p' | sed 's/ .*//g; s/[^0-9]//g')"
            debug "FNTARGET = $FNTARGET"
            debug "LABEL = $LABEL"
            (test "$FNTARGET") && efibootmgr -B -b "$FNTARGET" | grep "$LABEL" >>$LOG
        } done
        if (entry_exists); then {
            err "$LABEL: failed to remove entry" 1
        } else {
            echo "$LABEL: removed entry"
        } fi
    } done
}

function list_entry()
{
    sanity_check; config

    let x=1
    until ! (execq entry_$x); do {
        entry_$x; let x++
        grep -q " $LABEL" <(efibootmgr) && echo "$(($x-1))* $LABEL"
    } done
}

function version()
{
    MVER="0.1" SVER="3" BVER="1"
    VERSION="${MVER}.${SVER}-${BVER}"
    DATE="23:22 14.02.2024"
    echo "stubload version $VERSION ($DATE)"
    echo "Licensed under the GPLv3 <https://www.gnu.org/licenses/>"
    debug "Build sha1sum: $(sed 's/ .*//g' <(sha1sum <$0))"
}

function parse_arg()
{
    RAWARGV=( $@ )
    ARGV=($(
        for ARG in $@; do {
            # 's/xyz//g' -- remove 'xyz' from input
            # 's/./& /g' -- add space between each character
            case "$ARG" in
                "--"*) sed 's/--//g' <<<"$ARG" ;;
                "-"*) sed 's/./& /g; s/-//g' <<<"$ARG" | xargs ;;
            esac
        } done
    ))

    function argx()
    {
        if (test ${#ARGX[$1]} = '1'); then {
            err "conflicting arguments provided" 64
        } else {
            ARGX[$1]="$2"
        } fi
    }

    colour
    for ARG in ${ARGV[@]}; do {
        case "$ARG" in
            "force") FORCE_COMPLETE=true ;;
            "verbose"|"v") VERBOSE=true ;;
            "colour") colour ;;
            "colour="*) colour "${ARG##colour=}" ;;
            "debug"|"d") set_debug ;;
            "sudo"|"s") argx 0 "gain_root" ;;
            "version"|"V") argx 1 "version" ;;
            "help"|"h") argx 1 "help" ;;
            "list"|"l") argx 1 "list_entry" ;;
            "remove"|"r") argx 1 "remove_entry" ;;
            "create"|"c") argx 2 "create_entry" ;;
            "colour="*) err "invalid value for 'colour' -- ${ARG##colour=}" 64 ;;
            *) err "invalid argument -- $ARG" 64
        esac
    } done

    debug "ARGV = ${ARGV[@]}"

    if (test ${#ARGX[@]} -lt 1); then {
        err "insufficient arguments provided" 64
    } fi
}

function main()
{
    CONFIG_FILE="/etc/efistub/stubload.conf"
    CONFIG_DIR="$(dirname $CONFIG_FILE)"

    parse_arg "$@"
    (bool "$VERBOSE") && LOG="/dev/stdout" || LOG="/dev/null"

    for exec in ${ARGX[@]}; do {
        "$exec"
    } done

    exit 0
}
main "$@"
