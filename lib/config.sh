#!/usr/bin/env bash

if [ ! -f "$config" ]; then
  config=/etc/efistub/stubload.conf
fi

config_dir=$(dirname "$config")
config_base=$(basename "$config")

confin()
{
  # capture config file content in a variable
  CONFIN=$(<"$config")
}

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

source "$config"
