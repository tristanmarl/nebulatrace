import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import "./style.css";

const api = "/api";

function App() {
  const [status, setStatus] = useState({});
  const [result, setResult] = useState("");

  async function call(path, options = {}) {
    const res = await fetch(`${api}${path}`, options);
    const body = await res.json();
    setResult(JSON.stringify(body, null, 2));
    return body;
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
