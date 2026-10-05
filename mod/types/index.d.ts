/** A Capture waiting to go out with this session's next message, as its bar lists it. */
export type PendingCapture = {
  id: string
  app: string
  window: string
  /** A small JPEG of the Screenshot, as a data URL; absent without one. */
  thumbnail?: string
}

declare module 'claude-code' {
  interface PluginState {
    'screen-context': { bar: PendingCapture[] }
  }
}
