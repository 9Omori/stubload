#!/bin/sh

VERSION="0.1.3-5"
VERSION_CODE=11
TIME="17:46"
DATE="04/03/2024"
TZONE="GMT"

EVERSION=`(efibootmgr -V)` EVERSION="${EVERSION//* }"

die()
{
  # \e[1;31m -- change output to red
  # \e[0m -- change output to default
  # >&2 -- redirect stdout to stderr
  echo $'\e[1;31m'"error:"$'\e[0m' "$*" >&2

  (($force)) && return 1
  exit 1
}

base()
{
  for base in $*; do
    eval "$base"
  done
}

find_exec()
{
  eval \
    command -v "$1" >$null
}

help()
{
  # basename -- remove everything before '/' to get
  # just executable name
  echo "stubload version $VERSION"
  echo "Usage: `(basename $0)` [OPTION]..."
  echo
  echo " -h, --help         print help & exit"
  echo " -v, --verbose      verbose output"
  echo " -V, --version      print version"
  echo " -n, --number [#]   specify boot # to target"
  echo " -l, --list         list entries"
  echo " -c, --create       create entries"
  echo " -r, --remove       remove entries"
  echo
  echo " --force            continue & ignore errors"
  echo " --config[=file]    use custom configuration file"
  echo
  exit 0
}

sanity_check()
{
  # id -u -- get user's UID (root=0, standard!=0)
  if ! ([ `(id -u)` = 0 ] || [ "$USER" == "root" ]); then
    die "insufficient permissions"
  fi

  # /sys/firmware/efi -- kernel interface to EFI variables
  if ! ( (eval efibootmgr >$null) && [ -d "/sys/firmware/efi" ] ); then
    die \
      "failed to read EFI variables, either your device is unsupported or you need to mount EFIvars"
  fi

  [ -d "$configDir" ] || mkdir -v $configDir
}

scripts()
{
  # add a '.' to the front of a script's name to disable it,
  # it will be hidden from `ls`
  for script in /lib/stubload/scripts/*.sh; do
    eval . "$script" >>$log
  done
}

config()
{
  if (($#)); then
    base sanity_check
    configFile="$1"
  fi

  dir() { bootDir="$1" ;}
  label() { label="$1" ;}
  target() { target="$1" ;}
  cmdline() { unicode="$1" ;}
  ramdisk() { ramdisk="\\$1" ;}

  # '.' -- POSIX compatible equivilent to bash's 'source'
  . "$configFile" || die "$configFile: failed to access configuration file"
}

entry_exists()
{
  grep -q "$label" <(efibootmgr)
}

create_entry()
{
  base sanity_check config scripts
  cd $configDir

  _create()
  {
    entry_$x

    if (entry_exists) && ! (($force)); then
      die \
        "$label: entry already exists" \
        $'\n'"use '--force' to ignore"
    fi

    # "${part/ */}" -- get only first string
    local part=`(grep " $bootDir " </proc/mounts)`; local part="${part/ */}"

    case "$part" in
      "/dev/nvme"*|"/dev/mmcblk"*)
        # '//p*' -- remove 'p' & everything after 'p'
        # '//*p' -- remove 'p' & everything before 'p'
        local disk="${part//p*}"
        local partNum="${part//*p}"
        ;;
      "/dev/sd"*)
        # -E -o '[0-9]' -- remove all non-numbers
        local disk="${part//sd*}"
        local partNum=`(grep -E -o '[0-9]' <<<"$part" | xargs)`
        ;;
      *)
        die "$part: unrecognised disk mapping"
        ;;
    esac

    echo "create: $label "
    efibootmgr -c -d "$disk" -p "$partNum" -L "$label" -l "$target" -u "initrd=$ramdisk $unicode" | grep "$label" >>$log

    if [ $? != 0 ]; then
      die "$label: failed to add entry"
    fi
  }

  if ((${#NUMARGV[@]})); then
    for x in ${NUMARGV[@]}; do
      _create
    done
  else
    let x=1
    until ! (find_exec entry_$x); do
      _create
      let x++
    done
  fi
}

remove_entry()
{
  base sanity_check config

  _remove()
  {
    entry_$x

    echo "remove: $label "
    until ! (entry_exists); do
      # head -n1 -c8 -- get first line & first 8 characters
      num=`(grep "$label" <(efibootmgr) | head -n1 -c8)` num="${num//Boot}"

      ((${#num})) && efibootmgr -B -b "$num" | grep "$label" >>$log
    done

    if (entry_exists); then
      die "$label: failed to remove entry"
    fi
  }

  if ((${#NUMARGV[@]})); then
    for x in ${NUMARGV[@]}; do
      _remove
    done
  else
    let x=1
    until ! (find_exec entry_$x); do
      _remove
      let x++
    done
  fi
}

list_entry()
{
  base sanity_check config

  _list()
  {
    entry_$x

    num=`(grep "$label" <(efibootmgr) | head -n1 -c8)`
    num="${num//Boot}"
    (entry_exists) && echo "$num|$x $label"
  }

  if ((${#NUMARGV[@]})); then
    for x in ${NUMARGV[@]}; do
      _list
    done
  else
    let x=1
    until ! (find_exec entry_$x); do
      _list
      let x++
    done
  fi
}

version()
{
  echo "stubload version $VERSION"
  echo "efibootmgr version $EVERSION"
  exit 0
}

parse_arg()
{
  RAWARGV=( $* )
  ARGV=(`
    for ARG in $*; do
      # ${ARG##--} -- remove '--' from ARG
      # fold -w1 -- add space between each character
      # echo -n -- echo without adding newline at the end (similar to printf's behaviour)
      case "$ARG" in
        "--"*)
          echo -n "${ARG##--} "
          ;;
        "-"*)
          ARG="${ARG##-}"
          fold -w1 <<<"$ARG"
          ;;
      esac
    done | xargs
  `)

  _parse_narg()
  {
    NUMARGV=(`
      for ARG in $*; do
        # -qE '[^0-9+$]' -- remove anything that doesn't match regex [0-9] (numbers only)
        if (grep -qE '^[0-9]+$' <<<"$ARG"); then
          echo -n "$ARG "
        fi
      done
    `)

    if ! ((${#NUMARGV[@]})); then
      die "must provide at least 1 number"
    fi
  }

  _argx()
  {
    _conflict_check()
    {
      ((${#ARGX[$1]})) && die "conflicting arguments provided"
    }

    case "$1" in
      "version"|"help"|"list_entry"|"remove_entry")
        _conflict_check 1
        ARGX[1]="$1"
        ;;
      "create_entry")
        _conflict_check 2
        ARGX[2]="$1"
        ;;
      *)
        _conflict_check 0
        ARGX[0]="$1"
        ;;
    esac
  }

  for ARG in ${ARGV[@]}; do
    case "$ARG" in
      "force") force=1 ;;
      "config="*) config "${ARG##config=}" ;;
      "verbose"|"v") verbose=1 ;;
      "version"|"V") _argx version ;;
      "help"|"h") _argx help ;;
      "number"|"n"*) _parse_narg $* ;;
      "list"|"l") _argx list_entry ;;
      "remove"|"r") _argx remove_entry ;;
      "create"|"c") _argx create_entry ;;
      *) die "invalid argument -- $ARG"
    esac
  done

  ((${#ARGX[@]})) || _argx help
}

configFile="/etc/efistub/stubload.conf"
configDir=`(dirname $configFile)`
null=/dev/null

parse_arg "$*"

(($verbose)) && log="/dev/stdout" || log="/dev/null"

for exec in ${ARGX[@]}; do
  eval "$exec"
done
