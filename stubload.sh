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
    echo "  -h   Show this help prompt"
    echo "  -v   Verbose output"
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
    . "$ConfigFile" &>/dev/null || abort "$ConfigFile: Could not source configuration file."
}

function parse_config
{
    function label { Label="$@" ;}
    function target { Target="$@" ;}
    function cmdline { [ "$@" ] && Unicode="$(cat $ConfigDir/$@)" ;}
    function ramdisk { [ -f "$@" ] && Unicode+=" initrd=$@ " ;} 
    
    # '//p*' == Remove 'p' & everything after 'p'
    # '//*p' == Remove 'p' & everything before 'p'
    Part="$(cat /proc/mounts | grep " $BootDir " | awk '{print $1}')"
    Disk="${Part//p*}"
    PartNum="${Part//*p}"
}

function create_entry
{
    cd $ConfigDir
    let x=1
    while ( command -v entry_$x &>/dev/null ); do
    {
        let x++
        if ! ( test "$BootDir" -a "$BootDir" -a "$Target" -a "$Label" ); then
        {
            abort "Required fields are missing. Fix $ConfigFile to continue."
        } fi

        if ( efibootmgr | grep -q " $Label" ); then
        {
            warn "$Label: Entry is listed more than once. This may cause issues."
            echo "Use '-crR' to remove entries with the same name."
        } fi

        parse_config; entry_$x
        efibootmgr -c -d "$Disk" -p "$PartNum" -L "$Label" -l "$Target" -u "$Unicode" | grep " $Label" &>$LogFile

        unset "Part" "Disk" "PartNum" "Unicode" "Ramdisk" "Cmdline" "Target" -f entryExists

        if ( efibootmgr | grep -q " $Label" ); then
        {
            echo "$Label: Added boot entry successfully."
        } else
        {
            abort "$Label: Failed to add boot entry."
        } fi
    } done
}

function remove_entry
{
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
    while ( command -v entry_$x &>/dev/null ); do
    {
        entry_$x; let x++
        test "$Label" || abort "No label set in configuration"

        entryExists && efibootmgr -B -b "$(getTarget)" | grep " $Label" &>$LogFile

        if ( entryExists ) && ( bool "$Repeat" ); then
        {
            while ( entryExists ); do
            {
                efibootmgr -B -b "$(getTarget)" | grep " $Label" &>$LogFile
            } done
        } fi
        unset -f get_target entry_exists
        entryExists && abort "$Label: Failed to remove boot entry." || echo "$Label: Removed boot entry."
    } done
}

function list_entry
{
    echo "Current entries:"

    let x=1
    while ( command -v entry_$x &>/dev/null ); do
    {
        entry_$x
        efibootmgr | grep -q " $Label" && echo "($x) $Label"
        let x++
    } done
}

function parse_arg
{
    test "$ARGN" = '0' && FirstAction="help"

    for ARG in $ARGV; do
    {
        case "$ARG" in
            "h") FirstAction="help" ;;
            "v") Verbose=true ;;
            "R") Repeat=true ;;
            "l") FirstAction="list_entry" ;;
            "c") SecondAction="create_entry" ;;
            "r") FirstAction="remove_entry" ;;
            *) abort "$ARG: Unrecognised argument" ;;
        esac
    } done

    test "$FirstAction" == "remove_entry" -o "$SecondAction" && SanityCheck=true
    test "$FirstAction" -a ! "$SecondAction" && SanityCheck=false
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
    if ( bool "$SanityCheck" ); then
    {
        sanity_check; config
    } fi
    bool "$Verbose" && LogFile="/dev/stdout" || LogFile="/dev/null"
    test "$FirstAction" && $FirstAction
    test "$SecondAction" && $SecondAction
    exit 0
}
main $@
