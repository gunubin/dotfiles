function __fzf_complete_token
    set -l token (commandline -ct)
    set -l cmd (commandline -opc)

    set -l completions (complete -C"$cmd $token" | awk '{print $1}' | fzf --height=40%)

    if test -n "$completions"
        commandline -rt "$completions"
    end

    commandline -f repaint
end