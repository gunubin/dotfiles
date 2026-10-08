---
name: prrange
description: |
  PR のコミット範囲 `origin/<base>..origin/<head>` をクリップボードにコピーする。
  WebStorm の Git ログのブランチフィルタに貼ると、その PR のコミットだけに絞れる。
  「PR の差分だけログで見たい」「prrange」「PR の範囲をコピーして」時に使用。
allowed-tools: Bash(fish -c *)
argument-hint: "[<PR番号>]"
---

# prrange

fish 関数 `prrange` を実行する。
Bash ツールのシェルは fish ではないため、必ず `fish -c` で呼ぶ。
カレントディレクトリが対象 PR のリポジトリであること。

```bash
fish -c 'prrange <PR番号>'   # PR番号なしなら現在のブランチの PR
```

関数は次を行う。

1. `gh pr view` でベースとヘッドのブランチ名を取得する
2. `git fetch origin <base> <head>` でリモート参照を最新にする
3. `origin/<base>..origin/<head>` を `pbcopy` する

## 報告

コピーした範囲の文字列を 1 行で伝え、WebStorm の Git ログの「ブランチ」フィルタに貼れば PR のコミットだけになると添える。
PR が見つからない・fetch に失敗した場合は、エラー出力をそのまま伝える。
