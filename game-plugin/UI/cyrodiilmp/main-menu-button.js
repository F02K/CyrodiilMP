const multiplayerButton = document.querySelector("#multiplayerButton");

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

multiplayerButton.addEventListener("click", () => {
    invoke("cyrodiilmp.openMainMenu", {
        source: "nirnlab-main-menu-button"
    });
});
