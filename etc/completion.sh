_stubload_completion()
{
  local cur
  _init_completion || return

  LONGARGV=(
    "--help"
    "--verbose"
    "--version"
    "--number"
    "--list"
    "--create"
    "--remove"
    "--force"
    "--config="
  )
  SHORTARGV=(
    "-h"
    "-v"
    "-V"
    "-n"
    "-l"
    "-c"
    "-r"
  )

  case "$cur" in
    "-n"|"--number")
      RES="1 2 3 4 5 6 7 8 9"
    ;;
    "--config=")
      RES=`(ls)`
    ;;
    "--"*)
      RES="${LONGARGV[@]}"
    ;;
    "-")
      RES="${SHORTARGV[@]}"
    ;;
    "-"*)
      RES="$cur"
    ;;
    *)
      RES="${SHORTARGV[@]}"
    ;;
  esac

  if [ "${#RES}" -gt 1 ]; then
    COMPREPLY=( `(compgen -W "$RES" -- $cur)` )
  fi

  return
}
complete -F _stubload_completion stubload
