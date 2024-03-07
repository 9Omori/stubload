#!/usr/bin/env bash

VERSION="0.1.3-6"
VERSION_CODE=12
TIME="22:02"
DATE="07/03/2024"
TZONE="gmt"

EVERSION=$(efibootmgr -V) EVERSION="${EVERSION//* }"

die()
{
  # \e[1;31m -- change output to red
  # \e[0m -- change output to default
  # >&2 -- redirect stdout to stderr
  echo $'\e[1;31m'"error:" $'\e[0m'"$1" >&2
  shift

  while (($#)); do
    echo "$1" >&2
    shift
  done

  (($force)) && return 1
  exit 1
}

execq()
{
  eval command -v "$1" >$void
}

sub()
{
  if ((${#NUMARGV[@]})); then
    for x in ${NUMARGV[@]}; do
      eval _$1
    done
  else
    let x=1
    until ! (execq entry_$x); do
      eval _$1
      let x++
    done
  fi
}

help()
{
  # ${0##*/} -- remove everything before '/' to get
  # just executable name
  echo \
"stubload version $VERSION
Usage: ${0##*/} [OPTION]...

 -h, --help        print help & exit
 -v, --verbose     don't suppress output
 -V, --version     print version
 -l, --list        list entries
 -c, --create      create entries
 -r, --remove      remove entries
 -[n]              specify entry's number to target

 --force           ignore errors
 --config [file]   specify configuration file
"
}

sanity_check()
{
  # (($UID)) -- UID is non-zero (root UID = 0)
  if (($UID)) || [ "$USER" != "root" ]; then
    die "insufficient permissions"
  fi

  # /sys/firmware/efi -- kernel interface to EFI variables
  if (! eval efibootmgr >$void) || [ ! -d "/sys/firmware/efi" ]; then
    die \
      "failed to read EFI variables, either your device is unsupported or you need to mount EFIvars"
  fi

  configDir=$(basename $config)
  [ -d "$configDir" ] || mkdir -v $configDir
}

scripts()
{
  # add a '.' to the front of a script's name to disable it,
  # it will be hidden from `ls`
  for script in /lib/stubload/scripts/*.sh; do
    bash "$script" >>$log
  done
}

config()
{
  if (($#)); then
    sanity_check
    config="$1"
  fi

  dir() { bootDir="$1" ;}
  label() { label="$1" ;}
  target() { target="$1" ;}
  cmdline() { unicode="$1" ;}
  ramdisk() { ramdisk="\\$1" ;}

  source $config || die "$config: failed to access configuration file"
}

entry_exists()
{
  [[ "$(efibootmgr)" =~ "$label" ]]
}

create_entry()
{
  sanity_check; config; scripts
  cd $configDir

  _create_entry()
  {
    entry_$x

    if (entry_exists) && ! (($force)); then
      die \
        "$label: entry already exists"\
        "use '--force' to ignore"
    fi

    # "${part/ */}" -- get only first string
    local part=$(grep " $bootDir " </proc/mounts); local part="${part/ */}"

    case "$part" in
      "/dev/nvme"*|"/dev/mmcblk"*)
        # '//p*' -- remove 'p' & everything after 'p'
        # '//*p' -- remove 'p' & everything before 'p'
        local disk="${part//p*}"
        local partInt="${part//*p}"
        ;;
      "/dev/sd"*)
        # '//![0-9]' -- remove all non-numbers
        local disk="${part//sd*}"
        local partInt="${part//[!0-9]}"
        ;;
      *)
        die "$part: unrecognised disk mapping"
        ;;
    esac

    echo "create: $label "
    efibootmgr -c -d "$disk" -p "$partInt" -L "$label" -l "$target" -u "initrd=$ramdisk $unicode" | grep "$label" >>$log

    if (($?)); then
      die "$label: failed to add entry"
    fi
  }

  sub ${FUNCNAME[0]}
}

remove_entry()
{
  sanity_check; config

  _remove_entry()
  {
    entry_$x

    echo "remove: $label "
    until ! (entry_exists); do
      # head -n1 -c8 -- get first line & first 8 characters
      int=$(efibootmgr | grep "$label" | head -n1 -c8) int="${int//Boot}"

      ((${#int})) && efibootmgr -B -b "$int" | grep "$label" >>$log
    done

    if (entry_exists); then
      die "$label: failed to remove entry"
    fi
  }

  sub ${FUNCNAME[0]}
}

list_entry()
{
  sanity_check; config

  _list_entry()
  {
    entry_$x

    int=$(efibootmgr | grep "$label" | head -n1 -c8) int="${int##Boot}"
    (entry_exists) && echo "$int|$x $label"
  }

  sub ${FUNCNAME[0]}
}

version()
{
  echo "stubload version $VERSION"
  echo "efibootmgr version $EVERSION"
  exit 0
}

parse_arg()
{
  # (($#)) -- number of arguments is non-zero
  while (($#)); do
    case "$1" in
      "--config")
        shift
        config="$1"
      ;;
      "--"*)
        ARGV+=( ${1##--} )
        ;;
      "-"*)
      # ${1//[!0-9]} -- remove all non-numbers from $1
        if ((${1//[!0-9]})); then
          NUMARGV+=( ${1//[!0-9]} )
        else
          # fold -w1 -- add spaces between each character
          ARGV+=( $(fold -w1 <<<"${1##-}") )
        fi
        ;;
    esac
    # move $2 to $1
    shift
  done

  ARGV=($(xargs <<<"${ARGV[@]}"))
  NUMARGV=($(xargs <<<"${NUMARGV[@]}"))

  _arg()
  {
    case "$1" in
      "version"|"help"|"list_entry"|"remove_entry") i=1 ;;
      "create_entry") i=2 ;;
      *) i=0 ;;
    esac

    if ((${#ARGX[$i]})); then
      die "conflicting arguments provided"
    else
      ARGX[$i]="$1"
    fi
  }

  for ARG in ${ARGV[@]}; do
    case "$ARG" in
      "force") force=1 ;;
      "verbose"|"v") verbose=1 ;;
      "version"|"V") _arg "version" ;;
      "help"|"h") _arg "help" ;;
      "list"|"l") _arg "list_entry" ;;
      "remove"|"r") _arg "remove_entry" ;;
      "create"|"c") _arg "create_entry" ;;
      *) die "invalid argument -- $ARG"
    esac
  done

  ((${#ARGX[@]})) || _arg "help"
}

((${#config})) || config="/etc/efistub/stubload.conf"
void=/dev/null

if (($verbose)); then
  log="/dev/stdout"
else
  log="/dev/null"
fi

parse_arg $*
for exec in ${ARGX[@]}; do
  eval $exec
done
