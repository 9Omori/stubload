#!/usr/bin/env bash

function abort
{
    # \e[1;31m == Dark red
    # \e[0m    == Default (white, etc)
    echo -e "\e[1;31mERROR: \e[0m$@"
    exit 1
}

function warn
{
    echo -e "\e[1;31mWARNING: \e[0m$@"
}

function bool
{
    test "$1" == "true" -o "$1" = '1'
}

function help
{
    echo "Usage: ${0##*/} [Argument]"
    echo "stubload: A bash script to create a kernel EFI boot entry"
    echo ""
    echo "  -h   Print this help prompt"
    echo "  -v   Print current version"
    echo "  -V   Verbose output"
    echo "  -R   Allow repeated removals"
    echo "  -l   List boot entry(s)"
    echo "  -c   Creates the boot entry(s)"
    echo "  -r   Removes boot entry(s)"
    echo ""
}

function sanity_check
{
    function root_check
    {
        # id -u == Print current user's UID (root = 0)
        test "$(id -u)" = '0' -o "$USER" == "root"
    }
    function dep_check
    {
        # command -v == Alternative to 'which'
        command -v "efibootmgr" &>/dev/null
    }
    function uefi_check
    {
        # /sys/firmware/efi == Kernel interface to EFI variables
        efibootmgr &>/dev/null && test -d "/sys/firmware/efi"
    }
    root_check || abort "The selected action must be ran as root."
    dep_check || abort "efibootmgr is missing."
    uefi_check || abort "EFI variables not found, stubload is only compatible with UEFI-based systems."
    test -d "$ConfigDir" || mkdir -v $ConfigDir
    unset -f passRoot
}

function config
{
    # '.' == POSIX compatible equivilent to bash's 'source'
    parse_config
    . "$ConfigFile" || abort "$ConfigFile: Failed to parse configuration file."
}

function parse_config
{
    function dir { BootDir="$@" ;}
    function label { Label="$@" ;}
    function target { Target="$@" ;}
    function cmdline { Unicode="$@" ;}
    function ramdisk { [ -f "$@" ] && Unicode+=" initrd=$@ " ;} 
}

function create_entry
{
    sanity_check
    config
    cd $ConfigDir

    let x=1
    until ! ( command -v entry_$x &>/dev/null ); do {
        entry_$x
        let x++

        if ( efibootmgr | grep -q " $Label" ); then {
            warn "$Label: Entry is listed more than once. This may cause issues."
            echo "Use '-crR' to remove entries with the same name."
        } fi

        # '//p*' == Remove 'p' & everything after 'p'
        # '//*p' == Remove 'p' & everything before 'p'
        Part="$(cat /proc/mounts | grep " $BootDir " | awk '{print $1}')"
        Disk="${Part//p*}"
        PartNum="${Part//*p}"

        efibootmgr -c -d "$Disk" -p "$PartNum" -L "$Label" -l "$Target" -u "$Unicode" | grep "$Label" &>$LogFile

        unset "Part" "Disk" "PartNum" "Unicode" "Ramdisk" "Cmdline" "Target" -f "entryExists"

        if ( efibootmgr | grep -q " $Label" ); then {
            echo "$Label: Added boot entry successfully."
        } else {
            abort "$Label: Failed to add boot entry."
        } fi
    } done
}

function remove_entry
{
    sanity_check
    config

    function get_target
    {
        # -E '[0-9.]+' == Print only numbers (0-9)
        efibootmgr | grep " $Label" | sed -n '1p' | awk '{print $1}' | grep -E -o '[0-9.]+'
    }
    function entry_exists
    {
        efibootmgr | grep -q "Boot$(get_target)\*"
    }

    let x=1
    entry_$x

    test "$Label" || abort "No label set in configuration"
    entry_exists && efibootmgr -B -b "$(get_target)" | grep "$Label" &>$LogFile

    if ! ( entry_exists ); then {
        echo "$Label: Removed boot entry."
    } elif ( bool "$Repeat" ); then {
        until ! ( entry_exists ); do {
            efibootmgr -B -b "$(get_target)" | grep "$Label" &>$LogFile
        } done
        echo "$Label: Removed boot entry."
    } else {
        abort "$Label: Failed to remove boot entry."
    } fi
}

function list_entry
{
    echo "Current entries:"

    let x=1
    while ( command -v entry_$x &>/dev/null ); do {
        entry_$x
        efibootmgr | grep -q " $Label" && echo "($x) $Label"
        let x++
    } done
}

function version
{
    Source="https://raw.githubusercontent.com/9Omori/stubload/main"
    function version_check
    {
        if ! cmp -s <(curl -Ls $Source/stubload.sha512sum) <(sha512sum $0 | awk '{print $1}'); then {
            UpdateAvailable=true
        } fi
    }
    version_check
    echo "stubload version 0.1"
    ( bool "$UpdateAvailable" ) && echo "An update is available." || echo "No updates are available."
}

function parse_arg
{
    test "$ARGN" = '0' && FirstAction="help"

    for ARG in $ARGV; do {
        case "$ARG" in
            "V") Verbose=true ;;
            "R") Repeat=true ;;
            "h") FirstAction="help" ;;
            "v") FirstAction="version" ;;
            "l") FirstAction="list_entry" ;;
            "c") SecondAction="create_entry" ;;
            "r") FirstAction="remove_entry" ;;
            *) abort "$ARG: Unrecognised argument" ;;
        esac
    } done
}

function main
{
    # 's/-//g'   == Removes all '-' from arguments
    # 's/./& /g' == Add space between each character
    #  wc -w     == Count all words
    ARGV="$(echo $@ | sed 's/-//g; s/./& /g')"
    ARGN="$(echo $@ | wc -w)"

    ConfigFile="/etc/efistub/stubload.conf"
    ConfigDir="$(dirname $ConfigFile)"

    parse_arg
    bool "$Verbose" && LogFile="/dev/stdout" || LogFile="/dev/null"
    test "$FirstAction" && $FirstAction
    test "$SecondAction" && $SecondAction
    exit 0
}
main $@
