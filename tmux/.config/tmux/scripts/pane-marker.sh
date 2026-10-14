#!/bin/sh
# pane-marker.sh - アクティブな pane の位置を、ステータスバー右端の3マスの色にして出す
#   Ghostty のシェーダー（~/.config/ghostty/shaders/pane-dim.glsl）がこの色を読み、
#   アクティブな pane の外側に薄い色を重ねる。マスはシェーダーが周りの色で塗りつぶして隠す
#
# Usage: pane-marker.sh <セル幅px> <セル高さpx> <列数> <行数> <paneの左> <paneの上> <paneの幅> <paneの高さ>
#   paneの左・上は画面の左上を0としたマス目（ステータスバーの行も含める）
#
# 各マスの色 #RRGGBB に3つずつ数値を入れる（どれも 0〜255）
#   1マス目: セル幅, セル高さ, 列数
#   2マス目: 行数, paneの左, paneの上
#   3マス目: paneの幅, paneの高さ, 目印（165）
# 右端から 1マス目・2マス目・3マス目の順に並ぶよう、3→2→1 の順で出す

[ $# -eq 8 ] || exit 0
for n in "$@"; do
    case "$n" in '' | *[!0-9]*) exit 0 ;; esac
    [ "$n" -le 255 ] || exit 0
done

printf '#[bg=#%02x%02x%02x] #[bg=#%02x%02x%02x] #[bg=#%02x%02x%02x] ' \
    "$7" "$8" 165 \
    "$4" "$5" "$6" \
    "$1" "$2" "$3"
