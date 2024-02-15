_stubload_completion()
{
    local cur cword
    _init_completion || return

    LONGARGV=(
        "--help"
        "--verbose"
        "--debug"
        "--version"
        "--sudo"
        "--list"
        "--create"
        "--remove"
        "--force"
        "--debug"
        "--colour=y"
        "--colour=n"
    )
    SHORTARGV=(
        "-h"
        "-v"
        "-d"
        "-V"
        "-s"
        "-l"
        "-c"
        "-r"
    )

    case "$cur" in
        "--"*)
            RES="${LONGARGV[@]}"
        ;;
        *"h"*|*"V"*|*"l"*|*"r"*)
            RES="$cur"
        ;;
        "-"*)
            for ARG in $(sed "s/-//g; s/./& /g" <<<"${cur}"); do {
                SHORTARGV=( $(sed "s/-$ARG//g" <<<"${SHORTARGV[@]}") )
            } done
            SHORTARGV=( $(sed "s/-/$cur/g" <<<"${SHORTARGV[@]}") )
            RES="${SHORTARGV[@]}"
        ;;
        *)
            RES="${SHORTARGV[@]}"
        ;;
    esac

    if (test "$RES"); then {
        COMPREPLY=( $(compgen -W "$RES" -- $cur) )
    } fi

    return
}
complete -F _stubload_completion stubload
