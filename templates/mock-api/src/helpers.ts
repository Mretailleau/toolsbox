import type { Context, MiddlewareHandler } from 'hono'
import type { ContentfulStatusCode } from 'hono/utils/http-status'

export const MAX_DELAY_MS = 10_000

export const delay = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms))

export const fail = (c: Context, status: ContentfulStatusCode, message: string) =>
  c.json({ error: message }, status)

// Simule une API lente : ?delay=500 attend 500 ms (plafonné à MAX_DELAY_MS).
export const delayFromQuery: MiddlewareHandler = async (c, next) => {
  const raw = c.req.query('delay')
  if (raw !== undefined && /^\d+$/.test(raw)) {
    await delay(Math.min(Number(raw), MAX_DELAY_MS))
  }
  await next()
}
