function cc --description "Claude Code with modes"
    set -l env_vars
    set -l claude_args --dangerously-skip-permissions
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
            case think
                set -a env_vars MAX_THINKING_TOKENS=63999
            case team
                set -a env_vars CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
            case fast
                set -a env_vars DISABLE_INTERLEAVED_THINKING=1
            case long
                set -a env_vars BASH_MAX_TIMEOUT_MS=1800000
            # --- モデル指定 ---
            case opus46
                set -a claude_args --model claude-opus-4-6
            case opus
                set -a claude_args --model opus
            case sonnet
                set -a claude_args --model sonnet
            case haiku
                set -a claude_args --model haiku
            # --- サブコマンド ---
            case c
                set -a claude_args -c
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
        set task_id (basename (git rev-parse --show-toplevel 2>/dev/null))
    end
    if test -n "$task_id"
        set -a env_vars CLAUDE_CODE_TASK_LIST_ID=$task_id
    end

    if test (count $env_vars) -gt 0
        env $env_vars claude $claude_args
    else
        claude $claude_args
    end
end
