_stubload_completion()
{
  local cur prev
  _init_completion || return

  LONGARGV=(
    "--help"
    "--verbose"
    "--version"
    "--list"
    "--create"
    "--remove"
    "--force"
    "--config "
  )
  SHORTARGV=(
    "-h"
    "-v"
    "-V"
    "-l"
    "-c"
    "-r"
  )

  case "$prev" in
    "--config")
      if ! [[ "$cur" == *"/" ]]; then
        RES="$cur/"
      else
        RES="$cur"
      fi
      COMPREPLY=( $(compgen -f -- $RES) )
      return
      ;;
  esac

  if ! ((${#RES})); then
    case "$cur" in
      "-n"|"--number")
        RES="1 2 3 4 5 6 7 8 9"
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
  fi

  if ((${#RES})); then
    COMPREPLY=( $(compgen -W "$RES" -- $cur) )
  fi

  unset LONGARGV SHORTARGV RES
}
complete -F _stubload_completion stubload
