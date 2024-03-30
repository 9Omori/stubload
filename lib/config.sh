#!/usr/bin/bash

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
  ramdisk="$1"
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
