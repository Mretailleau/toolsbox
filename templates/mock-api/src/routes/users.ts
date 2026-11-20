import { Hono } from 'hono'
import { fail } from '../helpers.js'

type User = { id: number; name: string }

const seed = (): User[] => [
  { id: 1, name: 'Ada' },
  { id: 2, name: 'Linus' },
]

let items: User[] = seed()
let nextId = 3

export const resetUsers = (): void => {
  items = seed()
  nextId = 3
}

const NOT_FOUND = 'Utilisateur introuvable'

export const users = new Hono()

users.get('/', (c) => c.json(items))

users.get('/:id', (c) => {
  const user = items.find((u) => u.id === Number(c.req.param('id')))
  return user ? c.json(user) : fail(c, 404, NOT_FOUND)
})

users.post('/', async (c) => {
  let body: unknown
  try {
    body = await c.req.json()
  } catch {
    return fail(c, 400, 'JSON invalide')
  }
  const name = (body as { name?: unknown } | null)?.name
  if (typeof name !== 'string' || name.trim() === '') {
    return fail(c, 400, 'Le champ name est requis')
  }
  const user: User = { id: nextId++, name }
  items = [...items, user]
  return c.json(user, 201)
})

users.delete('/:id', (c) => {
  const id = Number(c.req.param('id'))
  if (!items.some((u) => u.id === id)) return fail(c, 404, NOT_FOUND)
  items = items.filter((u) => u.id !== id)
  return c.body(null, 204)
})
