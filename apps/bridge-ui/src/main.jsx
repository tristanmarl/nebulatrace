import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import "./style.css";

const api = "/api";

const ACTIONS = [
  {
    path: "/missions", method: "POST",
    label: "Create Mission",
    service: "mission-api",
    desc: "Writes a row to PostgreSQL, publishes a job message to ActiveMQ — drone-worker picks it up asynchronously",
  },
  {
    path: "/orbit/recommend", method: "GET",
    label: "Get AI Recommendation",
    service: "orbit-ai → mock-llm",
    desc: "Calls the AI service, which calls the LLM and returns an incident investigation suggestion",
  },
  {
    path: "/cargo", method: "GET",
    label: "Fetch Cargo Inventory",
    service: "cargo-api (Java)",
    desc: "Reads the cargo manifest from PostgreSQL via a Java Spring Boot service",
  },
  {
    path: "/credits/authorize", method: "GET",
    label: "Authorize Payment",
    service: "credits-api (Go)",
    desc: "Checks credit balance and authorizes a transaction — backed by a Go service with Redis",
  },
];

const FAULTS = [
  {
    mode: "slow-db",
    label: "Slow Database Queries",
    service: "cargo-api",
    tech: "PostgreSQL",
    desc: "Cargo service queries take 5–10 seconds instead of milliseconds",
  },
  {
    mode: "queue-backlog",
    label: "Message Queue Backlog",
    service: "drone-worker",
    tech: "ActiveMQ",
    desc: "Worker pauses 3 seconds between jobs — queue depth grows and mission processing falls behind",
  },
  {
    mode: "credit-errors",
    label: "Payment Service Errors",
    service: "credits-api",
    tech: "HTTP 500",
    desc: "Credits API fails 70% of authorization requests with an internal server error",
  },
  {
    mode: "wormhole-route",
    label: "Service Mesh Traffic Fault",
    service: "credits-api",
    tech: "Istio · HTTP 503",
    desc: "Istio aborts 50% of traffic to the credits service at the mesh layer — before it reaches the pod",
  },
  {
    mode: "ai-anomaly",
    label: "AI Service Degraded",
    service: "mock-llm",
    tech: "LLM",
    desc: "LLM responds slowly and returns incorrect recommendations",
  },
  {
    mode: "job-failures",
    label: "Job Processing Failures",
    service: "drone-worker",
    tech: "ActiveMQ NACK",
    desc: "Worker crashes on every message — ActiveMQ redelivers endlessly and jobs never complete",
  },
  {
    mode: "mission-errors",
    label: "Mission API Unavailable",
    service: "mission-api",
    tech: "HTTP 503",
    desc: "Mission API rejects all incoming requests — nothing enters the queue",
  },
  {
    mode: "cascade",
    label: "Full Cascade Failure",
    service: "all services",
    tech: "multi-fault",
    desc: "Triggers all faults at once: slow DB, queue crashes, payment errors, mesh faults, AI failures",
  },
];

function App() {
  const [status, setStatus] = useState(null);
  const [result, setResult] = useState(null);
  const [activeMode, setActiveMode] = useState(null);
  const [pending, setPending] = useState(null);
  const [loading, setLoading] = useState(false);

  async function callApi(path, method = "GET") {
    setLoading(true);
    try {
      const res = await fetch(`${api}${path}`, { method });
      const body = await res.json();
      setResult({ path, status: res.status, body });
      return body;
    } finally {
      setLoading(false);
    }
  }

  async function triggerFault(mode) {
    setPending(mode);
    try {
      await callApi(`/entropy/${mode}`, "POST");
      setActiveMode(mode === "reset" ? null : mode);
    } finally {
      setPending(null);
    }
  }

  useEffect(() => {
    fetch(`${api}/status`)
      .then(r => r.json())
      .then(setStatus)
      .catch(() => setStatus({ error: "offline" }));
  }, []);

  const activeFault = FAULTS.find(f => f.mode === activeMode);

  return (
    <main>
      <header className="header">
        <h1>NebulaTrace</h1>
        <p className="subtitle">Kubernetes observability demo — generate traffic, inspect services, inject faults.</p>
        {status && (
          <div className="status-bar">
            <span className="status-dot" />
            <span>System online</span>
            {activeFault && (
              <span className="active-fault-tag">
                Fault active: {activeFault.label}
              </span>
            )}
          </div>
        )}
      </header>

      <section className="section">
        <h2 className="section-title">Generate Traffic</h2>
        <p className="section-desc">Each button calls a real backend service and returns a live JSON response below.</p>
        <div className="action-grid">
          {ACTIONS.map(action => (
            <button
              key={action.path}
              className="action-btn"
              disabled={loading}
              onClick={() => callApi(action.path, action.method)}
              title={action.desc}
            >
              <span className="btn-label">{action.label}</span>
              <span className="btn-service">{action.service}</span>
            </button>
          ))}
        </div>
      </section>

      <section className="section fault-section">
        <h2 className="section-title">Fault Injection</h2>
        <p className="section-desc">
          Inject faults into individual services to generate errors, slow traces, and queue failures in Dynatrace.
          {activeMode && !activeFault && " "}
        </p>
        <div className="fault-grid">
          {FAULTS.map(({ mode, label, service, tech, desc }) => (
            <button
              key={mode}
              className={`fault-btn${activeMode === mode ? " fault-btn--active" : ""}`}
              disabled={pending !== null}
              onClick={() => triggerFault(mode)}
              title={desc}
            >
              <span className="btn-label">{pending === mode ? "Applying…" : label}</span>
              <span className="fault-tags">
                <span className="tag tag--service">{service}</span>
                <span className="tag tag--tech">{tech}</span>
              </span>
            </button>
          ))}
          <button
            className="fault-btn fault-btn--reset"
            disabled={pending !== null || activeMode === null}
            onClick={() => triggerFault("reset")}
          >
            <span className="btn-label">{pending === "reset" ? "Resetting…" : "Reset All Faults"}</span>
            <span className="fault-tags">
              <span className="tag tag--reset">all services</span>
            </span>
          </button>
        </div>
      </section>

      {result && (
        <section className="section">
          <h2 className="section-title">
            API Response
            <span className={`status-code ${result.status >= 400 ? "status-code--error" : "status-code--ok"}`}>
              {result.status}
            </span>
          </h2>
          <p className="section-desc">{result.path}</p>
          <pre className="response-pre">{JSON.stringify(result.body, null, 2)}</pre>
        </section>
      )}
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);
