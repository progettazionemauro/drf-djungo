(function () {
  const API_BASE = (window.API_BASE || "http://127.0.0.1:8000/api").replace(/\/+$/, "");
  const EVENTS_URL = `${API_BASE}/events/`;
  const FILMS_URL  = `${API_BASE}/films/`;

  const listEl = document.getElementById("films-list"); // metti questo UL dove vuoi vedere i film

  async function fetchAndRender() {
    if (!listEl) return;
    try {
      const res = await fetch(FILMS_URL, { headers: { "Accept": "application/json" } });
      if (!res.ok) return;
      const data = await res.json();
      listEl.innerHTML = data.map(f => `<li>[${f.id}] ${escapeHtml(f.title || f.name || "Untitled")}</li>`).join("");
    } catch (e) {
      console.error("fetch films failed:", e);
    }
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"
    }[c]));
  }

  // primo popolamento
  fetchAndRender();

  // EventSource (SSE): ascolta le variazioni inviate da Django
  try {
    const es = new EventSource(EVENTS_URL);
    es.addEventListener("open", () => console.debug("SSE connected"));
    es.addEventListener("error", (e) => console.warn("SSE error:", e));
    es.addEventListener("films-changed", () => fetchAndRender());
  } catch (e) {
    console.error("EventSource unsupported or failed:", e);
  }
})();
