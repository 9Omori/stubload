_stubload_completion()
{
    local cur
    _init_completion || return

    LONGARGV=(
        "--force"
        "--debug"
        "--colour="
        "--colour=y"
        "--colour=yes"
        "--colour=n"
        "--colour=no"
    )
    SHORTARGV=(
        "-v"
        "-n"
        "-s"
        "-V"
        "-h"
        "-l"
        "-r"
        "-c"
    )

    case "$cur" in
        "--force"|"--debug"|"--colour=y"|"--colour=yes"|"--colour=n"|"--colour=no")
            return
        ;;
        "-v"|"-n"|"-s"|"-V"|"-h"|"-l"|"-r"|"-c")
            return
        ;;
        "--f"*)
            RES="${LONGARGV[0]}"
        ;;
        "--d"*)
            RES="${LONGARGV[1]}"
        ;;
        "--colour="*)
            RES=$(cut -d ' ' -f "4-7" <<<"${LONGARGV[@]}")
        ;;
        "--c"*)
            RES=$(cut -d ' ' -f "3-7" <<<"${LONGARGV[@]}")
        ;;
        "--"|"--"*)
            RES="${LONGARGV[@]}"
        ;;
        "-")
            RES="${SHORTARGV[@]} ${LONGARGV[@]}"
        ;;
        "-"*)
            RES="$prev"
        ;;
        *)
            RES="${SHORTARGV[@]} ${LONGARGV[@]}"
        ;;
    esac

    test "$RES" && COMPREPLY=( $(compgen -W "$RES" -- $cur) )

    return
}
complete -F _stubload_completion stubload
