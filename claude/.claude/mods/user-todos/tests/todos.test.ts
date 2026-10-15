import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On, RenderElement } from 'claude-code'

const SURFACES = ['terminal', 'desktop'] as const
const BAND = { hasSurvey: false, isWorking: false, maxRows: 20, bodyColumns: 80 }

// プラグインの下にある世界（cwd・git・ツール登録・帯の既定の描画）をテスト側で答える
const setup = async ($: Engine, on: On, store: Record<string, unknown> = {}) => {
  mock.clock(on, { now: 1_700_000_000_000 })
  mock.store(on, store)
  on('session.cwd', () => ({ value: '/home/me/repo-a' }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: '/home/me/repo-a\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('tool.register', ($, e) => ({ value: { tool: `mcp__user-todos__${e.name}` } }))
  on('session.start', () => ({ cwd: '/home/me/repo-a' }))
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => h($.ui.resolve(e).Box, {}) as RenderElement)
  await $.session.start({ cwd: '/home/me/repo-a', source: 'startup' } as never)
}

const call = ($: Engine, name: string, input: Record<string, unknown>) =>
  $.tool.call({ tool: `mcp__user-todos__${name}`, tool_use_id: `t-${name}-${Math.random()}`, ...input } as never)

const idOf = (text: unknown) => String(text).match(/id: ([0-9a-z]+)/)?.[1] ?? ''

for (const surface of SURFACES) {
  test(`${surface}: 今やるを登録すると帯に出て、✓で消える`, async ($, on) => {
    await setup($, on)
    const added = await call($, 'add', { text: 'Apple のメールが届いたら知らせる', when: 'now' })
    const id = idOf(added.result)

    const band = await $.ui.mount({ plugin: 'user-todos', surface, component: 'AbovePrompt', props: BAND as never })
    expect(await band.find({ text: /Apple のメール/ })).toBeDefined()

    await band.press({ key: `done-${id}` })
    expect(await band.findAll({ text: /Apple のメール/ })).toHaveLength(0)
    const listed = await call($, 'list', {})
    expect(String(listed.result)).not.toContain('Apple')
  })

  test(`${surface}: あとでは store に残り、帯は件数だけで開くと一覧が出る`, async ($, on) => {
    await setup($, on)
    await call($, 'add', { text: '証明書の更新期限を確認する', when: 'later' })

    const band = await $.ui.mount({ plugin: 'user-todos', surface, component: 'AbovePrompt', props: BAND as never })
    expect(await band.find({ text: /Later \(1\)/ })).toBeDefined()
    expect(await band.findAll({ text: /証明書/ })).toHaveLength(0)

    await band.press({ key: 'toggle-later' })
    expect(await band.find({ text: /証明書/ })).toBeDefined()
  })
}

test('move で今やるとあとでを行き来する', async ($, on) => {
  await setup($, on)
  const added = await call($, 'add', { text: 'PR を確認する', when: 'now' })
  const id = idOf(added.result)

  await call($, 'move', { id, to: 'later' })
  expect(String((await call($, 'list', {})).result)).toMatch(/あとで:\n {2}- [0-9a-z]+: PR を確認する/)

  await call($, 'done', { id })
  expect(String((await call($, 'list', {})).result)).not.toContain('PR を確認する')
})

test('他のセッションが書いたあとでを起動時に読み込む', async ($, on) => {
  await setup($, on, {
    later: [{ id: 'x1', text: '別リポジトリの作業', repo: 'repo-b', createdAt: '2026-10-01T00:00:00.000Z' }],
  })
  expect(String((await call($, 'list', {})).result)).toContain('x1: 別リポジトリの作業')
})
