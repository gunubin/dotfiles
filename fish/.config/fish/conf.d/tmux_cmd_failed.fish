# tmux_cmd_failed.fish - コマンドが失敗したら tmux の pane に印（@cmd_failed）を付ける
#   Ghostty の pane-dim.glsl が、印の付いたアクティブな pane の縁を赤く光らせる
#   （~/.config/tmux/scripts/pane-marker.sh が印をステータスバーの目印に載せる）
#   次のコマンドを打つと消す

# 非インタラクティブシェルでは実行しない（Claude Code等のサブシェル対策）
status is-interactive; or return

function __tmux_cmd_failed_clear --on-event fish_preexec
    test -n "$TMUX"; or return
    tmux set-option -p -u -t $TMUX_PANE @cmd_failed 2>/dev/null
end

function __tmux_cmd_failed_mark --on-event fish_postexec
    set -l code $status
    test -n "$TMUX"; or return
    if test $code -ne 0
        tmux set-option -p -t $TMUX_PANE @cmd_failed 1 2>/dev/null
        # ステータスバーの描き直し（最大1秒）を待たずに反映する
        tmux refresh-client -S 2>/dev/null
    end
end
