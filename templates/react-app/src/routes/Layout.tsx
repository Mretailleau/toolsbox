import { Link, Outlet } from 'react-router'

export default function Layout() {
  return (
    <div className="mx-auto max-w-3xl p-6">
      <nav className="mb-6 flex gap-4">
        <Link to="/" className="font-medium hover:underline">
          Accueil
        </Link>
        <Link to="/about" className="font-medium hover:underline">
          À propos
        </Link>
      </nav>
      <Outlet />
    </div>
  )
}
