import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const dir = '/Users/me/.claude/screen-context'
const pricing = {
  id: '7f3a2c',
  takenAt: 1_791_230_275_970,
  app: 'Safari',
  window: 'Pricing · Linear',
  screenshot: `${dir}/7f3a2c.png`,
  text: 'Free\nPro\n[button] Upgrade',
  session: 'this-session',
}

/** How a message the person typed reaches the mod. */
const typed = { wait: false, origin: { kind: 'composer' } } as const

/** This session, with a capture folder in memory beneath the mod. */
function session(on: On, files: Record<string, string>, me = { id: 'this-session' }) {
  mock.env(on, { HOME: '/Users/me' })
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.id', () => ({ value: me.id }))
  on('fs.list', ($, e) => ({
    value: Object.keys(files)
      .filter(path => path.startsWith(`${e.path}/`))
      .map(path => ({ name: path.slice(e.path.length + 1), kind: 'file' as const, size: 0, mtimeMs: 0, isLink: false })),
  }))
  on('fs.read', ($, e) => {
    const text = files[e.path]
    if (text === undefined) throw new Error(`no such file: ${e.path}`)
    return { value: text }
  })
  on('fs.write', ($, e) => {
    files[e.path] = e.text
    return { value: undefined }
  })
}

/** Sends a message; answers the hidden context that reached Claude beside it. */
function sent(on: On) {
  const contexts: (readonly string[])[] = []
  on('prompt.submit', ($, e) => {
    contexts.push(e.context ?? [])
    return { text: e.text, context: e.context }
  })
  return contexts
}

/** The bar above the prompt, as the desktop app draws it. */
const abovePrompt = {
  plugin: 'screen-context',
  surface: 'desktop',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 80, scroll: { offset: 0, bodyRows: 10 }, view: {} },
} as const

test('a capture sent to this session goes along with the next message', async ($, on) => {
  session(on, { [`${dir}/7f3a2c.json`]: JSON.stringify(pricing) })
  const contexts = sent(on)
  await $.prompt.submit({ text: 'which plan should I pick?', ...typed })
  expect(contexts[0]).toHaveLength(1)
  expect(contexts[0]?.[0]).toContain('Safari')
  expect(contexts[0]?.[0]).toContain(`${dir}/7f3a2c.png`)
  expect(contexts[0]?.[0]).toContain('Free\nPro\n[button] Upgrade')
})

test('a capture named in the message goes along with it', async ($, on) => {
  session(on, { [`${dir}/7f3a2c.json`]: JSON.stringify({ ...pricing, session: undefined }) })
  const contexts = sent(on)
  await $.prompt.submit({ text: '📸 Safari — "Pricing · Linear" (capture 7f3a2c)\nwhich plan should I pick?', ...typed })
  expect(contexts[0]).toHaveLength(1)
  expect(contexts[0]?.[0]).toContain('Free\nPro\n[button] Upgrade')
})

test('a capture goes out only once', async ($, on) => {
  session(on, { [`${dir}/7f3a2c.json`]: JSON.stringify(pricing) })
  const contexts = sent(on)
  await $.prompt.submit({ text: 'which plan should I pick?', ...typed })
  await $.prompt.submit({ text: 'and for a team of 5?', ...typed })
  expect(contexts[1]).toEqual([])
})

test('a capture removed from the bar stays behind', async ($, on) => {
  session(on, { [`${dir}/7f3a2c.json`]: JSON.stringify(pricing) })
  const clock = mock.clock(on)
  const contexts = sent(on)
  await $.session.start({ cwd: '/Users/me', surface: 'desktop', isInteractive: true })
  await clock.advance(1_000)
  const bar = await $.ui.mount(abovePrompt)
  expect(await bar.find({ text: 'Pricing · Linear' })).toBeDefined()
  await bar.press({ key: 'remove-7f3a2c' })
  await $.prompt.submit({ text: 'which plan should I pick?', ...typed })
  expect(contexts[0]).toEqual([])
})

test("a background task's notification leaves the capture for the person's next message", async ($, on) => {
  session(on, { [`${dir}/7f3a2c.json`]: JSON.stringify(pricing) })
  const contexts = sent(on)
  await $.prompt.submit({ text: 'Task "build" finished', wait: false, origin: { kind: 'task-notification' } })
  await $.prompt.submit({ text: 'which plan should I pick?', ...typed })
  expect(contexts[0]).toEqual([])
  expect(contexts[1]).toHaveLength(1)
})

test("a message that doesn't go out leaves its capture for the next one", async ($, on) => {
  session(on, { [`${dir}/7f3a2c.json`]: JSON.stringify(pricing) })
  const contexts: (readonly string[])[] = []
  on('prompt.submit', ($, e) => {
    contexts.push(e.context ?? [])
    return contexts.length === 1 ? { drop: 'a hook stopped it' } : { text: e.text, context: e.context }
  })
  await $.prompt.submit({ text: 'which plan should I pick?', ...typed })
  await $.prompt.submit({ text: 'which plan should I pick?', ...typed })
  expect(contexts[1]).toHaveLength(1)
})

test('after /clear the bar lists the captures sent to the session that goes on', async ($, on) => {
  const me = { id: 'this-session' }
  session(on, { [`${dir}/7f3a2c.json`]: JSON.stringify({ ...pricing, session: 'after-clear' }) }, me)
  const clock = mock.clock(on)
  await $.session.start({ cwd: '/Users/me', surface: 'desktop', isInteractive: true })
  me.id = 'after-clear'
  await clock.advance(1_000)
  const bar = await $.ui.mount(abovePrompt)
  expect(await bar.find({ text: 'Pricing · Linear' })).toBeDefined()
})
