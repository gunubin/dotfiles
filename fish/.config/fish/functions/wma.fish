function wma --description 'workmux add with auto date-based name'
    set -l project (basename (git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null)
    if test -z "$project"
        set project (basename (pwd))
    end

    set -l today (date +%m-%d)
    set -l base "$project-$today"

    # 既存ブランチから同日のものを検索
    set -l has_base false
    set -l max_code 0

    for branch in (git branch --all --list "*$base*" 2>/dev/null | string trim | string replace -r '.*/' '')
        if test "$branch" = "$base"
            set has_base true
        else
            set -l s (string replace "$base-" '' $branch | string sub -l 1)
            set -l code (printf '%d' "'$s" 2>/dev/null)
            if test $code -gt $max_code
                set max_code $code
            end
        end
    end

    # 命名: 初回=サフィックスなし, 2つ目=-b, 3つ目=-c, ...
    set -l name
    if not $has_base
        set name $base
    else if test $max_code -eq 0
        set name "$base-b"
    else
        set name "$base-"(printf "\\x$(printf '%02x' (math $max_code + 1))")
    end

    echo "Creating: $name"
    workmux add $argv "$name"
end
