#!/usr/bin/env bash

ConfigFile="/etc/efistub/stubload.conf"
ConfigDir="$(dirname $ConfigFile)"

function abort
{
    echo -e "ERROR: $@"
    exit 1
}

function bool
{
    test "$1" == "true" -o "$1" == '1'
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

function sanityCheck
{
    function rootCheck
    {
        test "$(id -u)" == '0' -o "${USER}" == "root"
    }
    function depCheck
    {
        command -v "efibootmgr" &>/dev/null
    }
    function uefiCheck
    {
        efibootmgr &>/dev/null && test -d "/sys/firmware/efi"
    }
    rootCheck || abort "The selected action must be ran as root."
    depCheck || abort "efibootmgr is missing."
    uefiCheck || abort "EFI variables not found, stubload is only compatible with UEFI-based systems."
    test -d "${ConfigDIr}" || mkdir -v "${ConfigDir}"
    unset -f passRoot
}

function config
{
    . "${ConfigFile}" &>/dev/null || abort "${ConfigFile}: Could not source configuration file."
}

function createEntry
{
    cd $ConfigDir
    let x=1
    until ! command -v entry_${x} &>/dev/null; do
        entry_${x}; let x++
        if ! test "${BootDir}" -a "${BootDir}" -a "${Target}" -a "${Label}"; then
            abort "Required fields are missing. Please edit ${ConfigFile} and fill in these fields."
        fi

        if efibootmgr | grep -q " ${Label}"; then
            echo "WARNING: ${Label}: Entry is listed more than once. This may cause issues."
            echo "Use '-crR' to remove entries with the same name."
        fi

        local Part="$(cat /proc/mounts | grep " ${BootDir} " | awk '{print $1}')"
        local Disk="${Part//p*}"
        local PartNum="${Part//*p}"
        local Unicode="$(test "$Ramdisk" && echo initrd=$Ramdisk) $(test -f "$Cmdline" && cat ${Cmdline})"

        efibootmgr -c -d "${Disk}" -p "${PartNum}" -L "${Label}" -l "${Target}" -u "${Unicode}" | grep " ${Label}" &>${OutputFile}

        unset Part Disk PartNum Unicode Ramdisk Cmdline Target Label -f entryExists

        if efibootmgr | grep -q " ${Label}"; then
            echo "${Label}: Added boot entry successfully."
        else
            abort "${Label}: Failed to add boot entry."
        fi
    done
}

function removeEntry
{
    function getTarget
    {
        efibootmgr | grep " ${Label}" | sed -n '1p' | awk '{print $1}' | grep -E -o '[0-9.]+'
    }
    function entryExists
    {
        efibootmgr | grep -q "Boot$(getTarget)\*"
    }

    let x=1
    until ! command -v entry_${x} &>/dev/null; do
        entry_${x}; let x++
        test "${Label}" || abort "No label set in configuration"

        entryExists && efibootmgr -B -b "$(getTarget)" | grep " ${Label}" &>${OutputFile}

        if entryExists && bool "$Repeat"; then
            while entryExists; do
                efibootmgr -B -b "$(getTarget)" | grep " ${Label}" &>${OutputFile}
            done
        fi
        unset -f getTarget entryExists
        entryExists && abort "${Label}: Failed to remove boot entry." || echo "${Label}: Removed boot entry."
    done
}

function listEntry
{
    echo "Current entries:"

    let x=1
    until ! command -v entry_${x} &>/dev/null; do
        entry_${x}
        efibootmgr | grep -q " ${Label}" && echo "(${x}) ${Label}"
        let x++
    done
}

ARGV=( $(echo $@ | sed 's/-//g; s/./& /g') )
ARGN="$(echo $@ | wc -w)"

function parseArg
{
    test "${ARGN}" == '0' && FirstAction="help"

    for ARG in ${ARGV[@]}; do
        case "$ARG" in
            "h") FirstAction="help" ;;
            "v") Verbose=true ;;
            "R") Repeat=true ;;
            "l") FirstAction="listEntry" ;;
            "c") SecondAction="createEntry" ;;
            "r") FirstAction="removeEntry" ;;
            *) abort "${ARG}: Unrecognised argument" ;;
        esac
    done

    if test "$FirstAction" == "removeEntry"; then
        SanityCheck=true
    elif test "$FirstAction" -a ! "$SecondAction"; then
        SanityCheck=false
    elif test "$SecondAction"; then
        SanityCheck=true
    fi
}

function main
{
    config; parseArg
    bool "${SanityCheck}" && sanityCheck
    bool "${Verbose}" && OutputFile="/dev/stdout" || OutputFile="/dev/null"
    test "${FirstAction}" && ${FirstAction}
    test "${SecondAction}" && ${SecondAction}
    exit 0
}
main
