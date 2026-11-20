import { createBrowserRouter } from 'react-router'
import About from './routes/About.tsx'
import Home from './routes/Home.tsx'
import Layout from './routes/Layout.tsx'

export const router = createBrowserRouter([
  {
    path: '/',
    element: <Layout />,
    children: [
      { index: true, element: <Home /> },
      { path: 'about', element: <About /> },
    ],
  },
])
