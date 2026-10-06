# Git ブランチ・push 運用

## 概要

ブランチの upstream が `origin/main` 等を向いたまま素の `git push` が失敗する問題の再発防止。ブランチ作成時と push 時の手順を固定する。

## ガイドライン

### 必須

- **ブランチ作成**: リモート起点で切る場合は追跡設定を持ち込まない
  ```bash
  git switch -c <branch> origin/main --no-track
  ```
  （現在の HEAD から切るだけなら `git switch -c <branch>` でよい）
- **push**: 常に同名リモートブランチへ。初回・upstream 不一致時は `-u` で追跡を付け替える
  ```bash
  git push -u origin HEAD
  ```
- push 前に `git branch -vv` で upstream を確認し、`[origin/main]` 等ブランチ名と不一致なら上記で修正する
- PR 作成時、push 先の確認で A/B をユーザーに訊かない（常に同名ブランチ → PR）

### 禁止

- `main` などデフォルトブランチへの直接 push
- upstream がブランチ名と不一致のまま素の `git push` をリトライし続けること

## 補足

- グローバル git 設定に `push.autoSetupRemote = true` を設定済み（2026-07-10）。upstream 未設定のブランチは素の `git push` でも同名リモートブランチが自動作成・追跡される。ただし **upstream が既に別名（origin/main 等）に設定済みのブランチには効かない**ため、その場合は `git push -u origin HEAD` が必要。
