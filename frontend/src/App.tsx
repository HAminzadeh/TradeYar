import React, { useEffect, useState } from "react";

export default function App() {
  const [status, setStatus] = useState("Connecting...");

  useEffect(() => {
    fetch("/api/health")
      .then(r => r.json())
      .then(data => setStatus(data.status))
      .catch(() => setStatus("Backend offline"));
  }, []);

  return (
    <div className="app">
      <aside className="sidebar">
        <h2>TradeYar</h2>
        <nav>
          {[
            "Dashboard",
            "Trading Workspace",
            "Strategies",
            "Signals",
            "Backtesting",
            "News & AI",
            "Learning Center",
            "Portfolio & Risk",
            "MetaTrader",
            "Settings"
          ].map(page => <p key={page}>{page}</p>)}
        </nav>
      </aside>

      <main>
        <header>
          <h1>TradeYar Trading Workstation</h1>
          <span>Backend: {status}</span>
        </header>

        <section className="cards">
          <article>
            <h3>Market Data</h3>
            <p>Provider not connected</p>
          </article>
          <article>
            <h3>MetaTrader 5</h3>
            <p>Disconnected</p>
          </article>
          <article>
            <h3>Strategies</h3>
            <p>20 planned strategies</p>
          </article>
          <article>
            <h3>Execution</h3>
            <p>Live trading disabled</p>
          </article>
        </section>

        <section className="panel">
          <h2>Professional Trading Workspace</h2>
          <p>Chart and indicator integration pending.</p>
          <p>Java-first trading research environment.</p>
        </section>
      </main>
    </div>
  );
}