import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { delayFromQuery } from './helpers.js'
import { users } from './routes/users.js'

export const app = new Hono()

app.use(logger())
app.use(cors())
app.use(delayFromQuery)

app.get('/', (c) => c.json({ status: 'ok' }))
app.route('/users', users)
