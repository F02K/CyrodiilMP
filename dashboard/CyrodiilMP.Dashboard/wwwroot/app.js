const THEME_STORAGE_KEY = "cyrodiilmp-dashboard-theme";

const scopeConfig = {
  inventory: {
    listKey: "inventories",
    label: "Game Inventory",
    detailUrl: (id) => `/api/inventories/${encodeURIComponent(id)}`,
    fileUrl: (id, file) => `/api/inventories/${encodeURIComponent(id)}/files/${encodeURIComponent(file)}`
  },
  run: {
    listKey: "fullResearchRuns",
    label: "Full Research",
    detailUrl: (id) => `/api/runs/${encodeURIComponent(id)}`,
    fileUrl: (id, file) => `/api/runs/${encodeURIComponent(id)}/files/${encodeURIComponent(file)}`
  },
  noteRun: {
    listKey: "noteRuns",
    label: "Research Notes",
    detailUrl: (id) => `/api/note-runs/${encodeURIComponent(id)}`,
    fileUrl: (id, file) => `/api/note-runs/${encodeURIComponent(id)}/files/${encodeURIComponent(file)}`
  },
  runtime: {
    listKey: "runtimeDumps",
    label: "Runtime Dump",
    detailUrl: (id) => `/api/runtime-dumps/${encodeURIComponent(id)}`,
    fileUrl: (id, file) => `/api/runtime-dumps/${encodeURIComponent(id)}/files/${encodeURIComponent(file)}`
  }
};

const state = {
  dashboard: null,
  detail: null,
  theme: readInitialTheme(),
  selection: {
    scope: "",
    id: "",
    file: ""
  },
  refreshInFlight: false,
  lastJobRunning: false,
  flashTimer: 0
};

const els = {
  projectRoot: document.querySelector("#project-root"),
  flashMessage: document.querySelector("#flash-message"),
  themeToggleButton: document.querySelector("#theme-toggle-button"),
  themeToggleValue: document.querySelector("#theme-toggle-value"),
  refreshButton: document.querySelector("#refresh-button"),
  inventoryCount: document.querySelector("#inventory-count"),
  fullResearchCount: document.querySelector("#full-research-count"),
  noteRunCount: document.querySelector("#note-run-count"),
  runtimeDumpCount: document.querySelector("#runtime-dump-count"),
  jobState: document.querySelector("#job-state"),
  serverState: document.querySelector("#server-state"),
  gamePathInput: document.querySelector("#game-path-input"),
  saveGamePathButton: document.querySelector("#save-game-path-button"),
  gamePathFile: document.querySelector("#game-path-file"),
  ue4ssInstallSummary: document.querySelector("#ue4ss-install-summary"),
  ue4ssInstallPath: document.querySelector("#ue4ss-install-path"),
  installUe4ssButton: document.querySelector("#install-ue4ss-button"),
  ue4ssInstallDetails: document.querySelector("#ue4ss-install-details"),
  quickScanButton: document.querySelector("#quick-scan-button"),
  fullResearchButton: document.querySelector("#full-research-button"),
  newRunName: document.querySelector("#new-run-name"),
  createNoteRunButton: document.querySelector("#create-note-run-button"),
  collectDumpName: document.querySelector("#collect-dump-name"),
  collectDumpButton: document.querySelector("#collect-dump-button"),
  analyzeSelectedDumpButton: document.querySelector("#analyze-selected-dump-button"),
  serverPortInput: document.querySelector("#server-port-input"),
  serverStartButton: document.querySelector("#server-start-button"),
  serverStopButton: document.querySelector("#server-stop-button"),
  serverForceStopButton: document.querySelector("#server-force-stop-button"),
  serverSummary: document.querySelector("#server-summary"),
  bridgeHostInput: document.querySelector("#bridge-host-input"),
  bridgePortInput: document.querySelector("#bridge-port-input"),
  bridgeTimeoutInput: document.querySelector("#bridge-timeout-input"),
  bridgeNameInput: document.querySelector("#bridge-name-input"),
  bridgeReasonInput: document.querySelector("#bridge-reason-input"),
  bridgeRunButton: document.querySelector("#bridge-run-button"),
  cancelJobButton: document.querySelector("#cancel-job-button"),
  currentJobSummary: document.querySelector("#current-job-summary"),
  recentJobs: document.querySelector("#recent-jobs"),
  currentJobLog: document.querySelector("#current-job-log"),
  inventoriesList: document.querySelector("#inventories-list"),
  runsList: document.querySelector("#runs-list"),
  noteRunsList: document.querySelector("#note-runs-list"),
  runtimeDumpsList: document.querySelector("#runtime-dumps-list"),
  inventoriesCountBadge: document.querySelector("#inventories-count-badge"),
  fullRunsCountBadge: document.querySelector("#full-runs-count-badge"),
  noteRunsCountBadge: document.querySelector("#note-runs-count-badge"),
  runtimeDumpsCountBadge: document.querySelector("#runtime-dumps-count-badge"),
  viewerTitle: document.querySelector("#viewer-title"),
  viewerMeta: document.querySelector("#viewer-meta"),
  fileTabs: document.querySelector("#file-tabs"),
  viewer: document.querySelector("#viewer"),
  serverLog: document.querySelector("#server-log"),
  selectionSummary: document.querySelector("#selection-summary"),
  selectionFacts: document.querySelector("#selection-facts")
};

els.themeToggleButton?.addEventListener("click", () => toggleTheme());
els.refreshButton.addEventListener("click", () => refreshState({ reloadSelection: true, silent: false }));
els.saveGamePathButton.addEventListener("click", () => saveGamePath());
els.installUe4ssButton.addEventListener("click", () => installUe4ssMods());
els.quickScanButton.addEventListener("click", () => runDashboardAction("/api/actions/quick-scan", {
  gamePath: els.gamePathInput.value.trim()
}, "Quick scan started."));
els.fullResearchButton.addEventListener("click", () => runDashboardAction("/api/actions/full-research", {
  gamePath: els.gamePathInput.value.trim()
}, "Full research started."));
els.createNoteRunButton.addEventListener("click", () => runDashboardAction("/api/actions/new-research-run", {
  name: els.newRunName.value.trim()
}, "Research notes run created."));
els.collectDumpButton.addEventListener("click", () => runDashboardAction("/api/actions/collect-runtime-dumps", {
  gamePath: els.gamePathInput.value.trim(),
  name: els.collectDumpName.value.trim()
}, "Runtime dump collection started."));
els.analyzeSelectedDumpButton.addEventListener("click", () => analyzeSelectedDump());
els.serverStartButton.addEventListener("click", () => startServer());
els.serverStopButton.addEventListener("click", () => stopServer());
els.serverForceStopButton.addEventListener("click", () => forceStopServer());
els.bridgeRunButton.addEventListener("click", () => runBridgeSmoke());
els.cancelJobButton.addEventListener("click", () => cancelCurrentJob());
applyTheme(state.theme, { persist: false });

async function refreshState({ reloadSelection = false, silent = true } = {}) {
  if (state.refreshInFlight) {
    return;
  }

  state.refreshInFlight = true;
  try {
    const dashboard = await fetchJson("/api/state");
    const previousJobRunning = state.lastJobRunning;
    state.dashboard = dashboard;
    state.lastJobRunning = Boolean(dashboard.job?.isRunning);

    renderDashboard();

    if (!selectionExists()) {
      await autoSelectDefault();
      return;
    }

    if (reloadSelection || (previousJobRunning && !state.lastJobRunning)) {
      await loadSelection(state.selection.scope, state.selection.id, {
        preferredFile: state.selection.file,
        silent: true
      });
    }
  } catch (error) {
    if (!silent) {
      showFlash(getErrorMessage(error), "error");
    }
  } finally {
    state.refreshInFlight = false;
  }
}

function readInitialTheme() {
  return document.documentElement.dataset.theme === "light" ? "light" : "dark";
}

function toggleTheme() {
  applyTheme(state.theme === "dark" ? "light" : "dark");
}

function applyTheme(theme, { persist = true } = {}) {
  const nextTheme = theme === "light" ? "light" : "dark";
  const nextLabel = nextTheme === "dark" ? "Dark Mode" : "Light Mode";
  const targetLabel = nextTheme === "dark" ? "light" : "dark";

  state.theme = nextTheme;
  document.documentElement.dataset.theme = nextTheme;

  if (els.themeToggleValue) {
    els.themeToggleValue.textContent = nextLabel;
  }

  if (els.themeToggleButton) {
    els.themeToggleButton.setAttribute("aria-label", `Switch to ${targetLabel} mode`);
    els.themeToggleButton.setAttribute("aria-pressed", String(nextTheme === "dark"));
    els.themeToggleButton.title = `Switch to ${targetLabel} mode`;
  }

  if (!persist) {
    return;
  }

  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
  } catch {
    // Ignore storage failures and keep the in-memory theme active.
  }
}

function renderDashboard() {
  const dashboard = state.dashboard;
  if (!dashboard) {
    return;
  }

  els.projectRoot.textContent = dashboard.projectRoot || "";
  syncInputValue(els.gamePathInput, dashboard.gamePath || "");
  syncInputValue(els.serverPortInput, String(dashboard.server?.port ?? 27015));
  els.gamePathFile.textContent = `${dashboard.projectRoot}\\game-path.txt`;

  els.inventoryCount.textContent = formatNumber(dashboard.summary?.inventoryCount);
  els.fullResearchCount.textContent = formatNumber(dashboard.summary?.fullResearchCount);
  els.noteRunCount.textContent = formatNumber(dashboard.summary?.noteRunCount);
  els.runtimeDumpCount.textContent = formatNumber(dashboard.summary?.runtimeDumpCount);

  const activeOrLatestJob = dashboard.job?.activeJob || dashboard.job?.recentJobs?.[0] || null;
  els.jobState.textContent = humanizeLabel(activeOrLatestJob?.status || "idle");
  els.serverState.textContent = humanizeLabel(dashboard.server?.status || "stopped");

  els.inventoriesCountBadge.textContent = String(dashboard.inventories?.length || 0);
  els.fullRunsCountBadge.textContent = String(dashboard.fullResearchRuns?.length || 0);
  els.noteRunsCountBadge.textContent = String(dashboard.noteRuns?.length || 0);
  els.runtimeDumpsCountBadge.textContent = String(dashboard.runtimeDumps?.length || 0);

  renderArtifactList("inventory", dashboard.inventories || [], els.inventoriesList);
  renderArtifactList("run", dashboard.fullResearchRuns || [], els.runsList);
  renderArtifactList("noteRun", dashboard.noteRuns || [], els.noteRunsList);
  renderArtifactList("runtime", dashboard.runtimeDumps || [], els.runtimeDumpsList);
  renderUe4ssInstallPanel();
  renderJobPanel();
  renderServerPanel();
  updateActionButtons();
}

function renderUe4ssInstallPanel() {
  const install = state.dashboard?.ue4ssInstall;
  if (!install) {
    return;
  }

  els.ue4ssInstallSummary.textContent = `${install.statusText || "Unknown"} | ${humanizeLabel(install.status || "unknown")}`;
  els.ue4ssInstallPath.textContent = install.modsPath || "Game path not configured yet";
  els.ue4ssInstallDetails.innerHTML = "";

  for (const detail of install.details || []) {
    const item = document.createElement("div");
    item.className = `check-list__item ${detail.ok ? "check-list__item--ok" : "check-list__item--missing"}`;
    item.innerHTML = `
      <strong>${escapeHtml(detail.name || "Item")}</strong>
      <span>${escapeHtml(detail.value || "")}</span>
    `;
    els.ue4ssInstallDetails.appendChild(item);
  }
}

function renderArtifactList(scope, items, container) {
  container.innerHTML = "";

  if (!items.length) {
    container.innerHTML = `<div class="artifact-empty">Nothing generated yet.</div>`;
    return;
  }

  for (const item of items) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `artifact-item ${state.selection.scope === scope && state.selection.id === item.id ? "artifact-item--active" : ""}`;
    button.innerHTML = `
      <strong>${escapeHtml(item.id)}</strong>
      <span>${escapeHtml(describeArtifact(scope, item))}</span>
    `;
    button.addEventListener("click", () => loadSelection(scope, item.id, { silent: false }));
    container.appendChild(button);
  }
}

function renderJobPanel() {
  const jobState = state.dashboard?.job;
  const current = jobState?.activeJob || jobState?.recentJobs?.[0] || null;

  if (!current) {
    els.currentJobSummary.textContent = "No job has run yet.";
    els.currentJobLog.textContent = "No logs yet.";
    els.recentJobs.innerHTML = "";
    return;
  }

  const summaryBits = [
    current.label || current.scriptName || "Dashboard job",
    humanizeLabel(current.status || "unknown"),
    current.startedAt ? `Started ${formatDateTime(current.startedAt)}` : ""
  ].filter(Boolean);

  if (current.finishedAt) {
    summaryBits.push(`Finished ${formatDateTime(current.finishedAt)}`);
  }
  if (Number.isFinite(current.exitCode)) {
    summaryBits.push(`Exit ${current.exitCode}`);
  }

  els.currentJobSummary.textContent = summaryBits.join(" | ");
  els.currentJobLog.textContent = (current.log || []).join("\n") || "No logs yet.";
  els.recentJobs.innerHTML = "";

  for (const job of jobState?.recentJobs || []) {
    const chip = document.createElement("span");
    chip.className = `pill pill--${statusTone(job.status)}`;
    chip.textContent = `${job.label}: ${humanizeLabel(job.status)}`;
    els.recentJobs.appendChild(chip);
  }
}

function renderServerPanel() {
  const server = state.dashboard?.server;
  if (!server) {
    return;
  }

  const bits = [
    humanizeLabel(server.status || "stopped"),
    server.processId ? `PID ${server.processId}` : "",
    server.port ? `Port ${server.port}` : "",
    server.lingeringCount > 0 ? `${server.lingeringCount} lingering` : ""
  ].filter(Boolean);
  els.serverSummary.textContent = bits.join(" | ") || "Server helper is not running.";
  els.serverLog.textContent = (server.log || []).join("\n") || "Server log will appear here after the helper starts.";
}

function updateActionButtons() {
  const jobRunning = Boolean(state.dashboard?.job?.isRunning);
  const serverRunning = Boolean(state.dashboard?.server?.running);
  const lingeringServers = Number(state.dashboard?.server?.lingeringCount || 0);
  const installReady = Boolean(state.dashboard?.ue4ssInstall?.readyToInstall);

  els.saveGamePathButton.disabled = jobRunning;
  els.installUe4ssButton.disabled = jobRunning || !installReady;
  els.quickScanButton.disabled = jobRunning;
  els.fullResearchButton.disabled = jobRunning;
  els.createNoteRunButton.disabled = jobRunning;
  els.collectDumpButton.disabled = jobRunning;
  els.bridgeRunButton.disabled = jobRunning;
  els.cancelJobButton.disabled = !jobRunning;
  els.analyzeSelectedDumpButton.disabled = jobRunning || state.selection.scope !== "runtime";
  els.serverStartButton.disabled = serverRunning;
  els.serverStopButton.disabled = !serverRunning;
  els.serverForceStopButton.disabled = jobRunning || (!serverRunning && lingeringServers === 0);
}

async function autoSelectDefault() {
  const dashboard = state.dashboard;
  if (!dashboard) {
    return;
  }

  const candidate =
    dashboard.latestRuntimeDump ? ["runtime", dashboard.latestRuntimeDump.id] :
    dashboard.latestRun ? ["run", dashboard.latestRun.id] :
    dashboard.latestInventory ? ["inventory", dashboard.latestInventory.id] :
    dashboard.latestNoteRun ? ["noteRun", dashboard.latestNoteRun.id] :
    null;

  if (!candidate) {
    clearViewer();
    return;
  }

  await loadSelection(candidate[0], candidate[1], { silent: true });
}

async function loadSelection(scope, id, { preferredFile = "", silent = false } = {}) {
  const config = scopeConfig[scope];
  if (!config) {
    return;
  }

  try {
    const detail = await fetchJson(config.detailUrl(id));
    state.selection.scope = scope;
    state.selection.id = id;
    state.selection.file = preferredFile || detail.preferredFile || detail.files?.[0]?.name || "";
    state.detail = detail;

    renderDashboard();
    renderViewerHeader(scope, id, detail);
    renderFileTabs(detail.files || []);
    renderSelectionFacts(scope, id, detail);

    if (state.selection.file) {
      await loadSelectedFile(state.selection.file);
    } else {
      els.viewer.innerHTML = `<div class="empty-state"><strong>No files available.</strong><p>This artifact does not expose any dashboard-readable files yet.</p></div>`;
    }
  } catch (error) {
    if (!silent) {
      showFlash(getErrorMessage(error), "error");
    }
  }
}

function renderViewerHeader(scope, id, detail) {
  els.viewerTitle.textContent = `${scopeConfig[scope].label}: ${id}`;
  els.viewerMeta.textContent = detail.path || "Generated artifact";
}

function renderFileTabs(files) {
  els.fileTabs.innerHTML = "";

  if (!files.length) {
    return;
  }

  for (const file of files) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `tab ${file.name === state.selection.file ? "tab--active" : ""}`;
    button.textContent = file.name;
    button.addEventListener("click", () => {
      state.selection.file = file.name;
      renderFileTabs(files);
      loadSelectedFile(file.name);
    });
    els.fileTabs.appendChild(button);
  }
}

async function loadSelectedFile(fileName) {
  const config = scopeConfig[state.selection.scope];
  if (!config) {
    return;
  }

  els.viewer.innerHTML = `<div class="empty-state"><strong>Loading ${escapeHtml(fileName)}...</strong><p>Pulling the selected artifact file from the dashboard API.</p></div>`;

  try {
    const response = await fetch(config.fileUrl(state.selection.id, fileName));
    if (!response.ok) {
      throw await readError(response);
    }

    const text = await response.text();
    state.selection.file = fileName;
    renderFileTabs(state.detail?.files || []);
    renderFileContent(fileName, text);
  } catch (error) {
    els.viewer.innerHTML = `<div class="empty-state"><strong>Could not load ${escapeHtml(fileName)}.</strong><p>${escapeHtml(getErrorMessage(error))}</p></div>`;
  }
}

function renderFileContent(fileName, text) {
  if (fileName.endsWith(".csv")) {
    els.viewer.innerHTML = csvToTable(text);
    return;
  }

  if (fileName.endsWith(".md")) {
    els.viewer.innerHTML = markdownToHtml(text);
    return;
  }

  if (fileName.endsWith(".json")) {
    try {
      const parsed = JSON.parse(text);
      els.viewer.innerHTML = `<pre>${escapeHtml(JSON.stringify(parsed, null, 2))}</pre>`;
      return;
    } catch {
      els.viewer.innerHTML = `<pre>${escapeHtml(text)}</pre>`;
      return;
    }
  }

  els.viewer.innerHTML = `<pre>${escapeHtml(text)}</pre>`;
}

function renderSelectionFacts(scope, id, detail) {
  const item = getSelectedArtifact();
  const facts = [
    ["Scope", scopeConfig[scope]?.label || scope],
    ["Identifier", id],
    ["Path", detail.path || "Unknown"],
    ["Files", String(detail.files?.length || 0)]
  ];

  if (scope === "inventory") {
    facts.push(["Game path", item?.gamePath || detail.summary?.GamePath || "Unknown"]);
    facts.push(["Indexed files", formatNumber(item?.fileCount || detail.summary?.FileCount)]);
  } else if (scope === "run") {
    facts.push(["Game path", item?.gamePath || detail.summary?.GamePath || "Unknown"]);
    facts.push(["Total files", formatNumber(item?.totalFiles || detail.summary?.TotalFiles)]);
    facts.push(["UE packages", formatNumber(item?.packageFiles || detail.summary?.PackageFiles)]);
    facts.push(["Legacy data", formatNumber(item?.legacyDataFiles || detail.summary?.LegacyDataFiles)]);
  } else if (scope === "noteRun") {
    facts.push(["Has notes", item?.hasNotes ? "Yes" : "No"]);
    facts.push(["Has status", item?.hasStatus ? "Yes" : "No"]);
    facts.push(["Top-level files", formatNumber(item?.fileCount)]);
  } else if (scope === "runtime") {
    facts.push(["CSV files", formatNumber(item?.csvFiles)]);
    facts.push(["Menu analysis", item?.hasMenuAnalysis ? "Ready" : "Not generated"]);
    facts.push(["Summary report", item?.hasSummary ? "Ready" : "Missing"]);
  }

  if (item?.createdAt) {
    facts.push(["Created", formatDateTime(item.createdAt)]);
  }

  els.selectionSummary.textContent = `Selected file: ${state.selection.file || "None"} | Updated ${item?.createdAt ? formatDateTime(item.createdAt) : "recently"}`;
  els.selectionFacts.innerHTML = facts.map(([label, value]) => `
    <div class="fact-row">
      <span class="fact-row__label">${escapeHtml(label)}</span>
      <span class="fact-row__value">${escapeHtml(value)}</span>
    </div>
  `).join("");
}

function getSelectedArtifact() {
  if (!state.dashboard) {
    return null;
  }

  const config = scopeConfig[state.selection.scope];
  const items = config ? state.dashboard[config.listKey] || [] : [];
  return items.find((item) => item.id === state.selection.id) || null;
}

function selectionExists() {
  return Boolean(getSelectedArtifact());
}

function clearViewer() {
  els.viewerTitle.textContent = "Viewer";
  els.viewerMeta.textContent = "Select an artifact from the explorer to inspect its files.";
  els.fileTabs.innerHTML = "";
  els.selectionFacts.innerHTML = "";
  els.selectionSummary.textContent = "File details and summaries for the current artifact selection.";
  els.viewer.innerHTML = `<div class="empty-state"><strong>No generated artifacts yet.</strong><p>Run a helper action from the left side to populate the dashboard.</p></div>`;
}

async function saveGamePath() {
  try {
    await fetchJson("/api/settings/game-path", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        gamePath: els.gamePathInput.value.trim()
      })
    });

    showFlash("Game path saved.", "success");
    await refreshState({ reloadSelection: false, silent: true });
  } catch (error) {
    showFlash(getErrorMessage(error), "error");
  }
}

async function runDashboardAction(url, body, successMessage) {
  try {
    await fetchJson(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body || {})
    });
    showFlash(successMessage, "success");
    await refreshState({ reloadSelection: false, silent: true });
  } catch (error) {
    showFlash(getErrorMessage(error), "error");
  }
}

async function analyzeSelectedDump() {
  if (state.selection.scope !== "runtime" || !state.selection.id) {
    showFlash("Select a runtime dump before starting analysis.", "error");
    return;
  }

  await runDashboardAction("/api/actions/analyze-runtime-dump", {
    dumpId: state.selection.id
  }, `Runtime dump ${state.selection.id} analysis started.`);
}

async function startServer() {
  try {
    await fetchJson("/api/server/start", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        port: Number.parseInt(els.serverPortInput.value, 10) || 27015
      })
    });
    showFlash("Server helper started.", "success");
    await refreshState({ reloadSelection: false, silent: true });
  } catch (error) {
    showFlash(getErrorMessage(error), "error");
  }
}

async function stopServer() {
  try {
    await fetchJson("/api/server/stop", {
      method: "POST"
    });
    showFlash("Server helper stop requested.", "success");
    await refreshState({ reloadSelection: false, silent: true });
  } catch (error) {
    showFlash(getErrorMessage(error), "error");
  }
}

async function installUe4ssMods() {
  await runDashboardAction("/api/actions/install-ue4ss-mods", {
    gamePath: els.gamePathInput.value.trim()
  }, "UE4SS mod install started.");
}

async function forceStopServer() {
  try {
    await fetchJson("/api/server/force-stop", {
      method: "POST"
    });
    showFlash("Force-kill requested for lingering server processes.", "success");
    await refreshState({ reloadSelection: false, silent: true });
  } catch (error) {
    showFlash(getErrorMessage(error), "error");
  }
}

async function runBridgeSmoke() {
  await runDashboardAction("/api/actions/client-bridge", {
    hostName: els.bridgeHostInput.value.trim(),
    port: Number.parseInt(els.bridgePortInput.value, 10) || 27015,
    name: els.bridgeNameInput.value.trim(),
    reason: els.bridgeReasonInput.value.trim(),
    timeoutMs: Number.parseInt(els.bridgeTimeoutInput.value, 10) || 1800
  }, "Client bridge smoke test started.");
}

async function cancelCurrentJob() {
  try {
    await fetchJson("/api/jobs/cancel", {
      method: "POST"
    });
    showFlash("Cancel requested for the active job.", "success");
    await refreshState({ reloadSelection: false, silent: true });
  } catch (error) {
    showFlash(getErrorMessage(error), "error");
  }
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, options);
  if (!response.ok) {
    throw await readError(response);
  }

  return response.json();
}

async function readError(response) {
  try {
    const payload = await response.json();
    return new Error(payload.error || payload.message || `HTTP ${response.status}`);
  } catch {
    return new Error(`HTTP ${response.status}`);
  }
}

function getErrorMessage(error) {
  return error?.message || String(error || "Unknown error");
}

function describeArtifact(scope, item) {
  if (!item) {
    return "Unknown artifact";
  }

  if (scope === "inventory") {
    return `${formatDateTime(item.createdAt)} | ${formatNumber(item.fileCount)} indexed files`;
  }
  if (scope === "run") {
    return `${formatDateTime(item.createdAt)} | ${formatNumber(item.packageFiles)} packages | ${formatNumber(item.legacyDataFiles)} legacy`;
  }
  if (scope === "noteRun") {
    return `${formatDateTime(item.createdAt)} | ${formatNumber(item.fileCount)} visible files`;
  }
  if (scope === "runtime") {
    return `${formatDateTime(item.createdAt)} | ${formatNumber(item.csvFiles)} CSV | ${item.hasMenuAnalysis ? "analysis ready" : "needs analysis"}`;
  }
  return item.id || "Artifact";
}

function statusTone(status) {
  if (status === "completed" || status === "running") {
    return "accent";
  }
  if (status === "cancelled" || status === "stopped") {
    return "warn";
  }
  if (status === "failed") {
    return "danger";
  }
  return "neutral";
}

function syncInputValue(input, value) {
  if (document.activeElement === input) {
    return;
  }
  input.value = value;
}

function formatDateTime(value) {
  if (!value) {
    return "Unknown";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return String(value);
  }
  return date.toLocaleString();
}

function formatNumber(value) {
  return Number.isFinite(value) ? value.toLocaleString() : String(value ?? "0");
}

function humanizeLabel(value) {
  return String(value || "unknown")
    .replaceAll("_", " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function showFlash(message, tone) {
  clearTimeout(state.flashTimer);
  els.flashMessage.textContent = message;
  els.flashMessage.className = `flash-message flash-message--${tone}`;
  state.flashTimer = window.setTimeout(() => {
    els.flashMessage.className = "flash-message hidden";
  }, 3600);
}

function csvToTable(text) {
  const rows = parseCsv(text);
  if (!rows.length) {
    return `<div class="empty-state"><strong>No rows found.</strong><p>The selected CSV file is empty.</p></div>`;
  }

  const [headers, ...data] = rows;
  return `
    <div class="table-wrap">
      <table>
        <thead>
          <tr>${headers.map((header) => `<th>${escapeHtml(header)}</th>`).join("")}</tr>
        </thead>
        <tbody>
          ${data.map((row) => `
            <tr>${headers.map((_, index) => `<td>${escapeHtml(row[index] || "")}</td>`).join("")}</tr>
          `).join("")}
        </tbody>
      </table>
    </div>
  `;
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let value = "";
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];

    if (quoted && char === '"' && next === '"') {
      value += '"';
      index += 1;
      continue;
    }

    if (char === '"') {
      quoted = !quoted;
      continue;
    }

    if (!quoted && char === ",") {
      row.push(value);
      value = "";
      continue;
    }

    if (!quoted && (char === "\n" || char === "\r")) {
      if (char === "\r" && next === "\n") {
        index += 1;
      }
      row.push(value);
      if (row.some((cell) => cell.length > 0)) {
        rows.push(row);
      }
      row = [];
      value = "";
      continue;
    }

    value += char;
  }

  row.push(value);
  if (row.some((cell) => cell.length > 0)) {
    rows.push(row);
  }

  return rows;
}

function markdownToHtml(text) {
  const lines = text.split(/\r?\n/);
  let html = `<div class="markdown">`;
  let inList = false;
  let inCode = false;
  let codeLines = [];

  const flushList = () => {
    if (inList) {
      html += "</ul>";
      inList = false;
    }
  };

  const flushCode = () => {
    if (inCode) {
      html += `<pre>${escapeHtml(codeLines.join("\n"))}</pre>`;
      codeLines = [];
      inCode = false;
    }
  };

  for (const rawLine of lines) {
    const line = rawLine.replace(/\t/g, "  ");

    if (line.trim().startsWith("```")) {
      flushList();
      if (inCode) {
        flushCode();
      } else {
        inCode = true;
        codeLines = [];
      }
      continue;
    }

    if (inCode) {
      codeLines.push(rawLine);
      continue;
    }

    if (line.startsWith("# ")) {
      flushList();
      html += `<h1>${inlineMarkdown(line.slice(2))}</h1>`;
    } else if (line.startsWith("## ")) {
      flushList();
      html += `<h2>${inlineMarkdown(line.slice(3))}</h2>`;
    } else if (line.startsWith("### ")) {
      flushList();
      html += `<h3>${inlineMarkdown(line.slice(4))}</h3>`;
    } else if (line.startsWith("- ")) {
      if (!inList) {
        html += "<ul>";
        inList = true;
      }
      html += `<li>${inlineMarkdown(line.slice(2))}</li>`;
    } else if (!line.trim()) {
      flushList();
    } else {
      flushList();
      html += `<p>${inlineMarkdown(line)}</p>`;
    }
  }

  flushList();
  flushCode();
  html += "</div>";
  return html;
}

function inlineMarkdown(text) {
  return escapeHtml(text)
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/`([^`]+)`/g, "<code>$1</code>");
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

setInterval(() => {
  void refreshState({ reloadSelection: false, silent: true });
}, 5000);

setInterval(() => {
  if (state.dashboard?.job?.isRunning || state.dashboard?.server?.running) {
    void refreshState({ reloadSelection: false, silent: true });
  }
}, 1500);

void refreshState({ reloadSelection: true, silent: false });
