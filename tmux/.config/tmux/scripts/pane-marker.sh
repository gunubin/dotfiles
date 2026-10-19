#!/bin/sh
# pane-marker.sh - アクティブな pane と popup の位置などを、ステータスバー右端の21マスの色にして出す
#   Ghostty のシェーダー（~/.config/ghostty/shaders/pane-dim.glsl）がこの色を読み、
#   アクティブな pane や popup の外側に効果をかける。マスはシェーダーが周りの色で塗りつぶして隠す
#
# Usage: pane-marker.sh <セル幅px> <セル高さpx> <列数> <行数> <paneの左> <paneの上> <paneの幅> <paneの高さ> \
#                       <popupの幅> <popupの高さ> <タブの色> <prefix> <コピーモード> <ズーム> <コマンド失敗> \
#                       <git push の時刻> <window の ID>
#   paneの左・上は画面の左上を0としたマス目（ステータスバーの行も含める）
#   popupの幅・高さは枠を含めたマス数。popup が開いていなければ空か 0。位置は画面の中央なので渡さない
#   空のときは、fzf の --tmux などが開いた popup を探す（tmux display-popup のプロセスの -w・-h を読む）
#   タブの色（#rrggbb）は popup の縁の光に使う。値ではなく色そのものとして1マスに塗る
#   prefix・コピーモード・ズームは 0 か 1（client_prefix・pane_in_mode・window_zoomed_flag）
#   コマンド失敗は、アクティブな pane の @cmd_failed（fish の conf.d/tmux_cmd_failed.fish が付ける）。1 か空
#   Claude の状態（処理中・入力待ち・終わった直後）は、~/.claude/pane-state.json から pane ごとに調べ、
#   window の ID の window で見えている pane のうち、Claude が動いている pane（最大4つ）の位置を載せる
#   git push の時刻は、成功したときに fish（conf.d/tmux_cmd_failed.fish）が tmux の @git_push_at に入れる UNIX 時刻
#
# 色は Ghostty の中で Display P3 に変換されて 8 ビットに丸められるため、シェーダーが読むと
# 各チャンネルが 3 前後ずれる。そこで 1 チャンネルには 16 段階（4 ビット）だけを、
# 段階の真ん中（n*16+8）の値で入れる。1マスに 12 ビット（0〜4095）の値を1つ入れる
#   1マス目: セル幅 * 64 + セル高さ（どちらも 63 まで）
#   2マス目: 列数 / 3マス目: 行数 / 4マス目: paneの左 / 5マス目: paneの上
#   6マス目: paneの幅 / 7マス目: paneの高さ / 8マス目: 目印（2730）
#   9マス目: popupの幅 / 10マス目: popupの高さ / 11マス目: タブの色
#   12マス目: prefix + コピーモード * 2 + ズーム * 4 + コマンド失敗 * 8
#   13マス目: git push が成功して5秒以内 * 16
#   14〜21マス目: Claude が動いている pane ごとに2マス。1マス目は paneの左、2マス目は paneの上 + 状態 * 512
#                 （状態は 0: なし / 1: 処理中 / 2: 入力待ち / 3: 終わって3秒以内 / 4: 処理を始めて60秒以上 / 5: アクティブな pane で待機中）
# 右端から 1マス目・2マス目…の順に並ぶよう、21→1 の順で出す

[ $# -eq 17 ] || exit 0
flags=$(( ${12:-0} == 1 ? 1 : 0 ))
[ "${13:-0}" = 1 ] && flags=$((flags + 2))
[ "${14:-0}" = 1 ] && flags=$((flags + 4))
[ "${15}" = 1 ] && flags=$((flags + 8))
push_at="${16}"
now=$(date +%s)

# Claude が動いている pane: 「paneの左 paneの上 状態」を1行ずつ（最大4つ）。
# ズーム中は、ズームした pane だけが見えている
claude_panes=$(tmux list-panes -t "${17}" -F '#{pane_id} #{pane_left} #{e|+:#{pane_top},1} #{pane_active} #{window_zoomed_flag}' 2>/dev/null |
    jq -R -r --slurpfile state "$HOME/.claude/pane-state.json" --argjson now "$now" '
        split(" ") as [$id, $left, $top, $active, $zoomed]
        | select($zoomed == "0" or $active == "1")
        | ($state[0][$id] // {}) as $s
        | (if $s.status == "working" and $now - ($s.since // $now) >= 60 then 4
           elif $s.status == "working" then 1
           elif $s.status == "waiting" then 2
           elif $s.status == "done" and $now - ($s.ts // 0) <= 3 then 3
           elif $s.status != null and $active == "1" then 5
           else 0 end) as $code
        | select($code > 0)
        | "\($left) \($top) \($code)"' 2>/dev/null | head -n 4)
claude=0
case "$push_at" in '' | *[!0-9]*) ;; *) [ $((now - push_at)) -le 5 ] && claude=$((claude + 16)) ;; esac

color="${11}"
case "$color" in '#'[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;; *) exit 0 ;; esac
popup_w="${9:-0}"
popup_h="${10:-0}"

# tmux display-popup の -w・-h（"70%" か "120" の形）を、画面の列数・行数をもとにマス数にする
popup_size() {
    case "$1" in
        *%) echo $(($2 * ${1%\%} / 100)) ;;
        '' | *[!0-9]*) echo 0 ;;
        *) echo "$1" ;;
    esac
}

# fzf の --tmux などは tmux のセッションを作らず、display-popup のプロセスだけが開いている間残る
if [ "$popup_w" = 0 ]; then
    spec=$(ps -axo comm=,args= | awk '$1 ~ /(^|\/)tmux$/ && / display-popup / {
        w = ""; h = ""
        for (i = 2; i <= NF; i++) {
            if ($i ~ /^-w./) w = substr($i, 3); else if ($i == "-w") w = $(i + 1)
            if ($i ~ /^-h./) h = substr($i, 3); else if ($i == "-h") h = $(i + 1)
        }
        if (w != "" && h != "") { print w, h; exit }
    }')
    if [ -n "$spec" ]; then
        popup_w=$(popup_size "${spec% *}" "$3")
        popup_h=$(popup_size "${spec#* }" "$4")
    fi
fi
set -- "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$popup_w" "$popup_h"
for n in "$@"; do
    case "$n" in '' | *[!0-9]*) exit 0 ;; esac
    [ "$n" -le 4095 ] || exit 0
done
[ "$1" -le 63 ] && [ "$2" -le 63 ] || exit 0

cell() {
    printf '#[bg=#%02x%02x%02x] ' \
        $((($1 >> 8 & 15) * 16 + 8)) $((($1 >> 4 & 15) * 16 + 8)) $((($1 & 15) * 16 + 8))
}

# Claude の pane は、右端から遠い順（4つ目→1つ目）に出す。空きは 0 で埋める
slots=$(printf '%s\n0 0 0\n0 0 0\n0 0 0\n0 0 0\n' "$claude_panes" | sed '/^$/d' | head -n 4 | tail -r)
while read -r pane_left pane_top code; do
    case "$pane_left$pane_top$code" in '' | *[!0-9]*) exit 0 ;; esac
    [ "$pane_left" -le 4095 ] && [ "$pane_top" -le 511 ] || exit 0
    cell $((pane_top + code * 512))
    cell "$pane_left"
done <<EOF2
$slots
EOF2
cell "$claude"
cell "$flags"
printf '#[bg=%s] ' "$color"
cell "${10}"
cell "$9"
cell 2730
cell "$8"
cell "$7"
cell "$6"
cell "$5"
cell "$4"
cell "$3"
cell $(($1 * 64 + $2))
