import { expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On, RenderElement } from 'claude-code'

// macOS では /home が自動マウント（ネットワーク扱い）なので、実在しうる /tmp 配下を HOME に見立てる
const HOME = '/tmp/image-inline-home'
const CWD = '/tmp/image-inline-home/repo'
const SIPS_OK = { exitCode: 0, stderr: '', isStdoutTruncated: false, isStderrTruncated: false }

type World = { files: string[]; tmux?: string }

// プラグインの下にある世界（HOME・cwd・tmux の有無・ファイルの有無・sips の答え）をテスト側で答える
const setup = ($: Engine, on: On, world: World) => {
  const ran: string[][] = []
  on('env.get', ($, e) => ({ value: e.name === 'HOME' ? HOME : e.name === 'TMUX' ? world.tmux : undefined }))
  on('session.cwd', () => ({ value: CWD }))
  on('fs.stat', ($, e) => {
    if (!world.files.includes(e.path)) {
      throw new Error('ENOENT')
    }

    return { value: { kind: 'file' as const, size: 1234, mtimeMs: 1_700_000_000_000, isLink: false } }
  })
  on('fs.exists', () => ({ value: false }))
  on('fs.write', () => ({ value: undefined }))
  on('process.run', ($, e) => {
    ran.push([...e.argv])
    const isProbe = e.argv[0] === 'sips' && e.argv.includes('-g')

    return { value: { ...SIPS_OK, stdout: isProbe ? '  pixelWidth: 800\n  pixelHeight: 400\n' : '' } }
  })
  on('ui.render', { component: 'AssistantMessage' }, ($, e) => h($.ui.resolve(e).Text, {}, 'engine') as RenderElement)

  return ran
}

const mount = ($: Engine, surface: 'terminal' | 'desktop', text: string) =>
  $.ui.mount({ plugin: 'image-inline', surface, component: 'AssistantMessage', props: { text, isFirstOfReply: true } as never })

test('terminal（tmux の外）: 実在する PNG の絶対パスは engine の Image で本文に描き、見出しが出る', async ($, on) => {
  const ran = setup($, on, { files: ['/tmp/shot.png'] })
  const row = await mount($, 'terminal', 'スクリーンショットを /tmp/shot.png に保存しました。')
  expect(await row.find({ text: /engine/ })).toBeDefined()
  expect(await row.find({ text: /\/tmp\/shot\.png \(800×400\)/ })).toBeDefined()
  expect(await row.findAll({ text: /開く/ })).toHaveLength(0)
  // PNG はそのまま端末に読ませるので、変換の sips は走らない
  expect(ran.filter(argv => argv.includes('--out'))).toHaveLength(0)
})

test('terminal（tmux の中）: 本文には「開く」ボタンを出し、押すと tmux のポップアップで開く', async ($, on) => {
  const ran = setup($, on, { files: ['/tmp/shot.png'], tmux: '/tmp/tmux-501/default,1,0' })
  const row = await mount($, 'terminal', '/tmp/shot.png に保存しました。')
  expect(await row.find({ text: /\/tmp\/shot\.png \(800×400\)/ })).toBeDefined()
  expect(ran.filter(argv => argv[0] === 'tmux')).toHaveLength(0)

  await row.press({ key: 'open:/tmp/shot.png' })
  const popups = ran.filter(argv => argv[0] === 'tmux')
  expect(popups).toHaveLength(1)
  const command = popups[0]?.[3] ?? ''
  expect(popups[0]?.slice(1, 3)).toEqual(['run-shell', '-b'])
  expect(command).toContain('tmux display-popup -E')
  // 800×400 は横 60 列に収めると縦 15 行。ポップアップはその外側に余白を足す
  expect(command).toContain('-w 64 -h 21')
  expect(command).toContain('scripts/show-image.py')
  expect(command).toContain("'/tmp/shot.png'")
})

test('terminal（tmux の中）: ~/ と相対パスは HOME と cwd から解決し、JPEG は PNG に変換する', async ($, on) => {
  const ran = setup($, on, { files: [`${HOME}/Pictures/a.jpg`, `${CWD}/docs/b.webp`], tmux: 'x' })
  const row = await mount($, 'terminal', '`~/Pictures/a.jpg` と ./docs/b.webp を確認してください')
  expect(await row.find({ text: /~\/Pictures\/a\.jpg/ })).toBeDefined()
  expect(await row.find({ text: /\.\/docs\/b\.webp/ })).toBeDefined()
  const converts = ran.filter(argv => argv.includes('--out'))
  expect(converts).toHaveLength(2)
  expect(converts[0]?.[0]).toBe('sips')
})

test('terminal: 実在しないパスや画像以外の拡張子は何も足さない', async ($, on) => {
  setup($, on, { files: [], tmux: 'x' })
  const row = await mount($, 'terminal', '/tmp/missing.png と /tmp/notes.md を見ました。')
  expect(await row.find({ text: /engine/ })).toBeDefined()
  expect(await row.findAll({ text: /開く|\(800×400\)/ })).toHaveLength(0)
})

test('desktop: 端末以外の面では engine の描画をそのまま通す', async ($, on) => {
  setup($, on, { files: ['/tmp/shot.png'], tmux: 'x' })
  const row = await mount($, 'desktop', '/tmp/shot.png に保存しました。')
  expect(await row.find({ text: /engine/ })).toBeDefined()
  expect(await row.findAll({ text: /開く|\(800×400\)/ })).toHaveLength(0)
})
