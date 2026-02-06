function __fzf_complete_token
    set -l token (commandline -ct)
    set -l cmd (commandline -opc)
    set -l completions (complete -C"$cmd $token")

    # 候補がなければ何もしない
    if test -z "$completions"
        return
    end

    set -l count (count $completions)

    # 候補が1つなら直接補完
    if test $count -eq 1
        commandline -rt (echo $completions[1] | awk '{print $1}')
        commandline -f repaint
        return
    end

    # 候補が2-4つなら標準のfish補完
    if test $count -lt 5
        commandline -f complete
        return
    end

    # 候補が5つ以上ならfzfで選択（説明付き）
    set -l selected (printf '%s\n' $completions | fzf --height=40% --no-preview)
    if test -n "$selected"
        commandline -rt (echo $selected | awk '{print $1}')
    end
    commandline -f repaint
end