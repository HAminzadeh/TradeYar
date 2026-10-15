import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import AccessPortal from './auth/AccessPortal';
import './design/tradeyar-theme.css';
// TradeYar-SakhtYar-Theme-Kit-v1
import './style.css';
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><AccessPortal><App /></AccessPortal></React.StrictMode>);
