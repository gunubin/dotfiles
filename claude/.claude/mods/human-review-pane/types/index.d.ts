export type ChunkStatus = 'done' | 'current' | 'todo'

export type ChunkEntry = { n: number; kind: string; label: string; status: ChunkStatus }

export type CodeRef = { path: string; startLine: number; source: string; note?: string }

export type ReviewComment = { chunk: number; location: string; text: string }

export type DiffMode = 'unified' | 'split'

export type ReviewPhase = 'map' | 'chunk' | 'summary' | 'finished'

export type ReviewView = {
  title: string
  phase: ReviewPhase
  chunks: ChunkEntry[]
  current: number
  path: string
  diff: string
  refs: CodeRef[]
  comments: ReviewComment[]
}

declare module 'claude-code' {
  interface PluginState {
    'human-review-pane': { view: ReviewView | null; isBandHidden: boolean; diffMode: DiffMode }
  }
}
