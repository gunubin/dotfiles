function wma --description 'workmux add with auto date-based name'
    set -l today (date +%Y-%m-%d)
    set -l prefix "feature-$today"

    # 既存ブランチから今日使われたサフィックスの最大文字コードを取得
    set -l max 0
    for branch in (git branch --all --list "*$prefix-*" 2>/dev/null | string trim | string replace -r '.*/' '')
        set -l s (string replace "$prefix-" '' $branch | string sub -l 1)
        set -l code (printf '%d' "'$s" 2>/dev/null)
        if test $code -gt $max
            set max $code
        end
    end

    # 次のサフィックスを決定 (a, b, c, ...)
    set -l suffix
    if test $max -eq 0
        set suffix a
    else
        set suffix (printf "\\x$(printf '%02x' (math $max + 1))")
    end

    echo "Creating: $prefix-$suffix"
    workmux add $argv "$prefix-$suffix"
end
