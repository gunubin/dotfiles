#!/bin/sh
# pane-marker.sh - アクティブな pane と popup の位置を、ステータスバー右端の11マスの色にして出す
#   Ghostty のシェーダー（~/.config/ghostty/shaders/pane-dim.glsl）がこの色を読み、
#   アクティブな pane や popup の外側に効果をかける。マスはシェーダーが周りの色で塗りつぶして隠す
#
# Usage: pane-marker.sh <セル幅px> <セル高さpx> <列数> <行数> <paneの左> <paneの上> <paneの幅> <paneの高さ> \
#                       <popupの幅> <popupの高さ> <タブの色>
#   paneの左・上は画面の左上を0としたマス目（ステータスバーの行も含める）
#   popupの幅・高さは枠を含めたマス数。popup が開いていなければ空か 0。位置は画面の中央なので渡さない
#   空のときは、fzf の --tmux などが開いた popup を探す（tmux display-popup のプロセスの -w・-h を読む）
#   タブの色（#rrggbb）は popup の縁の光に使う。値ではなく色そのものとして1マスに塗る
#
# 色は Ghostty の中で Display P3 に変換されて 8 ビットに丸められるため、シェーダーが読むと
# 各チャンネルが 3 前後ずれる。そこで 1 チャンネルには 16 段階（4 ビット）だけを、
# 段階の真ん中（n*16+8）の値で入れる。1マスに 12 ビット（0〜4095）の値を1つ入れる
#   1マス目: セル幅 * 64 + セル高さ（どちらも 63 まで）
#   2マス目: 列数 / 3マス目: 行数 / 4マス目: paneの左 / 5マス目: paneの上
#   6マス目: paneの幅 / 7マス目: paneの高さ / 8マス目: 目印（2730）
#   9マス目: popupの幅 / 10マス目: popupの高さ / 11マス目: タブの色
# 右端から 1マス目・2マス目…の順に並ぶよう、11→1 の順で出す

[ $# -eq 11 ] || exit 0
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
