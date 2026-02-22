function wmh --description 'Retroactively convert current window to workmux-managed'
    # git リポジトリでなければ中断
    git rev-parse --git-dir >/dev/null 2>&1
    or begin
        echo "Error: not a git repository"
        return 1
    end

    # tmux 外なら中断
    test -n "$TMUX"
    or begin
        echo "Error: not inside tmux"
        return 1
    end

    # 現在のウィンドウIDを保存（workmux add 後に削除するため）
    set -l old_window (tmux display-message -p '#{window_id}')

    # 日付ベースのブランチ名を生成（wma と同じロジック）
    set -l today (date +%Y-%m-%d)
    set -l prefix "feature-$today"

    set -l max 0
    for branch in (git branch --all --list "*$prefix-*" 2>/dev/null | string trim | string replace -r '.*/' '')
        set -l s (string replace "$prefix-" '' $branch | string sub -l 1)
        set -l code (printf '%d' "'$s" 2>/dev/null)
        if test $code -gt $max
            set max $code
        end
    end

    set -l suffix
    if test $max -eq 0
        set suffix a
    else
        set suffix (printf "\\x$(printf '%02x' (math $max + 1))")
    end

    set -l branch "$prefix-$suffix"
    echo "Creating workmux: $branch"

    # workmux window を作成（未コミットの変更も移行）
    workmux add --with-changes $argv "$branch"
    or return 1

    # 元のウィンドウを閉じる（workmux add で新ウィンドウに切り替え済み）
    tmux kill-window -t "$old_window" 2>/dev/null
end
