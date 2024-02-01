#!/usr/bin/env bash

function abort
{
    echo -e "ERROR: $@"
    exit 1
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
    exit 0
}

function rootCheck
{
    function passRoot
    {
        test "$(id -u)" == '0' -o "${USER}" == "root"
    }
    passRoot || abort "This script must be ran as root."
    unset -f passRoot
}

function config
{
    ConfigFile="/etc/efistub/stubload.conf"
    . "${ConfigFile}" &>/dev/null || abort "${ConfigFile}: Configuration file does not exist."
}

function createEntry
{
    pushd /etc/efistub &>/dev/null
    let x=1
    until ! command -v entry_${x} &>/dev/null; do
        entry_${x}; let x++
        if ! test "${BootDir}" -a "${BootDir}" -a "${Target}" -a "${Label}"; then
            abort "Required fields are missing. Please edit ${ConfigFile} and fill in these fields."
        fi

        if efibootmgr | grep -q " ${Label}"; then
            echo "WARNING: ${Label}: Entry is repeated. Use '-rR' to remove all entries with the same name."
        fi

        local Part="$(cat /proc/mounts | grep " ${BootDir} " | awk '{print $1}')"
        local Disk="${Part//p*}"
        local PartNum="${Part//*p}"
        local Unicode="$(test "$Ramdisk" && echo initrd=$Ramdisk) $(test -f "$Cmdline" && cat ${Cmdline})"

        efibootmgr -c -d "${Disk}" -p "${PartNum}" -L "${Label}" -l "${Target}" -u "${Unicode}" | grep " ${Label}" &>${OutputFile}

        if test "$?" == '0'; then
            echo "${Label}: Added boot entry successfully."
             unset Part Disk PartNum Unicode Ramdisk Cmdline Target Label
        else
            abort "${Label}: Failed to add boot entry."
        fi
    done
    popd /etc/efistub &>/dev/null
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

        if entryExists && test "$Repeat"; then
            while entryExists; do
                efibootmgr -B -b "$(getTarget)" | grep " ${Label}" &>${OutputFile}
            done
        fi

        entryExists && abort "${Label}: Failed to remove boot entry." || echo "${Label}: Removed boot entry."
    done

    unset -f getTarget entryExists
}

function listEntry
{
    echo "Current entries:"

    let x=1
    until ! command -v entry_${x} &>/dev/null; do
        entry_${x}; let x++
        efibootmgr | grep -q " ${Label}" && echo "$(($x-1))* ${Label}"
    done
    exit 0
}

ARGV=( $(echo $@ | sed 's/-//g; s/./& /g') )
ARGN="$(echo $@ | wc -w)"

function parseArg
{
    test "${ARGN}" == '0' && help

    for ARG in ${ARGV[*]}; do
        case "$ARG" in
            "h") FirstAction="help" ;;
            "v") export Verbose=1 ;;
            "R") export Repeat=1 ;;
            "l") FirstAction="listEntry" ;;
            "c") SecondAction="createEntry" ;;
            "r") FirstAction="removeEntry" ;;
            *) abort "${ARG}: Unrecognised argument" ;;
        esac
    done
}

function main
{
    config; parseArg; rootCheck
    test -d "/etc/efistub" || mkdir /etc/efistub
    test "${Verbose}" && OutputFile="/dev/stdout" || OutputFile="/dev/null"
    test "${FirstAction}" && ${FirstAction}
    test "${SecondAction}" && ${SecondAction}
    exit 0
}
main
