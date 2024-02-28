#!/usr/bin/env bash

base()
{
  for start in $*; do
    $start
  done
}

bool()
{
  [ "$1" == "true" ]
}

die()
{
  local red="\e[1;31m"

  # >&2 -- redirect stdout to stderr
  echo -e "${red}error:${no_colour} $1" >&2; shift
  [ $# -ge 1 ] && echo -e "$*" >&2

  [ "${#force}" -gt 1 ] && return 1
  exit 1
}

warn()
{
  local yellow="\e[1;33m"

  echo -e "${yellow}warning:${no_colour} $*" >&2
  return 1
}

debug()
{
  return
}

set_debug()
{
  debug()
  {
    local cyan="\e[1;36m"

    echo -e "${cyan}debug:${no_colour} $*" >&2
  }
}

find_exec()
{
  eval \
    command -v "$1" >/dev/null
}

help()
{
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

usage()
{
  echo "Usage: `(basename $0)`"
  echo "       [-h|--help] [-v|--verbose] [-V|--version]"
  echo "       [-n|--number <number>] [-l|--list] [-c|--create]"
  echo "       [-r|--remove] [--force] [--config<=file>]"
  exit 1
}

sanity_check()
{
  # id -u -- print current user's UID (root = 0)
  if ! ( [ `(id -u)` = '0' ] || [ "$USER" == "root" ] ); then
    die "insufficient permissions"
  fi

  # /sys/firmware/efi -- kernel interface to EFI variables
  if ! ( (efibootmgr >/dev/null) && [ -d "/sys/firmware/efi" ] ); then
    die \
    "failed to read EFI variables, either your device is unsupported or you need to mount EFIvars"
  fi
  
  if ! [ -f "$configFile" ]; then
    warn "$configFile: configuration file is missing"
  fi

  [ -d "$configDir" ] || mkdir -v $configDir
}

colour()
{
  fNone="\e[0m"
  fRed="\e[1;31m"
  fCyan="\e[1;36m"
  fYellow="\e[1;33m"
}

run_scripts()
{
  for script in `(ls -d -1 /usr/lib/stubload/scripts/* | grep '\.sh')`; do
    debug "$script: running script"
    . "$script" >>$log
    debug "$script: exited with $?"
  done
}

config()
{
  if [ "${#1}" -ge 1 ]; then
    base sanity_check
    configFile="$1"
  fi

  dir() { bootDir="$1" ;}
  label() { label="$1" ;}
  target() { target="$1" ;}
  cmdline() { unicode="$1" ;}
  ramdisk() { ramdisk="\\$1" ;}

  debug "configFile = $configFile"

  # '.' -- POSIX compatible equivilent to bash's 'source'
  . "$configFile" || die "$configFile: failed to access configuration file"
}

entry_exists()
{
  grep -q " $label" <(efibootmgr)
}

create_entry()
{
  base sanity_check config run_scripts
  cd $configDir

  _create()
  {
    entry_$x

    if (entry_exists) && ! (bool "$force"); then
      die \
        "$label: entry already exists" \
        "use '--force' to ignore"
    fi

    local part=`(grep " $bootDir " /proc/mounts | awk '{print $1}')`

    case "$part" in
      "/dev/nvme"*|"/dev/mmcblk"*)
        # 's/p.*//' -- remove 'p' & everything after 'p'
        # 's/.*p//' -- remove 'p' & everything before 'p'
        local disk=`(sed 's/p.*//' <<<"$part")`
        local partNum=`(sed 's/.*p//' <<<"$part")`
        ;;
      "/dev/sd"*)
        # 's/[^0-9]//g' -- remove all non-numbers
        local disk=`(sed 's/sd.*//' <<<"$part")`
        local partNum=`(sed 's/[^0-9]//g' <<<"$part")`
        ;;
      *)
        die \
          "$part: unrecognised disk mapping"
        ;;
    esac

    debug "disk = $disk"
    debug "partNum = $partNum"
    debug "unicode = $unicode"

    efibootmgr -c -d "$disk" -p "$partNum" -L "$label" -l "$target" -u "initrd=$ramdisk $unicode" | grep "$label" >>$log

    if (entry_exists); then
      echo "$label: added entry"
    else
      die "$label: failed to add entry"
    fi
  }

  if [ "${#NUMARGV[@]}" -ge 1 ]; then
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

    until ! (entry_exists); do
      # -n 1p       -- print first line only
      # s/ .*//g    -- print first string only
      # s/[^0-9]//g -- print only numbers
      fnTarget=`(grep "$label" <(efibootmgr) | sed -n '1p' | sed 's/ .*//g; s/[^0-9]//g')`

      debug "fnTarget = $fnTarget"
      debug "label = $label"

      [ "${#fnTarget}" -lt '1' ] || efibootmgr -B -b "$fnTarget" | grep "$label" >>$log
    done

    if (entry_exists); then
      die "$label: failed to remove entry"
    else
      echo "$label: removed entry"
    fi
  }

  if [ "${#NUMARGV[@]}" -ge 1 ]; then
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

    num=`(efibootmgr | grep "$label" | sed -n '1p' | sed 's/Boot//; s/*.*//')`
    if (entry_exists); then
      echo "$num|$x $label "
    else
      debug "$label: entry does not exist"
    fi
  }

  if [ "${#NUMARGV[@]}" -ge 1 ]; then
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
  VERSION="0.1.3-4"
  VERSION_CODE=9
  TIME="00:05"
  DATE="29/02/2024"
  TZONE="GMT"
  LICENSE="GPLv3"

  echo "stubload version $VERSION ($TIME $DATE [$TZONE])"
  echo "Licensed under the $LICENSE <https://www.gnu.org/licenses/>"
  debug "Build sha1sum: `(sed 's/ .*//g' <(sha1sum <$0))`"
  exit 0
}

parse_arg()
{
  RAWARGV=( $@ )
  ARGV=(`
    for ARG in $@; do
      # 's/xyz//g' -- remove 'xyz' from input
      # 's/./& /g' -- add space between each character
      case "$ARG" in
        "--"*) sed 's/--//g' <<<"$ARG" ;;
        "-"*) sed 's/./& /g; s/-//g' <<<"$ARG" | xargs ;;
      esac
    done
  `)

  parse_narg()
  {
    NUMARGV=(`
      for ARG in $*; do
        if (grep -qE '^[0-9]+$' <<<"$ARG"); then
          printf "$ARG "
        fi
      done
    `)

    debug "NUMARGV = ${NUMARGV[@]}"

    if [ "${#NUMARGV[@]}" -lt 1 ]; then
      die "must provide at least 1 number"
    fi
  }

  argx()
  {
    if [ ${#ARGX[$1]} -ge 1 ]; then
      die "conflicting arguments provided"
    else
      ARGX[$1]="$2"
    fi
  }

  for ARG in ${ARGV[@]}; do
    case "$ARG" in
      "force") force=true ;;
      "config="*) config `(sed 's/config=//' <<<"$ARG")` ;;
      "verbose"|"v") set_debug; verbose=true ;;
      "version"|"V") argx 1 "version" ;;
      "help"|"h") argx 1 "help" ;;
      "number"|"n") parse_narg $@ ;;
      "n"*) parse_narg `(sed 's/n//' <<<"$ARG")` $@ ;;
      "list"|"l") argx 1 "list_entry" ;;
      "remove"|"r") argx 1 "remove_entry" ;;
      "create"|"c") argx 2 "create_entry" ;;
      *) die "invalid argument -- $ARG"
    esac
  done

  debug "ARGV = ${ARGV[@]}"

  if [ "${#ARGX[@]}" -lt '1' ]; then
    die \
      "insufficient arguments provided" \
      "try '`(basename $0)` -h' for more info"
  fi
}

configFile="/etc/efistub/stubload.conf"
configDir=`(dirname $configFile)`

no_colour="\e[0m"

parse_arg "$@"
(bool "$verbose") && log="/dev/stdout" || log="/dev/null"

for exec in ${ARGX[@]}; do
  $exec
done

exit 0
