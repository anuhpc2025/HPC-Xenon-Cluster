import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { HashRouter } from "react-router";

createRoot(document.getElementById('root')!).render(
  <StrictMode>
      <HashRouter basename={import.meta.env.BASE_URL}>
          <App />
      </HashRouter>,
  </StrictMode>,
)
