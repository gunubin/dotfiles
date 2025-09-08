function _fzf_delete_history --argument-names cmd
    # Remove the timestamp prefix and delete the exact command from history
    set -l clean_cmd (echo $cmd | string replace --regex '^.*? │ ' '')
    if test -n "$clean_cmd"
        history delete --exact --case-sensitive -- "$clean_cmd"
    end
end