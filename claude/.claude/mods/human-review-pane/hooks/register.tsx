import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { DiffMode, ReviewView } from '../types'

const PANE = 'human-review'
const TITLE = 'Review'
const TOOL = 'mcp__human-review-pane__show'
const view = atom({ plugin: 'human-review-pane', key: 'view' } as const, null as ReviewView | null)
const isBandHidden = atom({ plugin: 'human-review-pane', key: 'isBandHidden' } as const, false)
const diffMode = atom({ plugin: 'human-review-pane', key: 'diffMode' } as const, 'unified' as DiffMode)
const DIFF_MODE_STORE_KEY = 'diffMode'
// split は左右それぞれにコードが収まる幅がないと読めないので、狭いときは unified で描く
const SPLIT_MIN_COLUMNS = 100

const STATUS_MARK = { done: '✓', current: '▶', todo: '·' } as const
const PHASE_LABEL = { map: '🗺 マップ', chunk: '📖 解説中', summary: '📋 まとめ', finished: '✅ 完了' } as const
const BAR_WIDTH = 20

type FileDiff = { path: string; renamedFrom?: string; hunks: string[] }
type Side = { no: number; text: string; kind: 'context' | 'removed' | 'added' }
type SplitRow = { left?: Side; right?: Side } | { header: string }

// git diff の出力から diff --git / index / rename 等のヘッダを除き、ファイルごとのハンクだけを取り出す。
// Code の diff 表示は --- / +++ 以外のヘッダがあるとハンクとして読めず、ただのコードとして描いてしまう。
const parseDiff = (diff: string, fallbackPath: string): FileDiff[] => {
  const files: FileDiff[] = []
  const lines = diff.split('\n')
  let file: FileDiff | undefined
  let isInHunk = false
  const startFile = (path: string) => {
    file = { path, hunks: [] }
    files.push(file)
    isInHunk = false
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i] ?? ''
    const following = lines[i + 1] ?? ''
    if (line.startsWith('diff --git ')) {
      startFile(line.split(' b/').pop() ?? fallbackPath)
      continue
    }
    if (line.startsWith('--- ') && following.startsWith('+++ ')) {
      const newPath = following.slice(4).replace(/^b\//, '')
      const oldPath = line.slice(4).replace(/^a\//, '')
      const path = newPath === '/dev/null' ? oldPath : newPath
      if (file === undefined || file.hunks.length > 0) {
        startFile(path)
      } else {
        file.path = path
      }
      i++
      continue
    }
    if (line.startsWith('@@')) {
      if (file === undefined) {
        startFile(fallbackPath)
      }
      isInHunk = true
      file?.hunks.push(line)
      continue
    }
    if (file !== undefined && !isInHunk) {
      if (line.startsWith('rename from ')) {
        file.renamedFrom = line.slice('rename from '.length)
      }
      continue
    }
    if (isInHunk && file !== undefined) {
      file.hunks.push(line === '' ? ' ' : line)
    }
  }

  // 末尾の改行で生じた空のコンテキスト行を落とす
  for (const one of files) {
    while (one.hunks.at(-1) === ' ') {
      one.hunks.pop()
    }
  }

  return files
}

// 削除行の塊と直後の追加行の塊を、GitHub の split 表示と同じく上から順に左右へ対応させる
const toSplitRows = (hunks: string[]): SplitRow[] => {
  const rows: SplitRow[] = []
  let oldNo = 0
  let newNo = 0
  let removed: Side[] = []
  let added: Side[] = []
  const flush = () => {
    for (let i = 0; i < Math.max(removed.length, added.length); i++) {
      rows.push({ left: removed[i], right: added[i] })
    }
    removed = []
    added = []
  }

  for (const line of hunks) {
    const header = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line)
    if (header !== null) {
      flush()
      oldNo = Number(header[1])
      newNo = Number(header[2])
      rows.push({ header: line })
    } else if (line.startsWith('-')) {
      removed.push({ no: oldNo++, text: line.slice(1), kind: 'removed' })
    } else if (line.startsWith('+')) {
      added.push({ no: newNo++, text: line.slice(1), kind: 'added' })
    } else if (!line.startsWith('\\')) {
      flush()
      const text = line.slice(1)
      rows.push({ left: { no: oldNo++, text, kind: 'context' }, right: { no: newNo++, text, kind: 'context' } })
    }
  }
  flush()

  return rows
}

// 背景を塗るとハイライトされた文字が読みにくくなるため、行頭の縦バー・記号・行番号の色で変更行を示す。
// 色は 256 色に丸められても変わらないよう、パレットにそのまま在るパステルピンクとミントを使う
const SIDE_ACCENT = { context: undefined, removed: '#ff87af', added: '#87d7af' } as const
// 行の背景は catppuccin Mocha の赤・緑を背景色に薄く溶かした色。
// tmux 内では CLAUDE_CODE_TMUX_TRUECOLOR が無いと 256 色に丸められ、両方とも灰色に潰れる
// 本体はペインを明るめの面の色で描くため、本文全体を端末（catppuccin Mocha）の背景色で塗り潰す
const PANE_BACKGROUND = '#1e1e2e'
const SIDE_BACKGROUND = { context: undefined, removed: '#45293a', added: '#283f33' } as const
const SIDE_BAR = { context: ' ', removed: '▌', added: '▌' } as const
const SIDE_SIGN = { context: ' ', removed: '-', added: '+' } as const

type UnifiedRow = { oldNo?: number; newNo?: number; text: string; kind: Side['kind'] } | { header: string }

// unified も Code の diff 表示に任せず split と同じ見た目で描く（テーマ次第で追加・削除の背景がほぼ見えないため）
const toUnifiedRows = (hunks: string[]): UnifiedRow[] => {
  const rows: UnifiedRow[] = []
  let oldNo = 0
  let newNo = 0
  for (const line of hunks) {
    const header = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line)
    if (header !== null) {
      oldNo = Number(header[1])
      newNo = Number(header[2])
      rows.push({ header: line })
    } else if (line.startsWith('-')) {
      rows.push({ oldNo: oldNo++, text: line.slice(1), kind: 'removed' })
    } else if (line.startsWith('+')) {
      rows.push({ newNo: newNo++, text: line.slice(1), kind: 'added' })
    } else if (!line.startsWith('\\')) {
      rows.push({ oldNo: oldNo++, newNo: newNo++, text: line.slice(1), kind: 'context' })
    }
  }

  return rows
}

const INPUT_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string', description: 'レビュー対象（例: "PR #123 ユーザー検索の追加"）' },
    phase: {
      type: 'string',
      enum: ['map', 'chunk', 'summary', 'finished'],
      description: '段階。map: 全体マップ表示中 / chunk: チャンク解説中 / summary: まとめ表示・投稿確認中 / finished: 投稿済みまたは終了',
    },
    chunks: {
      type: 'array',
      description: '全チャンクの一覧と状態',
      items: {
        type: 'object',
        properties: {
          n: { type: 'number' },
          kind: { type: 'string', description: '契約 / コア / 配線 / テスト / その他' },
          label: { type: 'string', description: '対象ファイル・関数名' },
          status: { type: 'string', enum: ['done', 'current', 'todo'] },
        },
        required: ['n', 'kind', 'label', 'status'],
      },
    },
    current: { type: 'number', description: '表示中のチャンク番号。全体マップ表示時は 0' },
    path: { type: 'string', description: '差分のファイルパス（言語判定に使う）。複数ファイルなら主たるもの' },
    diff: {
      type: 'string',
      description: 'このチャンクの unified diff（@@ ハンク単位、途中で切らない）。全体マップ表示時は空文字',
    },
    refs: {
      type: 'array',
      description: '解説で参照した周辺コード',
      items: {
        type: 'object',
        properties: {
          path: { type: 'string' },
          startLine: { type: 'number', description: 'source の1行目の行番号' },
          source: { type: 'string', description: '参照箇所のコード（前後数行を含めて 30 行以内）' },
          note: { type: 'string', description: '何のための参照か（例: 呼び出し元）' },
        },
        required: ['path', 'startLine', 'source'],
      },
    },
    comments: {
      type: 'array',
      description: '記録済みコメント全件',
      items: {
        type: 'object',
        properties: {
          chunk: { type: 'number' },
          location: { type: 'string', description: 'path:L42 など' },
          text: { type: 'string' },
        },
        required: ['chunk', 'location', 'text'],
      },
    },
  },
  required: ['title', 'phase', 'chunks', 'current', 'path', 'diff', 'refs', 'comments'],
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'review-pane',
      description: 'human-review のペインを開く',
    })
    const stored = await $.store.get(DIFF_MODE_STORE_KEY)
    if (stored === 'unified' || stored === 'split') {
      await update($, diffMode, () => stored)
    }
    await $.tool.register({
      name: 'show',
      description:
        'human-review skill 専用。現在のチャンクの差分・参照コード・進捗・コメントをペインに色付きで表示する。' +
        '呼ぶたびに表示内容を丸ごと置き換える。',
      inputSchema: INPUT_SCHEMA,
    })

    return next(e)
  })

  on('command.run', { command: 'review-pane' }, async $ => {
    await $.ui.open({ id: PANE, title: TITLE })

    return { text: 'レビューペインを開きました。' }
  })

  on('tool.call', { tool: TOOL }, async ($, e) => {
    // ツールの引数は e.input ではなく e の直下に載る（tool / tool_use_id / agentId は予約キー）
    const { title, phase, chunks, current, path, diff, refs, comments } = e as unknown as ReviewView
    const incoming: ReviewView = { title, phase, chunks, current, path, diff, refs, comments }
    const previous = await read($, view)
    await update($, view, () => incoming)
    await update($, isBandHidden, () => false)
    await $.ui.open({ id: PANE, title: TITLE })
    // チャンクや段階が変わったときだけ先頭に戻す（c でコメントを足しただけなら読んでいた位置を保つ）
    if (previous?.current !== incoming.current || previous?.phase !== incoming.phase) {
      await $.ui.scroll({ in: PANE, to: 'start' })
    }

    return { result: `#${incoming.current} をペインに表示しました。` }
  })

  // 引数（差分全文など）を会話ログに展開させず、1行の要約に差し替える
  on('ui.render', { component: 'ToolUse', props: { tool: TOOL } }, async ($, e) => {
    const { Text } = $.ui.resolve(e)
    const input = e.props.input as Partial<ReviewView>
    const phase = input.phase ?? 'chunk'
    const chunk = input.chunks?.find(one => one.n === input.current)
    const target =
      phase === 'chunk' && chunk !== undefined
        ? `#${chunk.n}/${input.chunks?.length ?? 0} ${chunk.kind}: ${chunk.label}`
        : PHASE_LABEL[phase]
    const state = e.props.isErrored ? ' （表示に失敗）' : e.props.isRunning ? ' …' : ''

    return (
      <Text dimColor={!e.props.isErrored} color={e.props.isErrored ? 'error' : undefined} wrap="truncate-end">
        📝 ペインに表示: {target}
        {state}
      </Text>
    )
  })

  // 完了表示は次の入力まで残し、その後は帯を消す
  on('prompt.submit', async ($, e, next) => {
    const current = await read($, view)
    if (current?.phase === 'finished') {
      await update($, isBandHidden, () => true)
    }

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const current = await read($, view)
    if (e.props.hasSurvey || current === null || (await read($, isBandHidden))) {
      return next(e)
    }

    const { Box, Button, Text } = $.ui.resolve(e)
    const mode = await read($, diffMode)
    const total = current.chunks.length
    const done = current.chunks.filter(chunk => chunk.status === 'done').length
    const filled = total === 0 ? 0 : Math.round((done / total) * Math.min(total, BAR_WIDTH))
    const empty = Math.min(total, BAR_WIDTH) - filled
    const chunk = current.chunks.find(one => one.n === current.current)

    return (
      <Box flexDirection="column">
        {/* PR ではタイトルにコミット範囲が付いて長くなるため、進捗とは別の行に置いて押し出さないようにする */}
        <Text bold wrap="truncate-end">
          📝 {current.title}
        </Text>
        <Text wrap="truncate-end">
          <Text color="success">{'■'.repeat(filled)}</Text>
          <Text dimColor>{'□'.repeat(empty)}</Text> {done}/{total}
          {'  '}
          <Text color="suggestion">{PHASE_LABEL[current.phase] ?? PHASE_LABEL.chunk}</Text>
          {'  '}💬 {current.comments.length}
          {/* 長いチャンク名で他の情報が切れないよう、末尾に置く */}
          {chunk !== undefined && current.phase === 'chunk' && (
            <Text>
              {'  '}▶ #{chunk.n} {chunk.kind}: {chunk.label}
            </Text>
          )}
        </Text>
        <Box>
          <Button
            key="diff-mode"
            label={mode === 'split' ? '⇆ split' : '☰ unified'}
            onPress={async () => {
              const toggled: DiffMode = mode === 'split' ? 'unified' : 'split'
              await update($, diffMode, () => toggled)
              await $.store.set(DIFF_MODE_STORE_KEY, toggled)
            }}
          />
          <Text dimColor wrap="truncate-end">
            {'  '}n:次へ  b:戻る  skip N:ジャンプ  c 内容:コメント  map:一覧  comments:コメント一覧  done:終了
          </Text>
        </Box>
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Code } = $.ui.resolve(e)
    const current = await read($, view)
    const fill = { backgroundColor: PANE_BACKGROUND, minHeight: e.props.scroll.bodyRows, flexGrow: 1 } as const

    if (current === null) {
      return (
        <Box {...fill}>
          <Text dimColor>レビュー開始前です。/human-review で始めてください。</Text>
        </Box>
      )
    }

    const total = current.chunks.length
    const isSplit = (await read($, diffMode)) === 'split' && e.props.bodyColumns >= SPLIT_MIN_COLUMNS
    const sideColumns = Math.floor((e.props.bodyColumns - 1) / 2)
    const gutterWidth = 7
    const files = current.diff === '' ? [] : parseDiff(current.diff, current.path)

    const drawSide = (side: Side | undefined, path: string) => (
      <Box width={sideColumns} backgroundColor={side === undefined ? undefined : SIDE_BACKGROUND[side.kind]}>
        <Box width={gutterWidth} flexShrink={0}>
          {side !== undefined && (
            <Text>
              <Text color={SIDE_ACCENT[side.kind]}>{SIDE_BAR[side.kind]}</Text>
              <Text color={SIDE_ACCENT[side.kind]} dimColor={side.kind === 'context'}>
                {String(side.no).padStart(gutterWidth - 3)}
              </Text>
              <Text color={SIDE_ACCENT[side.kind]} bold>
                {SIDE_SIGN[side.kind]}
              </Text>
            </Text>
          )}
        </Box>
        {side === undefined || side.text === '' ? (
          <Text> </Text>
        ) : (
          <Code source={side.text} path={path} wrap="truncate-end" />
        )}
      </Box>
    )

    return (
      <Box flexDirection="column" gap={1} {...fill}>
        <Box flexDirection="column">
          <Text bold>{current.title}</Text>
          {current.chunks.map(chunk => (
            <Text
              color={chunk.status === 'current' ? 'suggestion' : undefined}
              bold={chunk.status === 'current'}
              dimColor={chunk.status === 'done'}
              wrap="truncate-end"
            >
              {STATUS_MARK[chunk.status]} #{chunk.n} {chunk.kind}: {chunk.label}
            </Text>
          ))}
        </Box>

        {files.map(file => (
          <Box flexDirection="column">
            <Text color="suggestion" bold wrap="truncate-end">
              ── #{current.current}/{total} 差分: {file.path}
              {file.renamedFrom === undefined ? '' : `（← ${file.renamedFrom}）`}
            </Text>
            {file.hunks.length === 0 ? (
              <Text dimColor>（内容の変更なし）</Text>
            ) : isSplit ? (
              toSplitRows(file.hunks).map(row =>
                'header' in row ? (
                  <Text dimColor wrap="truncate-end">
                    {row.header}
                  </Text>
                ) : (
                  <Box flexDirection="row">
                    {drawSide(row.left, file.path)}
                    <Text dimColor>│</Text>
                    {drawSide(row.right, file.path)}
                  </Box>
                ),
              )
            ) : (
              toUnifiedRows(file.hunks).map(row =>
                'header' in row ? (
                  <Text dimColor wrap="truncate-end">
                    {row.header}
                  </Text>
                ) : (
                  <Box flexDirection="row" backgroundColor={SIDE_BACKGROUND[row.kind]}>
                    <Box width={gutterWidth * 2 - 2} flexShrink={0}>
                      <Text>
                        <Text color={SIDE_ACCENT[row.kind]}>{SIDE_BAR[row.kind]}</Text>
                        <Text color={SIDE_ACCENT[row.kind]} dimColor={row.kind === 'context'}>
                          {(row.oldNo === undefined ? '' : String(row.oldNo)).padStart(gutterWidth - 3)}{' '}
                          {(row.newNo === undefined ? '' : String(row.newNo)).padStart(gutterWidth - 3)}
                        </Text>
                        <Text color={SIDE_ACCENT[row.kind]} bold>
                          {SIDE_SIGN[row.kind]}
                        </Text>
                      </Text>
                    </Box>
                    {row.text === '' ? <Text> </Text> : <Code source={row.text} path={file.path} />}
                  </Box>
                ),
              )
            )}
          </Box>
        ))}

        {current.refs.map(ref => (
          <Box flexDirection="column">
            <Text color="warning">
              ── 参照: {ref.path}:{ref.startLine}
              {ref.note === undefined ? '' : `（${ref.note}）`}
            </Text>
            <Code source={ref.source} path={ref.path} startLine={ref.startLine} />
          </Box>
        ))}

        {current.comments.length > 0 && (
          <Box flexDirection="column">
            <Text color="success" bold>
              ── コメント（{current.comments.length}件）
            </Text>
            {current.comments.map(comment => (
              <Text>
                [#{comment.chunk}] <Text dimColor>{comment.location}</Text> {comment.text}
              </Text>
            ))}
          </Box>
        )}
      </Box>
    )
  })
}
