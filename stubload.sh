#!/usr/bin/bash

function bool
{
    test "$1" == "true" -o "$1" = '1'
}

function print
{
    cat <<<"$@"
}

function fprint
{
    print "${0##*/}: $@"
}

function eprint
{
    fprint "$@"
    (bool "$FORCE_COMPLETE") || exit 1
}

function execf
{
    command -v "$1" &>/dev/null
}

function help
{
    print "Usage: ${0##*/} <-h|-v|-V|-n|-s|-l|-c|-r> [--force]"
    print ""
    print "  -h   Print this help prompt"
    print "  -v   Print current version"
    print "  -V   Verbose output"
    print "  -n   Don't recursively remove entry(s)"
    print "  -s   Gain root permissions by sudo if not already root"
    print "  -l   List boot entry(s)"
    print "  -c   Creates the boot entry(s)"
    print "  -r   Removes boot entry(s)"
    print ""
    print "  --force  Force program to continue regardless of warnings/errors"
    print ""
}

function sanity_check
{
    function root_check
    {
        # id -u == Print current user's UID (root = 0)
        if ! test "$(id -u)" = '0' -o "$USER" == "root"; then
            eprint "The selected action must be ran as root."
        fi
    }
    function uefi_check
    {
        # /sys/firmware/efi == Kernel interface to EFI variables
        if ! efibootmgr &>/dev/null && test -d "/sys/firmware/efi"; then
            eprint "EFI variables not found, stubload is only compatible with UEFI-based systems."
        fi
    }
    root_check; uefi_check
    test -d "$CONFIG_DIR" || mkdir -v $CONFIG_DIR
}

function config
{
    # '.' == POSIX compatible equivilent to bash's 'source'
    parse_config
    . "$CONFIG_FILE" || eprint "$CONFIG_FILE: Failed to access configuration file."
}

function parse_config
{
    function dir { BOOT_DIR="$@" ;}
    function label { LABEL="$@" ;}
    function target { TARGET="$@" ;}
    function cmdline { UNICODE="$@" ;}
    function ramdisk { [ -f "$@" ] && UNICODE+=" initrd=$@ " ;} 
}

function gain_root
{
    if test "$(id -u)" = '0' -o "$USER" == "root"; then
        print "User is already root."
    else
        SHORTARGV="$(print $SHORTARGV | sed 's/s//' | tr -d "[:space:]")"
        fprint "Attempting to elevate privileges."
        sudo -u root -H "$SHELL" $0 -"$SHORTARGV"
        exit $?
    fi
}

function create_entry
{
    sanity_check
    config
    cd $CONFIG_DIR

    let x=1
    until ! (execf entry_$x); do {
        entry_$x; let x++

        if (grep -q " $LABEL" <(efibootmgr)); then {
            fprint "${0##*/}: $LABEL: Entry is listed more than once. This may cause issues."
            fprint "Use '-crR' to remove entries with the same name."
        } fi

        # '//p*' == Remove 'p' & everything after 'p'
        # '//*p' == Remove 'p' & everything before 'p'
        PART="$(grep " $BOOT_DIR " /proc/mounts | awk '{print $1}')"
        DISK="${PART//p*}"
        PART_NUM="${PART//*p}"

        efibootmgr -c -d "$DISK" -p "$PART_NUM" -L "$LABEL" -l "$TARGET" -u "$UNICODE" | grep "$LABEL" >>$LOG

        unset "Part" "Disk" "PartNum" "Unicode" "Ramdisk" "Cmdline" "Target" -f "entryExists"

        if (grep -q " $LABEL" <(efibootmgr)); then {
            fprint "$LABEL: Added boot entry successfully."
        } else {
            eprint "$LABEL: Failed to add boot entry."
        } fi
    } done
}

function remove_entry
{
    sanity_check
    config

    function target
    {
        # -E '[0-9.]+' == Print only numbers (0-9)
        grep " $LABEL" <(efibootmgr) | sed -n '1p' | awk '{print $1}' | grep -E -o '[0-9.]+'
    }
    function entry_exists
    {
        grep -q "Boot$(target)\*" <(efibootmgr)
    }

    let x=1
    entry_$x

    until ! (execf entry_$x); do {
        entry_$x; let x++
        test "$LABEL" || eprint "No label set in configuration"
        entry_exists && efibootmgr -B -b "$(target)" | grep "$LABEL" &>$LOG

        if ! (entry_exists); then {
            fprint "$LABEL: Removed boot entry."
        } elif ! (bool "$DONT_REPEAT"); then {
            until ! (entry_exists); do {
                efibootmgr -B -b "$(target)" | grep "$LABEL" &>$LOG
            } done
            fprint "$LABEL: Removed boot entry."
        } else {
            eprint "$LABEL: Failed to remove boot entry."
        } fi        
    } done
}

function list_entry
{
    sanity_check
    config
    
    print "Current entries:"

    let x=1
    until ! (execf entry_$x); do {
        entry_$x; let x++
        grep -q " $LABEL" <(efibootmgr) && print "$(($x-1))* $LABEL"
    } done
}

function version
{
    print "stubload version 0.1"
    if cmp -s <(curl -Ls https://raw.githubusercontent.com/9Omori/stubload/main/stubload.sh) $0; then {
        print "No updates are available."
    } else {
        print "An update is available."
    } fi
}

function parse_arg
{
    # 's/-//g'   == Removes all '-' from arguments
    # 's/./& /g' == Add space between each character
    #  wc -w     == Count all words
    SHORTARGV=$(
        for ARG in $@; do {
            case "$ARG" in
                "--"*) false ;;
                "-"*) sed 's/./& /g; s/-//g' <<<"$ARG" ;;
            esac
        } done
    )

    LONGARGV=$(
        for ARG in $@; do {
            case "$ARG" in
                "--"*) sed 's/--//g' <<<"$ARG" ;;
            esac
        } done
    )

    SHORTARGN="$(wc -w <<<"$SHORTARGV")"
    LONGARGN="$(wc -w <<<"$LONGARGV")"

    if test "$SHORTARGN" -lt '1'; then {
        eprint "Insufficient arguments"
    } fi

    for LONGARG in $LONGARGV; do {
        case "$LONGARG" in
            "force") FORCE_COMPLETE=true ;;
            *) eprint "Invalid argument -- $LONGARG" ;;
        esac
    } done

    for SHORTARG in $SHORTARGV; do {
        case "$SHORTARG" in
            "V") VERBOSE=true ;;
            "n") DONT_REPEAT=true ;;
            "s") readonly arg0="gain_root" && ARGX+=" $arg0" ;;
            "h") readonly arg1="help" && ARGX+=" $arg1" ;;
            "v") readonly arg1="version" && ARGX+=" $arg1" ;;
            "l") readonly arg1="list_entry" && ARGX+=" $arg1" ;;
            "r") readonly arg1="remove_entry" && ARGX+=" $arg1" ;;
            "c") readonly arg2="create_entry" && ARGX+=" $arg2" ;;
            *) eprint "Invalid argument -- $SHORTARG" ;;
        esac
    } done
    ARGX="$(sort -n <<<"$ARGX")"
}

function main
{
    CONFIG_FILE="/etc/efistub/stubload.conf"
    CONFIG_DIR="$(dirname $CONFIG_FILE)"

    parse_arg $@
    bool "$VERBOSE" && LOG="/dev/stdout" || LOG="/dev/null"

    for exec in $ARGX; do
        $exec
    done

    exit 0
}
main $@
