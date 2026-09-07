#!/bin/bash
# session-title-from-pr.sh - Claude Code SessionStart hook
# 作業中ブランチに対応する GitHub PR のタイトルをセッション名のデフォルトにする。
# - source が startup / resume のときのみ適用（clear / compact では sessionTitle は無視される）
# - ユーザーが --name / /rename で既に命名済みなら何もしない（手動命名を尊重）
# - PR が無い・gh が無い・git リポジトリ外なら何もしない（既定の挙動を維持）

input=$(cat)

# sessionTitle は startup / resume でのみ有効。それ以外は gh を叩かず即終了
source=$(echo "$input" | jq -r '.source // ""' 2>/dev/null)
case "$source" in
  startup | resume) ;;
  *) exit 0 ;;
esac

# 既にタイトルが設定済みなら上書きしない
existing=$(echo "$input" | jq -r '.session_title // ""' 2>/dev/null)
[ -n "$existing" ] && exit 0

cwd=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null)
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null || exit 0

# gh CLI が無ければ何もしない
command -v gh >/dev/null 2>&1 || exit 0

# git リポジトリ外なら何もしない
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# 現ブランチに対応する PR タイトルを取得（無ければ空）
pr_title=$(gh pr view --json title -q '.title' 2>/dev/null)
[ -z "$pr_title" ] && exit 0

# 端末幅を決定（tmux pane 幅 → tmux client 幅 → COLUMNS → tput → 80 の順）
width=""
if [ -n "$TMUX_PANE" ]; then
  width=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_width}' 2>/dev/null)
fi
[ -z "$width" ] && [ -n "$TMUX" ] && width=$(tmux display-message -p '#{client_width}' 2>/dev/null)
[ -z "$width" ] && [ -n "$COLUMNS" ] && [ "$COLUMNS" -gt 0 ] 2>/dev/null && width="$COLUMNS"
[ -z "$width" ] && width=$(tput cols 2>/dev/null)
[[ "$width" =~ ^[0-9]+$ ]] && [ "$width" -gt 0 ] || width=80

# 表示に使える幅（左インデント＋右余白ぶんを差し引く）
max=$((width - 4))
[ "$max" -lt 12 ] && max=12

# 表示幅（全角=2/半角=1）で先頭から切り詰め、超過時は末尾を … にする
pr_title=$(printf '%s' "$pr_title" | perl -CSDA -e '
  my $max = shift @ARGV;
  local $/; my $s = <STDIN>;
  $s =~ s/\s+\z//;
  my @c = split //, $s;
  my $total = 0; $total += (/\p{ASCII}/ ? 1 : 2) for @c;
  if ($total <= $max) { print $s; exit; }
  my $limit = $max - 2;   # … の表示幅ぶんを予約
  my ($w, $out) = (0, "");
  for my $ch (@c) {
    my $cw = ($ch =~ /\p{ASCII}/) ? 1 : 2;
    last if $w + $cw > $limit;
    $w += $cw; $out .= $ch;
  }
  print $out . "\x{2026}";
' "$max")

# jq で安全に JSON を組み立てて出力
jq -nc --arg t "$pr_title" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", sessionTitle: $t}}'
