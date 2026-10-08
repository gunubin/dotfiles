function cc --description "Claude Code with modes"
    set -l env_vars
    # 会社の managed settings が defaultMode=default を強制するため、起動フラグで auto にする
    set -l claude_args --permission-mode auto
    set -l awaiting_pr false
    set -l awaiting_task false
    set -l task_id ""

    for arg in $argv
        if $awaiting_pr
            set -a claude_args --from-pr $arg
            set awaiting_pr false
            continue
        end
        if $awaiting_task
            set task_id $arg
            set awaiting_task false
            continue
        end

        switch $arg
            # --- 環境変数モード ---
            case team
                set -a env_vars CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
            case fast
                set -a env_vars DISABLE_INTERLEAVED_THINKING=1
            case long
                set -a env_vars BASH_MAX_TIMEOUT_MS=1800000
            # --- モデル指定 ---
            case opus
                set -a claude_args --model opus
            case sonnet
                set -a claude_args --model sonnet
            case haiku
                set -a claude_args --model haiku
            # --- サブコマンド ---
            case c
                set -a claude_args --continue
            case pr
                set awaiting_pr true
            case task
                set awaiting_task true
            case '*'
                set -a claude_args $arg
        end
    end

    # CLAUDE_CODE_TASK_LIST_ID: 手動指定 or gitリポジトリ名から自動生成
    if test -z "$task_id"
        set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
        if test -n "$repo_root"
            set task_id (basename $repo_root)
        end
    end
    if test -n "$task_id"
        set -a env_vars CLAUDE_CODE_TASK_LIST_ID=$task_id
    end

    # tmux ウィンドウ名を保存（フォールバック用: SessionEnd が発火しなかった場合の復元）
    set -l orig_window ""
    if test -n "$TMUX"
        set orig_window (tmux display-message -p -t $TMUX_PANE '#W')
    end

    # env 経由だと外部コマンドとして起動され fish の claude 関数（--settings 付与）を通らないため、
    # 関数スコープの export で渡す
    for kv in $env_vars
        set -l pair (string split -m1 = -- $kv)
        set -fx $pair[1] $pair[2]
    end
    claude $claude_args

    # tmux ウィンドウ名を復元（実行中に prefix+R で手動リネームされていたら、その名前を優先する）
    if test -n "$TMUX" -a -n "$orig_window"
        set -l manual (tmux display-message -p -t $TMUX_PANE '#{@manual_name}')
        if test "$manual" != 1
            tmux rename-window -t $TMUX_PANE "$orig_window" 2>/dev/null
        end
    end
end
