#!/usr/bin/env bash

if [ ! -f "$config" ]; then
  config=/etc/efistub/stubload.conf
fi

# get just 'stubload.conf' from '/etc/efistub/stubload.conf'
config_base="${config##*/}"
config_dir="${config/$config_base}"

# capture configuration file in a variable
CONFIN=$(<"$config")

target()
{
  case "$1" in 
    "-p"|"--preset")
      source /lib/stubload/presets/"$2" &>>$log
      ;;
    *)
      target="$1"
      ;;
  esac
}

ramdisk()
{
  ramdisks=( $* )
}

dir()
{
  boot_dir="$1"
}

label()
{
  label="$1"
}

cmdline()
{
  unicode="$1"
}

disabled()
{
  disabled=1
}

source "$config"
