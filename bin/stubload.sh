#!/usr/bin/env bash

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

set -o posix

echo()
{
  # 2>&1 -- redirect stderr to stdout
  cat <<<"$*" 2>&1
}

die()
{
  # >&2 -- redirect stdout to stderr
  cat <<<"${FRED}error:${FNONE} $*" >&2
  exit 1
}

warn()
{
  cat <<<"${FYELLOW}warning:${FNONE} $*" >&2
  return 1
}

bool()
{
  [ "$1" = "true" ]
}

execq()
{
  command -v "$1" >/dev/null
}

help()
{
  echo "Usage: `(basename $0)` [OPTION]..."
  echo
  echo " -h, --help      print help & exit"
  echo " -v, --verbose   verbose output"
  echo " -d, --debug     add extra information for debugging"
  echo " -V, --version   print version"
  echo " -s, --sudo      gain permissions by sudo/doas"
  echo " -l, --list      list entries"
  echo " -c, --create    create entries"
  echo " -r, --remove    remove entries"
  echo
  echo " --force         continue & ignore errors"
  echo " --colour[=y/n]  toggle colour output"
  echo
  exit 0
}

sanity_check()
{
  # id -u -- print current user's UID (root = 0)
  if ! ([ `(id -u)` = '0' ] || [ "$USER" = "root" ]); then {
    die "insufficient permissions"
  } fi

  # /sys/firmware/efi -- kernel interface to EFI variables
  if ! ((efibootmgr >/dev/null) && [ -d "/sys/firmware/efi" ]); then {
    die "failed to read EFI variables, either your device is unsupported or you need to mount EFIvars"
  } fi
  
  if ! [ -f "$CONFIG_FILE" ]; then {
    warn "$CONFIG_FILE: configuration file is missing"
  } fi

  [ -d "$CONFIG_DIR" ] || mkdir -v $CONFIG_DIR
}

debug()
{
  return $?
}

set_debug()
{
  debug()
  {
    echo "${FCYAN}debug:${FNONE} $*"
  }
}

colour()
{
  FNONE=`(tput setaf 9)`

  case "$1" in
    ""|"y"|"yes") {
      FRED=`(tput setaf 1)`
      FCYAN=`(tput setaf 6)`
      FYELLOW=`(tput setaf 3)`
    } ;;
    "n"|"no") {
      unset "FRED" "FCYAN" "FYELLOW"
    } ;;
    *) {
      die "invalid value for 'colour' -- ${ARG##colour=}"
    } ;;
  esac
}

config()
{
  dir() { BOOT_DIR="$1" ;}
  label() { LABEL="$1" ;}
  target() { TARGET="$1" ;}
  cmdline() { UNICODE="$1" ;}
  ramdisk() { RAMDISK="\\${1///}" ;}

  debug "CONFIG_FILE = $CONFIG_FILE"

  # '.' -- POSIX compatible equivilent to bash's 'source'
  . "$CONFIG_FILE" || die "$CONFIG_FILE: failed to access configuration file"
}

gain_root()
{
  if ((grep -q "SUDO_UID=" <(env)) || [ ${#SUDO} -ge 1 ]); then {
    return 0
  } fi

  (execq "doas") && SUDO=doas
  (execq "sudo") && SUDO=sudo

  debug "SUDO = $SUDO"

  if ! [ ${#SUDO} -ge 1 ]; then {
    die "failed to locate sudo/doas"
  } fi

  $SUDO $0 "${RAWARGV[@]}"
  exit $?
}

entry_exists()
{
  grep -q " $LABEL" <(efibootmgr)
}

create_entry()
{
  sanity_check; config
  cd $CONFIG_DIR

  let x=1
  until ! (execq entry_$x); do {
    entry_$x; let x++

    # '//p*' -- remove 'p' & everything after 'p'
    # '//*p' -- remove 'p' & everything before 'p'
    local PART=`(grep " $BOOT_DIR " /proc/mounts | awk '{print $1}')`
    local DISK=`(sed 's/p.*//' <<<"$PART")`
    local PART_NUM=`(sed 's/.*p//' <<<"$PART")`

    debug "DISK = $DISK"
    debug "PART_NUM = $PART_NUM"
    debug "UNICODE = initrd=$RAMDISK $UNICODE"
    efibootmgr -c -d "$DISK" -p "$PART_NUM" -L "$LABEL" -l "$TARGET" -u "initrd=$RAMDISK $UNICODE" | grep "$LABEL" >>$LOG

    if (entry_exists); then {
      echo "$LABEL: added entry successfully"
    } else {
      die "$LABEL: failed to add entry"
    } fi
  } done
}

remove_entry()
{
  sanity_check; config

  let x=1
  until ! (execq entry_$x); do {
    entry_$x; let x++
    until ! (entry_exists); do {
      # -n 1p       -- print first line only
      # s/ .*//g    -- print first string only
      # s/[^0-9]//g -- print only numbers
      FNTARGET=`(grep "$LABEL" <(efibootmgr) | sed -n '1p' | sed 's/ .*//g; s/[^0-9]//g')`
      debug "FNTARGET = $FNTARGET"
      debug "LABEL = $LABEL"
      [ "${#FNTARGET}" -ge 1 ] && efibootmgr -B -b "$FNTARGET" | grep "$LABEL" >>$LOG
    } done
    if (entry_exists); then {
      die "$LABEL: failed to remove entry"
    } else {
      echo "$LABEL: removed entry"
    } fi
  } done
}

list_entry()
{
  sanity_check; config

  let x=1
  until ! (execq entry_$x); do {
    entry_$x; let x++
    (entry_exists) && echo "$(($x-1))* $LABEL"
  } done
}

version()
{
  MVER="0.1" SVER="3" BVER="2"
  VERSION="${MVER}.${SVER}-${BVER}"
  DATE="09:50 21/02/2024"
  TZ="GMT"
  echo "stubload version $VERSION ($DATE [$TZ])"
  echo "Licensed under the GPLv3 <https://www.gnu.org/licenses/>"
  debug "Build sha1sum: `sed 's/ .*//g' <(sha1sum <$0)`"
  exit 0
}

parse_arg()
{
  RAWARGV=( $* )
  ARGV=(`
    for ARG in $*; do {
      # 's/xyz//g' -- remove 'xyz' from input
      # 's/./& /g' -- add space between each character
      case "$ARG" in
        "--"*) sed 's/--//g' <<<"$ARG" ;;
        "-"*) sed 's/./& /g; s/-//g' <<<"$ARG" | xargs ;;
      esac
    } done
  `)

  argx()
  {
    if [ ${#ARGX[$1]} -ge 1 ]; then {
      die "conflicting arguments provided"
    } else {
      ARGX[$1]="$2"
    } fi
  }

  colour
  for ARG in ${ARGV[@]}; do {
    case "$ARG" in
      "force") FORCE_COMPLETE=true ;;
      "verbose"|"v") VERBOSE=true ;;
      "colour"*) colour `sed 's/colour//; s/=//' <<<"$ARG"` ;;
      "debug"|"d") set_debug ;;
      "sudo"|"s") argx 0 "gain_root" ;;
      "version"|"V") argx 1 "version" ;;
      "help"|"h") argx 1 "help" ;;
      "list"|"l") argx 1 "list_entry" ;;
      "remove"|"r") argx 1 "remove_entry" ;;
      "create"|"c") argx 2 "create_entry" ;;
      *) die "invalid argument -- $ARG"
    esac
  } done

  debug "ARGV = ${ARGV[@]}"

  if [ '1' -gt ${#ARGX[@]} ]; then {
    die "must provide at least one of '-h'|'-V'|'-l'|'-c'|'-r'"
  } fi
}

main()
{
  CONFIG_FILE="/etc/efistub/stubload.conf"
  CONFIG_DIR=`dirname $CONFIG_FILE`

  parse_arg "$*"
  (bool "$VERBOSE") && LOG="/dev/stdout" || LOG="/dev/null"

  for exec in ${ARGX[@]}; do {
    $exec
  } done

  exit 0
}
main "$*"
