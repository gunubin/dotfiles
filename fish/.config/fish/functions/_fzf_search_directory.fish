function _fzf_search_directory --description "Search the current directory. Replace the current token with the selected file paths."
    # Directly use fd binary to avoid output buffering delay caused by a fd alias, if any.
    # Debian-based distros install fd as fdfind and the fd package is something else, so
    # check for fdfind first. Fall back to "fd" for a clear error message.
    set -f fd_cmd (command -v fdfind || command -v fd  || echo "fd")
    set -f --append fd_cmd --color=always $fzf_fd_opts

    set -f fzf_arguments --multi --ansi --expect=ctrl-a --header="enter: relative / ctrl-a: absolute" $fzf_directory_opts
    set -f token (commandline --current-token)
    # expand any variables or leading tilde (~) in the token
    set -f expanded_token (eval echo -- $token)
    # unescape token because it's already quoted so backslashes will mess up the path
    set -f unescaped_exp_token (string unescape -- $expanded_token)

    # If the current token is a directory and has a trailing slash,
    # then use it as fd's base directory.
    if string match --quiet -- "*/" $unescaped_exp_token && test -d "$unescaped_exp_token"
        set --append fd_cmd --base-directory=$unescaped_exp_token
        # use the directory name as fzf's prompt to indicate the search is limited to that directory
        set --prepend fzf_arguments --prompt="Directory $unescaped_exp_token> " --preview="_fzf_preview_file $expanded_token{}"
        set -f raw_output ($fd_cmd 2>/dev/null | _fzf_wrapper $fzf_arguments)
    else
        set --prepend fzf_arguments --prompt="Directory> " --query="$unescaped_exp_token" --preview='_fzf_preview_file {}'
        set -f raw_output ($fd_cmd 2>/dev/null | _fzf_wrapper $fzf_arguments)
    end

    if test $status -eq 0
        set -f key $raw_output[1]
        set -f file_paths_selected $raw_output[2..]

        if test "$key" = ctrl-a
            set -f abs_paths
            for p in $file_paths_selected
                set --append abs_paths (realpath -- $p)
            end
            set file_paths_selected $abs_paths
        else
            if string match --quiet -- "*/" $unescaped_exp_token && test -d "$unescaped_exp_token"
                set -f prefixed
                for p in $file_paths_selected
                    set --append prefixed "$unescaped_exp_token$p"
                end
                set file_paths_selected $prefixed
            end
        end

        commandline --current-token --replace -- (string escape -- $file_paths_selected | string join ' ')
    end

    commandline --function repaint
end
