import type { Register, RenderElement } from 'claude-code'

// 描く画像の最大の大きさ（セル単位）。縦横比はこの枠に収まるよう保つ
const MAX_COLUMNS = 60
const MAX_ROWS = 20
// 1 セルは幅 1 に対して高さ 2 とみなす（一般的な等幅フォントの比率）
const CELL_HEIGHT_PER_WIDTH = 2
// 1 つの返答で扱う画像の上限
const MAX_IMAGES = 4
// 端末が読むのは PNG だけなので、他の形式とこの大きさを超える PNG は縮小した PNG に変換する
const DIRECT_PNG_MAX_BYTES = 3 * 1024 * 1024
const CONVERTED_MAX_PIXELS = 1600
const CACHE_DIR_NAME = '.cache/claude-image-inline'
// ポップアップは画像の枠の外側に、左右 2 セルと上下の見出し・案内の行を足す
const POPUP_EXTRA_COLUMNS = 4
const POPUP_EXTRA_ROWS = 6

// 拡張子で終わるパスらしい文字列。括弧・引用符・空白で切れ、末尾の句読点は拾わない
const PATH_PATTERN = /(?:file:\/\/)?((?:(?:~|\.{1,2})?\/)?[^\s'"`()<>\[\]{}:]+\.(?:png|jpe?g|gif|webp))(?![\w.])/gi

type Picture = { file: string; width: number; height: number; generation: number; id: number }

// パス + 更新時刻ごとの結果。変換は一度だけ行い、描き直しのたびに sips を走らせない
const pictures = new Map<string, Promise<Picture | undefined>>()
let isCacheDirReady = false

const hashOf = (text: string) => {
  let hash = 5381
  for (let i = 0; i < text.length; i++) {
    hash = ((hash << 5) + hash + text.charCodeAt(i)) >>> 0
  }

  return hash
}

const extractPaths = (text: string): string[] => {
  const found: string[] = []
  for (const match of text.matchAll(PATH_PATTERN)) {
    const path = match[1]
    if (path !== undefined && !found.includes(path)) {
      found.push(path)
    }
  }

  return found
}

const resolvePath = (path: string, home: string, cwd: string) => {
  if (path.startsWith('~/')) {
    return `${home}${path.slice(1)}`
  }
  if (path.startsWith('/')) {
    return path
  }

  return `${cwd}/${path.replace(/^\.\//, '')}`
}

// 枠に収まり、かつ縦横比を保つセル数。画像は枠いっぱいに引き伸ばされるので枠の方を画像に合わせる
const fitCells = (width: number, height: number, maxColumns: number) => {
  const aspect = width / height
  let columns = maxColumns
  let rows = Math.round(columns / (aspect * CELL_HEIGHT_PER_WIDTH))
  if (rows > MAX_ROWS) {
    rows = MAX_ROWS
    columns = Math.round(rows * aspect * CELL_HEIGHT_PER_WIDTH)
  }

  return { columns: Math.max(1, Math.min(64, columns)), rows: Math.max(1, Math.min(64, rows)) }
}

const shellQuote = (text: string) => `'${text.replaceAll("'", `'\\''`)}'`

export const register: Register = on => {
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || e.props.isSummary === true) {
      return next(e)
    }
    const paths = extractPaths(e.props.text).slice(0, MAX_IMAGES)
    if (paths.length === 0) {
      return next(e)
    }

    const [home, cwd, tmux] = await Promise.all([$.env.get('HOME'), $.session.cwd(), $.env.get('TMUX')])
    if (home === undefined) {
      return next(e)
    }
    const cacheDir = `${home}/${CACHE_DIR_NAME}`
    // tmux は画像を知らないので、本文に貼った画像は画面が流れても元の座標に居座る。
    // tmux の中では本文に描かず、ボタンで tmux のポップアップに開く
    const isInTmux = tmux !== undefined && tmux !== ''

    const load = async (path: string): Promise<Picture | undefined> => {
      const absolute = resolvePath(path, home, cwd)
      const stat = await $.fs.stat(absolute).catch(() => undefined)
      if (stat === undefined || stat.kind !== 'file') {
        return undefined
      }
      const key = `${absolute}:${stat.mtimeMs}:${stat.size}`
      let pending = pictures.get(key)
      if (pending === undefined) {
        pending = (async () => {
          const probe = await $.process.run(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', absolute])
          const width = Number(/pixelWidth:\s*(\d+)/.exec(probe.stdout)?.[1])
          const height = Number(/pixelHeight:\s*(\d+)/.exec(probe.stdout)?.[1])
          if (probe.exitCode !== 0 || !(width > 0) || !(height > 0)) {
            return undefined
          }
          // ポップアップで端末に渡す画像 ID（24bit、0 は使えない）
          const id = (hashOf(key) & 0xffffff) || 1
          const generation = Math.floor(stat.mtimeMs)
          const isPng = /\.png$/i.test(absolute)
          if (isPng && stat.size <= DIRECT_PNG_MAX_BYTES) {
            return { file: absolute, width, height, generation, id }
          }
          if (!isCacheDirReady) {
            await $.fs.write(`${cacheDir}/.keep`, '')
            isCacheDirReady = true
          }
          const converted = `${cacheDir}/${hashOf(key).toString(16)}.png`
          if (!(await $.fs.exists(converted))) {
            const result = await $.process.run([
              'sips', '-s', 'format', 'png', '-Z', String(CONVERTED_MAX_PIXELS), absolute, '--out', converted,
            ])
            if (result.exitCode !== 0) {
              return undefined
            }
          }

          return { file: converted, width, height, generation, id }
        })().catch(() => undefined)
        pictures.set(key, pending)
      }

      return pending
    }

    const openPopup = (path: string, picture: Picture, columns: number, rows: number) => {
      const caption = `${path} (${picture.width}×${picture.height})`
      const viewer = [
        'python3', '-I', `${$.plugin.root}/scripts/show-image.py`,
        picture.file, caption, String(columns), String(rows), String(picture.id),
      ].map(shellQuote).join(' ')
      const popup = [
        'tmux', 'display-popup', '-E',
        '-w', String(columns + POPUP_EXTRA_COLUMNS),
        '-h', String(rows + POPUP_EXTRA_ROWS),
        '-T', shellQuote(` ${path} `),
        shellQuote(viewer),
      ].join(' ')
      // display-popup -E はポップアップが閉じるまで戻らないので、run-shell -b で背景に流す
      void $.process.run(['tmux', 'run-shell', '-b', popup]).catch(() => undefined)
    }

    const loaded = await Promise.all(paths.map(async path => ({ path, picture: await load(path) })))
    const shown = loaded.filter((one): one is { path: string; picture: Picture } => one.picture !== undefined)
    const own = await next(e)
    if (shown.length === 0) {
      return own
    }

    const { Box, Text, Image, Button } = $.ui.resolve(e)
    const maxColumns = Math.max(10, Math.min(MAX_COLUMNS, (e.viewport?.columns ?? MAX_COLUMNS + 4) - 4))

    return (
      <Box flexDirection="column">
        {own as RenderElement}
        {shown.map(({ path, picture }) => {
          const { columns, rows } = fitCells(picture.width, picture.height, maxColumns)
          const caption = `${path} (${picture.width}×${picture.height})`

          return isInTmux ? (
            <Box key={path} flexDirection="row" gap={1} marginTop={1}>
              <Button key={`open:${path}`} label="開く" onPress={() => openPopup(path, picture, columns, rows)} />
              <Text dimColor wrap="truncate-end">
                {caption}
              </Text>
            </Box>
          ) : (
            <Box key={path} flexDirection="column" marginTop={1}>
              <Image
                source={{ file: picture.file, format: 'png', generation: picture.generation }}
                columns={columns}
                rows={rows}
                alt={`[画像: ${path}]`}
              />
              <Text dimColor wrap="truncate-end">
                {caption}
              </Text>
            </Box>
          )
        })}
      </Box>
    )
  })
}
