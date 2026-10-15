export type TodoWhen = 'now' | 'later'

export type Todo = { id: string; text: string; repo: string; createdAt: string }

declare module 'claude-code' {
  interface PluginState {
    'user-todos': { now: Todo[]; later: Todo[]; isLaterOpen: boolean }
  }
}
