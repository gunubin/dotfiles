import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Todo, TodoWhen } from '../types'

const PLUGIN = 'user-todos'
const TOOL_ADD = 'mcp__user-todos__add'
const TOOL_DONE = 'mcp__user-todos__done'
const TOOL_MOVE = 'mcp__user-todos__move'
const TOOL_LIST = 'mcp__user-todos__list'
// 「あとで」は全セッション共通なので $.store に置き、帯の描画用に $.state へ写す
const LATER_STORE_KEY = 'later'
// 他のセッションが「あとで」を書き換えても帯に反映されるよう、定期的に読み直す
const SYNC_MS = 30_000

const now = atom({ plugin: 'user-todos', key: 'now' } as const, [] as Todo[])
const later = atom({ plugin: 'user-todos', key: 'later' } as const, [] as Todo[])
// ターミナルの配色（Catppuccin Mocha）に揃えたパステルの黄色
const NOW_COLOR = '#f9e2af'
const isLaterOpen = atom({ plugin: 'user-todos', key: 'isLaterOpen' } as const, false)

const WHEN_SCHEMA = {
  type: 'string',
  enum: ['now', 'later'],
  description: 'now: 今の作業を進めるのにユーザーの行動が要る / later: 今すぐではないが、あとでユーザーがやること',
}

const isTodo = (value: unknown): value is Todo =>
  typeof value === 'object' &&
  value !== null &&
  typeof (value as Todo).id === 'string' &&
  typeof (value as Todo).text === 'string'

const loadLater = async ($: EngineInterface): Promise<Todo[]> => {
  const stored = await $.store.get(LATER_STORE_KEY)
  return Array.isArray(stored) ? stored.filter(isTodo) : []
}

// 他のセッションの書き込みを消さないよう、書き換えのたびに $.store から読み直してから書く
const changeLater = async ($: EngineInterface, fn: (list: Todo[]) => Todo[]): Promise<Todo[]> => {
  const next = fn(await loadLater($))
  await $.store.set(LATER_STORE_KEY, next)
  await update($, later, () => next)
  return next
}

const syncLater = async ($: EngineInterface) => {
  const stored = await loadLater($)
  await update($, later, () => stored)
}

const repoName = async ($: EngineInterface): Promise<string> => {
  const cwd = await $.session.cwd()
  try {
    const { exitCode, stdout } = await $.process.run(['git', 'rev-parse', '--show-toplevel'], { timeoutMs: 5000 })
    const root = exitCode === 0 ? stdout.trim() : ''
    return (root || cwd).split('/').pop() ?? cwd
  } catch {
    return cwd.split('/').pop() ?? cwd
  }
}

const formatList = (nowList: Todo[], laterList: Todo[]) => {
  const lines = (list: Todo[]) => (list.length === 0 ? ['  （なし）'] : list.map(todo => `  - ${todo.id}: ${todo.text}`))
  return ['今やる:', ...lines(nowList), 'あとで:', ...lines(laterList)].join('\n')
}

const findIn = async ($: EngineInterface, id: string): Promise<TodoWhen | undefined> => {
  if ((await read($, now)).some(todo => todo.id === id)) return 'now'
  if ((await loadLater($)).some(todo => todo.id === id)) return 'later'
  return undefined
}

const remove = async ($: EngineInterface, id: string) => {
  await update($, now, list => list.filter(todo => todo.id !== id))
  await changeLater($, list => list.filter(todo => todo.id !== id))
}

// 同じミリ秒に複数登録されても id が重ならないよう、連番を足す
let sequence = 0
const newId = async ($: EngineInterface) => {
  sequence += 1
  return `${(await $.clock.now()).toString(36)}${sequence.toString(36)}`
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await syncLater($)
    $.clock.every(SYNC_MS, () => void syncLater($))

    await $.tool.register({
      name: 'add',
      description:
        'ユーザーにやってもらうことを、プロンプト上の帯に登録して常に見えるようにする。' +
        '確認・動作確認・判断・外部の連絡待ちなど、ユーザーが何かしないと作業が進まないときは、返答で頼むのと同時に必ず when=now で登録する。' +
        '今すぐではないがあとでユーザーがやること（後回しにした作業、期日のある対応など）は when=later で登録する（全セッション・全リポジトリ共通で残る）。' +
        'text は「誰が・何をしたら再開できるか」がわかる1文にする。機密情報（APIキー、顧客名、社内URL）は書かない。',
      inputSchema: {
        type: 'object',
        properties: {
          text: { type: 'string', description: 'ユーザーにやってもらうこと（1文）' },
          when: WHEN_SCHEMA,
        },
        required: ['text', 'when'],
      },
      isDeferred: false,
    })
    await $.tool.register({
      name: 'done',
      description:
        '帯に登録した項目を完了にして消す。ユーザーがやったと言った、または結果から済んだとわかったときに呼ぶ。' +
        'ユーザーが返事をしただけで、頼んだことが済んでいなければ消さない。',
      inputSchema: {
        type: 'object',
        properties: { id: { type: 'string', description: 'add / list が返した項目の id' } },
        required: ['id'],
      },
      isDeferred: false,
    })
    await $.tool.register({
      name: 'move',
      description: '項目を「今やる」と「あとで」の間で移す。ユーザーが後回しにすると言ったときや、あとでの項目に今取りかかるときに呼ぶ。',
      inputSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'add / list が返した項目の id' },
          to: WHEN_SCHEMA,
        },
        required: ['id', 'to'],
      },
      isDeferred: false,
    })
    await $.tool.register({
      name: 'list',
      description: '帯に登録されている「今やる」と「あとで」の項目を id 付きで返す。',
      inputSchema: { type: 'object', properties: {} },
      isDeferred: false,
    })

    return next(e)
  })

  // ツールの引数は e.input ではなく e の直下に載る（tool / tool_use_id / agentId は予約キー）
  on('tool.call', { tool: TOOL_ADD }, async ($, e) => {
    const { text, when } = e as unknown as { text: string; when: TodoWhen }
    const todo: Todo = {
      id: await newId($),
      text: text.trim(),
      repo: await repoName($),
      createdAt: new Date(await $.clock.now()).toISOString(),
    }
    if (when === 'later') {
      await changeLater($, list => [...list, todo])
    } else {
      await update($, now, list => [...list, todo])
    }
    return { result: `${when === 'later' ? 'あとで' : '今やる'}に登録しました（id: ${todo.id}）。` }
  })

  on('tool.call', { tool: TOOL_DONE }, async ($, e) => {
    const { id } = e as unknown as { id: string }
    if ((await findIn($, id)) === undefined) {
      return { result: `id ${id} の項目はありません。\n${formatList(await read($, now), await loadLater($))}` }
    }
    await remove($, id)
    return { result: `${id} を完了にしました。` }
  })

  on('tool.call', { tool: TOOL_MOVE }, async ($, e) => {
    const { id, to } = e as unknown as { id: string; to: TodoWhen }
    const from = await findIn($, id)
    if (from === undefined) {
      return { result: `id ${id} の項目はありません。\n${formatList(await read($, now), await loadLater($))}` }
    }
    if (from === to) {
      return { result: `${id} はすでに${to === 'later' ? 'あとで' : '今やる'}にあります。` }
    }
    const todo = (from === 'now' ? await read($, now) : await loadLater($)).find(one => one.id === id)
    if (todo === undefined) {
      return { result: `id ${id} の項目はありません。` }
    }
    await remove($, id)
    if (to === 'later') {
      await changeLater($, list => [...list, todo])
    } else {
      await update($, now, list => [...list, todo])
    }
    return { result: `${id} を${to === 'later' ? 'あとで' : '今やる'}に移しました。` }
  })

  on('tool.call', { tool: TOOL_LIST }, async $ => {
    await syncLater($)
    return { result: formatList(await read($, now), await read($, later)) }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const nowList = await read($, now)
    const laterList = await read($, later)
    if (e.props.hasSurvey || (nowList.length === 0 && laterList.length === 0)) {
      return next(e)
    }

    const { Box, Button, Text } = $.ui.resolve(e)
    const isOpen = await read($, isLaterOpen)
    const row = (todo: Todo, actions: 'now' | 'later') => (
      <Box key={`row-${todo.id}`} flexDirection="row">
        <Button key={`done-${todo.id}`} label="✓" onPress={() => remove($, todo.id)} />
        <Text> </Text>
        {actions === 'later' && (
          <Button
            key={`up-${todo.id}`}
            label="今やる"
            onPress={async () => {
              await remove($, todo.id)
              await update($, now, list => [...list, todo])
            }}
          />
        )}
        <Text wrap="truncate-end">
          {actions === 'later' ? ' ' : ''}
          {todo.text}
          {actions === 'later' && <Text dimColor> {todo.repo}</Text>}
        </Text>
      </Box>
    )

    return (
      <Box flexDirection="column">
        {nowList.length > 0 && (
          <Text bold color={NOW_COLOR}>
            ▶ Your turn ({nowList.length})
          </Text>
        )}
        {nowList.map(todo => row(todo, 'now'))}
        {laterList.length > 0 && (
          <Box flexDirection="row">
            <Button
              key="toggle-later"
              plain
              onPress={() => update($, isLaterOpen, open => !open)}
            >
              <Text dimColor>
                {isOpen ? '▼' : '▶'} Later ({laterList.length})
              </Text>
            </Button>
          </Box>
        )}
        {isOpen && laterList.map(todo => row(todo, 'later'))}
      </Box>
    )
  })
}
