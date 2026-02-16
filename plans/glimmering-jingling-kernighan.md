# 新規ウィンドウ起動時にプロジェクト名を表示

## Context
tmux で新しいウィンドウを開くと `automatic-rename` により "fish" が表示される。`--on-variable PWD` は PWD が**変化**した時のみ発火するため、シェル起動直後は反映されない。

## 変更ファイル

### `fish/.config/fish/conf.d/tmux_project_name.fish`
- 既存の `--on-variable PWD` フックの**前**に、シェル起動時1回だけ実行するブロックを追加
- tmux 内かつ Claude pane でなければ `tmux rename-window` を呼ぶ（4行追加）

```fish
if test -n "$TMUX"
    set -l _pane_id (tmux display-message -p '#{pane_id}')
    if not test -f "/tmp/claude-tmux/pane-$_pane_id"
        tmux rename-window ($HOME/.config/claude/scripts/tmux-project-name.sh $PWD)
    end
end
```

他のファイルの変更なし。

## 検証
1. tmux で新しいウィンドウ作成 → "fish" ではなくプロジェクト名が表示される
2. `cd` で別プロジェクトに移動 → 名前が更新される
3. Claude pane では従来通りアイコン付き表示
