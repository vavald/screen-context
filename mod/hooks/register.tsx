import { atom, read, update } from 'claude-code'
import type { EngineInterface, PromptOrigin, Register } from 'claude-code'

import type { PendingCapture } from '../types'

/** What the Helper writes for each Capture (helper/Sources/ScreenContext/Capture.swift). */
type Capture = {
  id: string
  takenAt: number
  app: string
  window: string
  /** Absent when the Helper may not record the screen. */
  screenshot?: string
  /** A small JPEG of the Screenshot, as a data URL. */
  thumbnail?: string
  text: string
  /** The CLI session id of the session the Capture went to. */
  session: string
}

/** Where a message the person typed comes from: the terminal, Remote Control, the desktop app (an SDK host). */
const fromPerson: PromptOrigin['kind'][] = ['composer', 'bridge', 'sdk']

/** The Pending captures this session's bar lists. */
const bar = atom({ plugin: 'screen-context', key: 'bar' } as const, [] as PendingCapture[])

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    let shown = ''
    // The Helper drops Captures for this session into the folder; list them in the bar.
    $.clock.every(1_000, async () => {
      // Asked every time: after a /clear the process goes on under a new session id.
      const me = await $.session.id()
      const mine = (await pendingCaptures($)).filter(capture => capture.session === me)
      const ids = mine.map(capture => capture.id).join()
      if (ids === shown) return
      shown = ids
      await update($, bar, () => mine.map(({ id, app, window, thumbnail }) => ({ id, app, window, thumbnail })))
    })
    return started
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const captures = await read($, bar)
    if (captures.length === 0) return next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    // The terminal has no Svg: it names each capture instead.
    const Svg = e.surface === 'terminal' ? undefined : $.ui.resolve(e).Svg
    return (
      <Box flexDirection="row" flexWrap="wrap" gap={1}>
        {captures.map(capture => {
          const name = capture.window ? `${capture.app} — ${capture.window}` : capture.app
          return (
            // Keyed, so hovering the thumbnail brings its × in.
            <Box key={capture.id}>
              {capture.thumbnail && Svg ? (
                <Svg source={thumbnailSvg(capture.thumbnail)} alt={name} />
              ) : (
                <Text wrap="truncate-end">{name}</Text>
              )}
              {/* Parked above the band, which clips it, and moved onto the top-right corner on hover:
                  the desktop draws a display="none" reveal as a card above the thumbnail instead. */}
              <Box position="absolute" top={-50} right={0} hover={{ top: 0 }}>
                <Button key={`remove-${capture.id}`} label="×" onPress={() => settle($, capture.id, 'removed from the bar')} />
              </Box>
            </Box>
          )
        })}
      </Box>
    )
  })

  on('prompt.submit', async ($, e, next) => {
    if (!fromPerson.includes(e.origin.kind)) return next(e)
    const me = await $.session.id()
    const going = (await pendingCaptures($)).filter(capture => capture.session === me)
    if (going.length === 0) return next(e)
    const result = await next({ ...e, context: [...(e.context ?? []), ...going.map(describe)] })
    // Settled only once the message went out: a hook beneath can still stop it.
    if (!result.drop) for (const capture of going) await settle($, capture.id, `sent in session ${me}`)
    return result
  })
}

async function folder($: EngineInterface) {
  return `${await $.env.get('HOME')}/.claude/screen-context`
}

/** Every Pending capture, whichever session it waits for, oldest first. */
async function pendingCaptures($: EngineInterface): Promise<Capture[]> {
  const dir = await folder($)
  const names = new Set((await $.fs.list(dir).catch(() => [])).map(entry => entry.name))
  const captures: Capture[] = []
  for (const name of names) {
    // `<id>.done` marks a Capture already sent or removed.
    if (!name.endsWith('.json') || names.has(name.replace(/json$/, 'done'))) continue
    try {
      captures.push(JSON.parse(String(await $.fs.read(`${dir}/${name}`))))
    } catch {}
  }
  return captures.sort((a, b) => a.takenAt - b.takenAt)
}

/** Marks a Capture as dealt with, so neither the bar nor a later message picks it up again. */
async function settle($: EngineInterface, id: string, how: string) {
  await $.fs.write(`${await folder($)}/${id}.done`, how).catch(() => undefined)
  await update($, bar, captures => captures.filter(capture => capture.id !== id))
}

/** The Screenshot's thumbnail inside an SVG: the desktop draws no raster image for a mod. */
function thumbnailSvg(dataUrl: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="80" viewBox="0 0 128 80"><clipPath id="c"><rect width="128" height="80" rx="6"/></clipPath><image href="${dataUrl}" width="128" height="80" preserveAspectRatio="xMidYMid slice" clip-path="url(#c)"/></svg>`
}

function describe(capture: Capture): string {
  const where = capture.window ? `${capture.app}, window "${capture.window}"` : capture.app
  return [
    `The user captured their screen while in ${where}.`,
    capture.screenshot
      ? `Screenshot of the whole display: ${capture.screenshot}. Open it with the Read tool before answering.`
      : 'No screenshot was taken.',
    capture.text
      ? `The window's text, read through macOS accessibility (it can include parts scrolled out of view):\n<screen-text>\n${capture.text}\n</screen-text>`
      : 'No text could be read from the window.',
  ].join('\n')
}
