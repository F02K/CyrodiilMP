let state = null;
let selectedMode = "research";
let selectedRunId = null;
let selectedDumpId = null;
let selectedFile = "report.md";

const researchTabs = [
  { name: "report.md", label: "Report" },
  { name: "packages.csv", label: "Packages" },
  { name: "legacy-data.csv", label: "Legacy Data" },
  { name: "executables-and-dlls.csv", label: "Binaries" },
  { name: "ini-summary.csv", label: "INI" },
  { name: "largest-files.csv", label: "Largest" },
  { name: "layout.csv", label: "Layout" }
];

const runtimePreferredOrder = [
  "menu-analysis.md",
  "main-menu-wrappers.csv",
  "menu-candidates.csv",
  "menu-analysis.json",
  "generated-main-menu-targets.lua",
  "summary.md",
  "collection-report.md"
];

const projectRoot = document.querySelector("#project-root");
const gamePathInput = document.querySelector("#game-path");
const runsEl = document.querySelector("#runs");
const runtimeDumpsEl = document.querySelector("#runtime-dumps");
const tabsEl = document.querySelector("#tabs");
const viewer = document.querySelector("#viewer");
const jobStatus = document.querySelector("#job-status");
const jobLog = document.querySelector("#job-log");
const runFullButton = document.querySelector("#run-full-button");
const refreshButton = document.querySelector("#refresh-button");
const analyzeRuntimeButton = document.querySelector("#analyze-runtime-button");

refreshButton.addEventListener("click", () => refresh());
runFullButton.addEventListener("click", () => runFullResearch());
analyzeRuntimeButton.addEventListener("click", () => analyzeSelectedRuntimeDump());

async function refresh() {
  const response = await fetch("/api/state");
  state = await response.json();
  projectRoot.textContent = state.projectRoot;
  gamePathInput.value = state.gamePath || "";
  renderJob(state.job);
  renderRuns(state.runs || []);
  renderRuntimeDumps(state.runtimeDumps || []);

  if (!selectedRunId && !selectedDumpId && state.latestRun) {
    await selectRun(state.latestRun.id);
  } else if (!selectedRunId && !selectedDumpId && state.latestRuntimeDump) {
    await selectRuntimeDump(state.latestRuntimeDump.id);
  }
}

function renderRuns(runs) {
  runsEl.innerHTML = "";

  if (runs.length === 0) {
    runsEl.innerHTML = `<div class="empty compact">No full research runs yet.</div>`;
    return;
  }

  for (const run of runs) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `run-item ${selectedMode === "research" && run.id === selectedRunId ? "active" : ""}`;
    button.innerHTML = `
      <span class="run-id">${escapeHtml(run.id)}</span>
      <span class="run-meta">${new Date(run.createdAt).toLocaleString()}</span>
      <span class="run-meta">${run.packageFiles} UE packages / ${run.legacyDataFiles} legacy</span>
    `;
    button.addEventListener("click", () => selectRun(run.id));
    runsEl.appendChild(button);
  }
}

function renderRuntimeDumps(dumps) {
  runtimeDumpsEl.innerHTML = "";
  analyzeRuntimeButton.disabled = selectedMode !== "runtime" || !selectedDumpId;

  if (dumps.length === 0) {
    runtimeDumpsEl.innerHTML = `<div class="empty compact">No runtime dumps collected yet.</div>`;
    return;
  }

  for (const dump of dumps) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `run-item ${selectedMode === "runtime" && dump.id === selectedDumpId ? "active" : ""}`;
    const analysis = dump.hasMenuAnalysis ? "analysis ready" : "needs analysis";
    button.innerHTML = `
      <span class="run-id">${escapeHtml(dump.id)}</span>
      <span class="run-meta">${new Date(dump.createdAt).toLocaleString()}</span>
      <span class="run-meta">${dump.csvFiles} CSV files / ${analysis}</span>
    `;
    button.addEventListener("click", () => selectRuntimeDump(dump.id));
    runtimeDumpsEl.appendChild(button);
  }
}

async function selectRun(runId) {
  selectedMode = "research";
  selectedRunId = runId;
  selectedDumpId = null;
  selectedFile = "report.md";
  renderRuns(state?.runs || []);
  renderRuntimeDumps(state?.runtimeDumps || []);
  renderTabs(researchTabs, selectedFile);

  const response = await fetch(`/api/runs/${encodeURIComponent(runId)}`);
  const run = await response.json();
  document.querySelector("#metric-total").textContent = formatValue(run.summary?.TotalFiles);
  document.querySelector("#metric-packages").textContent = formatValue(run.summary?.PackageFiles);
  document.querySelector("#metric-legacy").textContent = formatValue(run.summary?.LegacyDataFiles);
  await loadRunFile(runId, selectedFile);
}

async function selectRuntimeDump(dumpId) {
  selectedMode = "runtime";
  selectedDumpId = dumpId;
  selectedRunId = null;
  renderRuns(state?.runs || []);
  renderRuntimeDumps(state?.runtimeDumps || []);

  const response = await fetch(`/api/runtime-dumps/${encodeURIComponent(dumpId)}`);
  const dump = await response.json();
  const files = orderRuntimeFiles(dump.files || []);
  selectedFile = dump.preferredReport || files[0]?.name || "";
  renderTabs(files.map((file) => ({ name: file.name, label: file.name })), selectedFile);

  const summary = (state?.runtimeDumps || []).find((item) => item.id === dumpId);
  document.querySelector("#metric-total").textContent = formatValue(summary?.csvFiles);
  document.querySelector("#metric-packages").textContent = summary?.hasMenuAnalysis ? "yes" : "no";
  document.querySelector("#metric-legacy").textContent = summary?.hasSummary ? "yes" : "no";

  if (selectedFile) {
    await loadRuntimeDumpFile(dumpId, selectedFile);
  } else {
    viewer.innerHTML = `<div class="empty">No files in runtime dump.</div>`;
  }
}

function orderRuntimeFiles(files) {
  return [...files].sort((a, b) => {
    const aIndex = runtimePreferredOrder.indexOf(a.name);
    const bIndex = runtimePreferredOrder.indexOf(b.name);
    const aScore = aIndex === -1 ? 1000 : aIndex;
    const bScore = bIndex === -1 ? 1000 : bIndex;
    return aScore - bScore || a.name.localeCompare(b.name);
  });
}

function renderTabs(files, activeFile) {
  tabsEl.innerHTML = "";
  for (const file of files) {
    const button = document.createElement("button");
    button.className = `tab ${file.name === activeFile ? "active" : ""}`;
    button.dataset.file = file.name;
    button.type = "button";
    button.textContent = file.label;
    button.addEventListener("click", async () => {
      selectedFile = file.name;
      renderTabs(files, selectedFile);
      if (selectedMode === "runtime" && selectedDumpId) {
        await loadRuntimeDumpFile(selectedDumpId, selectedFile);
      } else if (selectedRunId) {
        await loadRunFile(selectedRunId, selectedFile);
      }
    });
    tabsEl.appendChild(button);
  }
}

async function loadRunFile(runId, fileName) {
  viewer.innerHTML = `<div class="empty">Loading ${escapeHtml(fileName)}...</div>`;
  const response = await fetch(`/api/runs/${encodeURIComponent(runId)}/files/${encodeURIComponent(fileName)}`);
  await renderFileResponse(response, fileName);
}

async function loadRuntimeDumpFile(dumpId, fileName) {
  viewer.innerHTML = `<div class="empty">Loading ${escapeHtml(fileName)}...</div>`;
  const response = await fetch(`/api/runtime-dumps/${encodeURIComponent(dumpId)}/files/${encodeURIComponent(fileName)}`);
  await renderFileResponse(response, fileName);
}

async function renderFileResponse(response, fileName) {
  if (!response.ok) {
    viewer.innerHTML = `<div class="empty">Could not load ${escapeHtml(fileName)}.</div>`;
    return;
  }

  const text = await response.text();
  if (fileName.endsWith(".csv")) {
    viewer.innerHTML = csvToTable(text);
  } else if (fileName.endsWith(".md")) {
    viewer.innerHTML = markdownToHtml(text);
  } else {
    viewer.innerHTML = `<pre>${escapeHtml(text)}</pre>`;
  }
}

async function analyzeSelectedRuntimeDump() {
  if (!selectedDumpId) return;

  analyzeRuntimeButton.disabled = true;
  viewer.innerHTML = `<div class="empty">Analyzing ${escapeHtml(selectedDumpId)}...</div>`;
  const response = await fetch(`/api/runtime-dumps/${encodeURIComponent(selectedDumpId)}/analyze`, { method: "POST" });
  const result = await response.json();

  if (!response.ok || result.exitCode !== 0) {
    viewer.innerHTML = `<pre>${escapeHtml(result.error || result.output || "Runtime analysis failed.")}</pre>`;
    analyzeRuntimeButton.disabled = false;
    return;
  }

  await refresh();
  await selectRuntimeDump(selectedDumpId);
}

async function runFullResearch() {
  runFullButton.disabled = true;
  const gamePath = gamePathInput.value.trim();
  const response = await fetch("/api/research/full", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ gamePath })
  });

  if (!response.ok) {
    const error = await response.json();
    alert(error.error || "Could not start research.");
    runFullButton.disabled = false;
    return;
  }

  await pollJob();
}

async function pollJob() {
  const response = await fetch("/api/jobs/current");
  const job = await response.json();
  renderJob(job);

  if (job.isRunning) {
    setTimeout(pollJob, 1200);
  } else {
    runFullButton.disabled = false;
    await refresh();
  }
}

function renderJob(job) {
  if (!job) return;
  jobStatus.textContent = job.isRunning ? "Running full research..." : `Status: ${job.status || "idle"}`;
  jobStatus.className = `status ${job.status || "idle"}`;
  jobLog.textContent = (job.log || []).join("\n");
}

function csvToTable(text) {
  const rows = parseCsv(text);
  if (rows.length === 0) {
    return `<div class="empty">No rows.</div>`;
  }

  const [headers, ...data] = rows;
  return `
    <table>
      <thead><tr>${headers.map((header) => `<th>${escapeHtml(header)}</th>`).join("")}</tr></thead>
      <tbody>
        ${data.map((row) => `
          <tr>${headers.map((_, index) => `<td>${escapeHtml(row[index] || "")}</td>`).join("")}</tr>
        `).join("")}
      </tbody>
    </table>
  `;
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let value = "";
  let quoted = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    const next = text[i + 1];

    if (quoted && char === '"' && next === '"') {
      value += '"';
      i++;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (!quoted && char === ",") {
      row.push(value);
      value = "";
    } else if (!quoted && (char === "\n" || char === "\r")) {
      if (char === "\r" && next === "\n") i++;
      row.push(value);
      if (row.some((cell) => cell.length > 0)) rows.push(row);
      row = [];
      value = "";
    } else {
      value += char;
    }
  }

  row.push(value);
  if (row.some((cell) => cell.length > 0)) rows.push(row);
  return rows;
}

function markdownToHtml(text) {
  const lines = text.split(/\r?\n/);
  let html = `<div class="markdown">`;
  let inList = false;

  for (const rawLine of lines) {
    const line = rawLine.trimEnd();
    if (line.startsWith("# ")) {
      if (inList) { html += "</ul>"; inList = false; }
      html += `<h1>${inlineMarkdown(line.slice(2))}</h1>`;
    } else if (line.startsWith("## ")) {
      if (inList) { html += "</ul>"; inList = false; }
      html += `<h2>${inlineMarkdown(line.slice(3))}</h2>`;
    } else if (line.startsWith("- ")) {
      if (!inList) { html += "<ul>"; inList = true; }
      html += `<li>${inlineMarkdown(line.slice(2))}</li>`;
    } else if (line.trim() === "") {
      if (inList) { html += "</ul>"; inList = false; }
    } else {
      if (inList) { html += "</ul>"; inList = false; }
      html += `<p>${inlineMarkdown(line)}</p>`;
    }
  }

  if (inList) html += "</ul>";
  html += "</div>";
  return html;
}

function inlineMarkdown(text) {
  return escapeHtml(text).replace(/`([^`]+)`/g, "<code>$1</code>");
}

function formatValue(value) {
  return Number.isFinite(value) ? value.toLocaleString() : String(value ?? "-");
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

refresh();
setInterval(async () => {
  const response = await fetch("/api/jobs/current");
  renderJob(await response.json());
}, 2500);
