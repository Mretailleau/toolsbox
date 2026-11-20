import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import Home from './Home.tsx'

test('affiche le titre d\'accueil', () => {
  render(
    <MemoryRouter>
      <Home />
    </MemoryRouter>,
  )

  expect(screen.getByRole('heading', { name: /bienvenue/i })).toBeInTheDocument()
})
