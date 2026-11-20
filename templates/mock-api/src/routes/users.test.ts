import { beforeEach, describe, expect, test } from 'vitest'
import { app } from '../app.js'
import { resetUsers } from './users.js'

const json = (body: unknown) => ({
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
})

describe('users', () => {
  beforeEach(() => resetUsers())

  test('GET /users returns seed list', async () => {
    const res = await app.request('/users')
    expect(res.status).toBe(200)
    expect(await res.json()).toHaveLength(2)
  })

  test('GET /users/1 returns Ada', async () => {
    const res = await app.request('/users/1')
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ id: 1, name: 'Ada' })
  })

  test('GET /users/999 returns 404 with error body', async () => {
    const res = await app.request('/users/999')
    expect(res.status).toBe(404)
    expect(await res.json()).toEqual({ error: 'Utilisateur introuvable' })
  })

  test('GET /users/abc returns 404', async () => {
    const res = await app.request('/users/abc')
    expect(res.status).toBe(404)
  })

  test('POST /users creates user', async () => {
    const res = await app.request('/users', json({ name: 'Grace' }))
    expect(res.status).toBe(201)
    expect(((await res.json()) as { name: string }).name).toBe('Grace')
    const list = await app.request('/users')
    expect(await list.json()).toHaveLength(3)
  })

  test('POST /users without name returns 400', async () => {
    const res = await app.request('/users', json({}))
    expect(res.status).toBe(400)
    expect(await res.json()).toEqual({ error: 'Le champ name est requis' })
  })

  test('POST /users with invalid JSON returns 400', async () => {
    const res = await app.request('/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{nope',
    })
    expect(res.status).toBe(400)
    expect(await res.json()).toEqual({ error: 'JSON invalide' })
  })

  test('DELETE /users/1 returns 204 then 404 on second delete', async () => {
    const first = await app.request('/users/1', { method: 'DELETE' })
    expect(first.status).toBe(204)
    const second = await app.request('/users/1', { method: 'DELETE' })
    expect(second.status).toBe(404)
  })

  test('delay query param waits', async () => {
    const start = Date.now()
    const res = await app.request('/users?delay=50')
    expect(res.status).toBe(200)
    expect(Date.now() - start).toBeGreaterThanOrEqual(45)
  })

  test('invalid delay is ignored', async () => {
    const res = await app.request('/users?delay=abc')
    expect(res.status).toBe(200)
  })
})
