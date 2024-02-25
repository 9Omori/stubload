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

bool()
{
  [ "$1" == "true" ]
}

die()
{
  # >&2 -- redirect stdout to stderr
  echo "${fRed}error:${fNone} $*" >&2
  if [ "${#force}" -gt 1 ]; then
    return 1
  else
    exit 1
  fi
}

warn()
{
  echo "${fYellow}warning:${fNone} $*" >&2
  return 1
}

debug()
{
  :
}

set_debug()
{
  debug()
  {
    echo "${fCyan}debug:${fNone} $*" >&2
  }
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
  echo " -V, --version   print version"
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
  if ! ([ `(id -u)` = '0' ] || [ "$USER" == "root" ]); then
    die "insufficient permissions"
  fi

  # /sys/firmware/efi -- kernel interface to EFI variables
  if ! ((efibootmgr >/dev/null) && [ -d "/sys/firmware/efi" ]); then
    die "failed to read EFI variables, either your device is unsupported or you need to mount EFIvars"
  fi
  
  if ! [ -f "$configFile" ]; then
    warn "$configFile: configuration file is missing"
  fi

  [ -d "$configDir" ] || mkdir -v $configDir
}

colour()
{
  case "$1" in
    ""|"y"|"yes") {
      fNone=`(echo -e "\e[0m")`
      fRed=`(echo -e "\e[1;31m")`
      fCyan=`(echo -e "\e[1;36m")`
      fYellow=`(echo -e "\e[1;33m")`
    } ;;
    "n"|"no") {
      unset fRed fCyan fYellow
    } ;;
    *) {
      die "'colour' must be yes/no"
    } ;;
  esac
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
  sanity_check; config
  run_scripts
  cd $configDir

  let x=1
  until ! (execq entry_$x); do
    entry_$x; let x++

    # '//p*' -- remove 'p' & everything after 'p'
    # '//*p' -- remove 'p' & everything before 'p'
    local part=`(grep " $bootDir " /proc/mounts | awk '{print $1}')`
    local disk=`(sed 's/p.*//' <<<"$part")`
    local partNum=`(sed 's/.*p//' <<<"$part")`

    debug "disk = $disk"
    debug "partNum = $partNum"
    debug "unicode = $unicode"

    efibootmgr -c -d "$disk" -p "$partNum" -L "$label" -l "$target" -u "initrd=$ramdisk $unicode" | grep "$label" >>$log

    if (entry_exists); then
      echo "$label: added entry successfully"
    else
      die "$label: failed to add entry"
    fi
  done
}

remove_entry()
{
  sanity_check; config

  let x=1
  until ! (execq entry_$x); do
    entry_$x; let x++
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
  done
}

list_entry()
{
  sanity_check; config

  let x=1
  until ! (execq entry_$x); do
    entry_$x; let x++
    (entry_exists) && echo "$(($x-1))* $label"
  done
}

version()
{
  mVer="0.1" sVer="3" bVer="3"
  version="${mVer}.${sVer}-${bVer}"
  date="23:52 25/02/2024"
  tz="GMT"
  echo "stubload version $version ($date [$tz])"
  echo "Licensed under the GPLv3 <https://www.gnu.org/licenses/>"
  debug "Build sha1sum: `sed 's/ .*//g' <(sha1sum <$0)`"
  exit 0
}

parse_arg()
{
  RAWARGV=( $* )
  ARGV=(`
    for ARG in $*; do
      # 's/xyz//g' -- remove 'xyz' from input
      # 's/./& /g' -- add space between each character
      case "$ARG" in
        "--"*) sed 's/--//g' <<<"$ARG" ;;
        "-"*) sed 's/./& /g; s/-//g' <<<"$ARG" | xargs ;;
      esac
    done
  `)

  argx()
  {
    if [ ${#ARGX[$1]} -ge 1 ]; then
      die "conflicting arguments provided"
    else
      ARGX[$1]="$2"
    fi
  }

  colour
  for ARG in ${ARGV[@]}; do
    case "$ARG" in
      "force") force=true ;;
      "verbose"|"v") set_debug; verbose=true ;;
      "colour"*) colour `(sed 's/colour//; s/=//' <<<"$ARG")` ;;
      "version"|"V") argx 1 "version" ;;
      "help"|"h") argx 1 "help" ;;
      "list"|"l") argx 1 "list_entry" ;;
      "remove"|"r") argx 1 "remove_entry" ;;
      "create"|"c") argx 2 "create_entry" ;;
      *) die "invalid argument -- $ARG"
    esac
  done

  debug "ARGV = ${ARGV[@]}"

  if [ "${#ARGX[@]}" -lt '1' ]; then
    die "insufficient arguments provided"
  fi
}

stubload()
{
  configFile="/etc/efistub/stubload.conf"
  configDir=`(dirname $configFile)`

  parse_arg "$*"
  (bool "$verbose") && log="/dev/stdout" || log="/dev/null"

  for exec in ${ARGX[@]}; do
    $exec
  done

  exit 0
}
stubload "$*"
