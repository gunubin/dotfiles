---
name: human-review
description: |
  PRまたは未コミット差分を、理解しやすい単位（チャンク）に分けて適切な順番で1つずつ解説し、人間のレビューを伴走する。
  `next` で次のチャンクへ進む対話型。AIが機械的チェックを担い、人間は意図・設計・ドメイン妥当性の判断に集中する。
  「PRをレビューしたい」「一緒にコードを読みたい」「差分を順番に解説して」時に使用。
allowed-tools: Bash(git *), Bash(gh *), Bash(fish -c *), Bash(mkdir *), Read, Grep, Glob, Write, Edit, AskUserQuestion, mcp__human-review-pane__show
argument-hint: "[<PR番号> | local]"
---

# human-review

## 目的

AI がコードを書く時代の人間レビューを支援する。
lint・型・典型的バグのような機械的チェックは AI に任せる。
人間は次の判断に集中する。

- 変更が意図（PR の目的・要件）と合っているか
- 設計判断は妥当か、もっと単純にできないか
- ドメイン上正しいか（仕様・業務ルール・エッジケース）
- AI 特有の失敗がないか（過剰実装、もっともらしいが誤った前提、不要な抽象化、意味のないテスト）
- 自分がこのコードを理解し、保守できるか

Claude はレビュアーではなく**案内役**として振る舞う。
判断を代行しない。
判断に必要な文脈と問いを差し出す。

## 引数

| 引数 | 対象 |
|------|------|
| `<PR番号>` | GitHub PR |
| `local` | 未コミット差分（staged + unstaged + untracked） |
| なし | AskUserQuestion で選ばせる（下記） |

引数なしの場合、`gh pr list --search "review-requested:@me" --state open --json number,title,author --limit 10` を取得し、AskUserQuestion で次の選択肢を出す。

- 未コミット差分（`git status --short` が空なら選択肢から外す）
- レビュー依頼中の PR（上位3件まで。それ以外は Other で番号入力）

## 実行手順

### Step 1: 対象の取得

**PR の場合**

```bash
gh pr view <N> --json number,title,body,author,baseRefName,headRefName,headRefOid,url,commits,files
gh pr diff <N>
git fetch origin pull/<N>/head
```

PR のコミット範囲 `origin/<base>..origin/<head>` をクリップボードにコピーする（WebStorm の Git ログのブランチフィルタに貼る用）。
Bash ツールのシェルは fish ではないため `fish -c` で呼ぶ。
失敗してもレビューは続ける。

```bash
fish -c 'prrange <N>'
```

周辺コードを読むため、PR の HEAD を worktree に展開する。
作業中のツリーは変更しない。

```bash
WT="$(git rev-parse --git-common-dir)/human-review/wt-<N>"
git worktree add --detach "$WT" FETCH_HEAD
```

以降、周辺コードの Read / Grep は `$WT` 配下で行う。
既に `$WT` があれば `git -C "$WT" checkout --detach FETCH_HEAD` で更新して再利用する。

**local の場合**

```bash
git status --short
git diff HEAD
git ls-files --others --exclude-standard   # untracked は Read で全文を差分として扱う
```

周辺コードはカレントのワーキングツリーをそのまま読む。

### Step 2: 意図の把握

チャンク分けの前に「この変更は何を達成しようとしているか」を把握する。

- PR: タイトル、本文、コミットメッセージ、リンクされた issue / チケット
- local: ブランチ名、直近コミット。意図が読み取れなければユーザーに一言で聞く

意図が曖昧なまま読み進めると、すべての判断が宙に浮く。
曖昧さ自体をレビュー観点として記録する。

### Step 3: チャンク分割と順序付け

[references/chunking.md](references/chunking.md) に従い、差分をチャンクに分割して順序を決める。

結果を状態ファイルに保存する（コンテキスト圧縮後も再開できるようにするため）。
`.git` 配下に置くので、コミット対象にはならない。ディレクトリは `mkdir -p` で作成する。

```
$(git rev-parse --git-common-dir)/human-review/<pr-N|local>/state.md
```

state.md の形式:

```markdown
# <対象> <タイトル>
意図: <1〜2文>
現在: <チャンク番号>

## チャンク
| # | 分類 | 対象 | 状態 |
|---|------|------|------|
| 1 | 契約 | src/types/user.ts | 済 |
| 2 | コア | src/domain/user.ts (validate, normalize) | 表示中 |

## コメント
- [#2] src/domain/user.ts:L42 — <内容>
```

### Step 4: 全体マップの提示

最初に次を表示し、ユーザーの `next` を待つ。

```markdown
## 🗺 全体マップ: <タイトル>

**意図**: <1〜2文>
**規模**: <ファイル数> files, +<追加> -<削除>

| # | 分類 | 対象 | 要点 |
|---|------|------|------|
| 1 | 契約 | ... | ... |
| ... |

**この順番の理由**: <なぜこの順で読むか。1〜3文>
**全体で人間が判断すべきこと**: <この変更全体に対する問い 1〜2個>

`next` で #1 へ
```

### Step 5: チャンクごとの解説

`next` を受けるたびに、[references/chunk-template.md](references/chunk-template.md) の形式で1チャンクを解説する。
解説を作る前に、そのチャンクの周辺コード（呼び出し元・呼び出し先・既存の類似実装）を必要なだけ Read / Grep する。
差分だけを見て推測で書かない。

表示後、state.md の「現在」と状態を更新する。

### ペイン表示（human-review-pane Mod）

ツール `mcp__human-review-pane__show` が使える場合、コードはペインに色付きで表示する。

- 全体マップ提示時（`current: 0`, `diff: ""`）、各チャンクの解説時、`c` でコメントを記録した直後に呼ぶ
- まとめ表示時（`phase: "summary"`）と、投稿完了または投稿しないと決まった時点（`phase: "finished"`）にも呼ぶ。local の場合はまとめ表示後に `finished` を渡す
- 引数には毎回全体を渡す（呼ぶたびに表示が丸ごと置き換わる）
  - `phase`: `map`（全体マップ）/ `chunk`（解説中）/ `summary`（まとめ・投稿確認中）/ `finished`（終了）。入力欄の上の帯に進捗と一緒に表示される
  - `title`: PR の場合は `PR #<N> <タイトル> ｜ origin/<base>..origin/<head>` の形で、コミット範囲を末尾に付ける。local の場合は範囲を付けない
  - `chunks`: state.md のチャンク一覧（`status` は done / current / todo）
  - `diff`: このチャンクの unified diff。`@@` ハンクの途中で切らない
  - `refs`: 「なぜ・どこに効くか」で参照した周辺コード。1件 30 行以内、前後数行を含める
  - `comments`: 記録済みコメント全件
- ペインに表示した場合、チャットには差分全文を出さず、解説だけを書く
- ツールが無い、またはエラーになった場合は、チャットに差分全文を出す
- ペインが見えないとユーザーが言ったら `/review-pane` で開けると案内する

### Step 6: 操作コマンド

| コマンド | 動作 |
|----------|------|
| `next` / `n` | 次のチャンクへ |
| `back` / `b` | 前のチャンクを再表示 |
| `skip <番号>` | 指定チャンクへジャンプ |
| `map` | 全体マップと進捗（済/未）を再表示 |
| `c <内容>` | 現在チャンクにコメント記録 |
| `c L<行> <内容>` | 現在チャンクの指定行にコメント記録 |
| `comments` | 記録済みコメント一覧 |
| `done` | 終了してまとめへ（Step 7） |

- コマンド以外の入力は質問として扱い、答える。答えた後も現在位置は維持し、末尾に `next で #<次番号> へ` を添える
- `c` は state.md に追記し、「記録しました（計 N 件）」とだけ返す
- `c` で行番号を省略した場合、内容から該当行を推定できれば補う。推定できなければファイル単位のコメントとして記録する
- 最後のチャンクで `next` を受けたら Step 7 へ進む

### Step 7: まとめと投稿

```markdown
## ✅ レビュー完了: <タイトル>

**確認したチャンク**: N / M（未確認: #x, #y）
**記録したコメント**: K 件

| # | 場所 | コメント |
|---|------|---------|
| 1 | path:L42 | ... |

**全体所感（AI）**: <意図との整合、気になった設計上の点を2〜3文。判断はユーザーに委ねる>
```

**PR の場合**、AskUserQuestion で投稿方法を確認する。

- 選択肢: `COMMENT` / `APPROVE` / `REQUEST_CHANGES` / 投稿しない
- 本文（Review の body）の下書きを preview に含める
- コメントの文面は、ユーザーが `c` で書いた内容を尊重する。整形は敬体化・誤字修正程度にとどめ、主張を変えない

承認されたら、行コメントをまとめて1つの Review として投稿する。

```bash
gh api repos/{owner}/{repo}/pulls/<N>/reviews --method POST --input <payload.json>
```

payload:

```json
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT",
  "body": "<全体コメント>",
  "comments": [
    { "path": "src/domain/user.ts", "line": 42, "side": "RIGHT", "body": "..." }
  ]
}
```

- `line` は差分に含まれる行のみ指定可能。差分外の行やファイル単位のコメントは body に `path:line` 付きで含める
- 削除行へのコメントは `side: "LEFT"` と旧ファイルの行番号を使う
- 投稿後、PR の URL を表示する

**local の場合**、一覧表示のみで終える。

### Step 8: 後片付け

PR の場合、worktree を削除する。

```bash
git worktree remove --force "$WT"
```

state.md は残す（同じ PR を再レビューする際の参考になる）。
同じ対象で再度起動されたとき、state.md があれば「前回の続きから再開するか、最初からやり直すか」を AskUserQuestion で聞く。

## 禁止事項

- ユーザーの承認なしに PR へ投稿すること
- 1回の応答で複数チャンクを解説すること（ユーザーが明示的に求めた場合を除く）
- 「問題ありません」「LGTM です」のように承認判断を代行すること
- 差分を読まずに要約だけで解説すること
