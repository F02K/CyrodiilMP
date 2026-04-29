const statusOutput = document.querySelector("#statusOutput");
const connectForm = document.querySelector("#connectForm");
const closeButton = document.querySelector("#closeButton");
const disconnectButton = document.querySelector("#disconnectButton");

function setStatus(message) {
    statusOutput.value = message;
    statusOutput.textContent = message;
}

function getHostBridge() {
    return window.CyrodiilMP
        || window.NirnLabUIPlatform
        || window.nirnLab
        || null;
}

function invoke(command, payload = {}) {
    const bridge = getHostBridge();
    const body = JSON.stringify(payload);

    if (bridge && typeof bridge.invoke === "function") {
        bridge.invoke(command, body);
        return true;
    }

    if (bridge && typeof bridge.call === "function") {
        bridge.call(command, body);
        return true;
    }

    console.log(`[CyrodiilMP] ${command}`, payload);
    return false;
}

connectForm.addEventListener("submit", (event) => {
    event.preventDefault();

    const form = new FormData(connectForm);
    const payload = {
        host: String(form.get("host") || "127.0.0.1"),
        port: Number(form.get("port") || 27016),
        name: String(form.get("name") || "OblivionPlayer"),
        reason: "chromium-menu-connect"
    };

    const sent = invoke("cyrodiilmp.connect", payload);
    setStatus(sent ? "Connecting..." : "UI backend not attached");
});

disconnectButton.addEventListener("click", () => {
    const sent = invoke("cyrodiilmp.disconnect");
    setStatus(sent ? "Disconnecting..." : "UI backend not attached");
});

closeButton.addEventListener("click", () => {
    invoke("cyrodiilmp.close");
});

window.cyrodiilmpEvent = function cyrodiilmpEvent(name, payload) {
    if (name === "statusChanged" && payload && payload.message) {
        setStatus(payload.message);
    }
};
