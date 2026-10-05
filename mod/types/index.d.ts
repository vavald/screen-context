/** A Capture waiting to go out with this session's next message, as its bar lists it. */
export type PendingCapture = { id: string; app: string; window: string }

declare module 'claude-code' {
  interface PluginState {
    'screen-context': { bar: PendingCapture[] }
  }
}
