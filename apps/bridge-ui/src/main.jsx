import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import "./style.css";

const api = "/api";

const ENTROPY_SCENARIOS = [
  { mode: "slow-db",        label: "Gravity Well",          desc: "cargo-api slow PostgreSQL query" },
  { mode: "queue-backlog",  label: "Drone Bay Congestion",  desc: "drone-worker sleeps between jobs" },
  { mode: "credit-errors",  label: "Credits Core Failure",  desc: "credits-api returns 500s" },
  { mode: "wormhole-route", label: "Wormhole Route Fault",  desc: "Istio aborts 50% of credits calls" },
  { mode: "ai-anomaly",     label: "ORBIT Anomaly",         desc: "mock-llm slow and unreliable" },
];

function App() {
  const [status, setStatus] = useState({});
  const [result, setResult] = useState("");
  const [active, setActive] = useState(null);
  const [pending, setPending] = useState(null);

  async function call(path, options = {}) {
    const res = await fetch(`${api}${path}`, options);
    const body = await res.json();
    setResult(JSON.stringify(body, null, 2));
    return body;
  }

  async function triggerEntropy(mode) {
    setPending(mode);
    try {
      await call(`/entropy/${mode}`, { method: "POST" });
      setActive(mode === "reset" ? null : mode);
    } finally {
      setPending(null);
    }
  }

  useEffect(() => {
    call("/status").then(setStatus).catch(() => setStatus({ ship: "offline" }));
  }, []);

  return (
    <main>
      <section className="hero">
        <p className="eyebrow">CSS Observable</p>
        <h1>NebulaTrace</h1>
        <p>AI starship incident simulator for Kubernetes, Istio, Dynatrace, and OpenTelemetry.</p>
      </section>

      <section className="controls">
        <button onClick={() => call("/missions", { method: "POST" })}>Launch Mission</button>
        <button onClick={() => call("/orbit/recommend")}>Ask ORBIT</button>
        <button onClick={() => call("/cargo")}>Scan Cargo</button>
        <button onClick={() => call("/credits/authorize")}>Authorize Credits</button>
      </section>

      <section className="panel entropy-panel">
        <h2>
          Entropy Drive
          {active && <span className="entropy-badge">{ENTROPY_SCENARIOS.find(s => s.mode === active)?.label} ACTIVE</span>}
        </h2>
        <div className="entropy-grid">
          {ENTROPY_SCENARIOS.map(({ mode, label, desc }) => (
            <button
              key={mode}
              className={`entropy-btn${active === mode ? " entropy-btn--active" : ""}`}
              disabled={pending !== null}
              onClick={() => triggerEntropy(mode)}
              title={desc}
            >
              {pending === mode ? "…" : label}
            </button>
          ))}
          <button
            className="entropy-btn entropy-btn--reset"
            disabled={pending !== null || active === null}
            onClick={() => triggerEntropy("reset")}
          >
            {pending === "reset" ? "…" : "Reset"}
          </button>
        </div>
      </section>

      <section className="panel">
        <h2>Bridge Status</h2>
        <pre>{JSON.stringify(status, null, 2)}</pre>
      </section>

      <section className="panel">
        <h2>Last Transmission</h2>
        <pre>{result || "Awaiting mission command..."}</pre>
      </section>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);
