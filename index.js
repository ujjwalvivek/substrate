import {
    loop,
    stop,
    compose,
    primitives,
    bindGenerator,
} from "https://cdn.ujjwalvivek.com/scripts/substrate/latest/main.js";
import {
    createStore,
    createRouter,
} from "https://cdn.ujjwalvivek.com/scripts/substrate/latest/core.js";
import {
    getCurrentColors,
    updateColorVariables,
    getThemeColors,
} from "https://cdn.ujjwalvivek.com/scripts/substrate/latest/color.js";
import { createTheme } from "https://cdn.ujjwalvivek.com/scripts/substrate/latest/theme.js";

const theme = createTheme();
function applyColors() {
    const colors = getCurrentColors(theme.colorMode, theme.darkMode);
    palette.background = colors.background;
    palette.primary = colors.primary;
    palette.secondary = colors.secondary;
    palette.accent = colors.accent;
    updateColorVariables(theme.colorMode, theme.darkMode);
}
const palette = {
    background: "#0a0a0a",
    primary: "#ff0080",
    secondary: "#8000ff",
    accent: "#00ffff",
};
applyColors();
const psychedelicScene = compose([
    {
        fn: primitives.background,
        options: {
            colorStops: [
                [0, "background", "50"],
                [0.4, "primary", "15"],
                [0.8, "secondary", "10"],
                [1, "background", "05"],
            ],
        },
    },
    {
        fn: primitives.mandala,
        options: {
            layers: 8,
            basePetals: 6,
            petalVariance: 3,
            radius: 300,
            colorStops: [
                [0, "accent", "80"],
                [0.5, "primary", "60"],
                [1, "secondary", "40"],
            ],
        },
    },
    { fn: primitives.particles, options: { minRadius: 150, maxRadius: 700 } },
    {
        fn: primitives.vignette,
        options: { innerRadius: 0.3, outerRadius: 1.0 },
    },
]);
const isMobile = window.innerWidth < 768;
const systemState = {
    speed: isMobile ? 0.1 : 0.1,
    density: isMobile ? 0.7 : 1.8,
    opacity: isMobile ? 1.0 : 1.0,
    fps: theme.fps,
};
document.body.innerHTML = `
    <canvas id="prism-canvas" style="position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; z-index: -1;"></canvas>
    <nav class="navbar">
        <a href="/" data-link class="logo">S U B S T R A T E</a>
        <div class="navbar-actions">
            <a href="https://github.com/ujjwalvivek/substrate"><img class="star-badge" src="https://echopoint.ujjwalvivek.com/svg/badges/stars?bg=111111&badgeColor=2b2b2b&textColor=e8e8e8&border=555555&borderWidth=0&rx=0&px=6&py=4&repo=substrate&logo=github" alt="GitHub stars"/></a>
            <button id="theme-toggle" class="theme-toggle-btn" title="Toggle dark / light">
                <div class="theme-icon">
                    <div class="theme-dot${theme.darkMode ? "" : " filled"}"></div>
                </div>
            </button>
        </div>
    </nav>
    <a href="/docs" data-link class="docs-strip">read the docs here ▸</a>
    <main id="app" style="flex: 1; display: flex; flex-direction: column; width: 100%; height: 100%; position: relative; overflow-y: auto;"></main>
`;
const canvas = document.getElementById("prism-canvas");
function startLoop() {
    loop(canvas, psychedelicScene, palette, systemState);
}
startLoop();
function buildSwatches() {
    const themes = getThemeColors(theme.darkMode);
    return theme.presets
        .map((p) => {
            const t = themes[p.id];
            const active = theme.colorMode === p.id ? " active" : "";
            return `<button class="theme-swatch${active}" data-theme="${p.id}" title="${p.label}">
            <div class="swatch-gradient" style="background: linear-gradient(135deg, ${t.primary}, ${t.secondary}, ${t.accent})"></div>
        </button>`;
        })
        .join("");
}
function highlightJS(code) {
    const pattern =
        /('(?:\\'|[^'])*'|"(?:\\"|[^"])*"|`[\s\S]*?`|\/\/.*?(?=\n|$)|\b\d+(?:\.\d+)?\b|\b(const|let|var|function|return|import|from|if|else|for|while|new|document|console)\b|\b(fn|options|spacing|opacity|density|primary|secondary|accent|background|speed|fps)\b)/g;
    code = code.replace(pattern, (match) => {
        if (
            match.startsWith("'") ||
            match.startsWith('"') ||
            match.startsWith("`")
        ) {
            return `<span style="color: var(--dynamic-theme-secondary)${/\.js['"`]?$/.test(match) ? "; text-decoration: underline;" : ""}">${match}</span>`;
        } else if (match.startsWith("//")) {
            return `<span style="color: var(--fg-muted)">${match}</span>`;
        } else if (/^\d+(\.\d+)?$/.test(match)) {
            return `<span style="color: var(--accent)">${match}</span>`;
        } else if (
            /^(const|let|var|function|return|import|from|if|else|for|while|new|document|console)$/.test(
                match,
            )
        ) {
            return `<span style="color: var(--dynamic-theme-primary)">${match}</span>`;
        } else if (
            /^(fn|options|spacing|opacity|density|primary|secondary|accent|background|speed|fps)$/.test(
                match,
            )
        ) {
            return `<span style="color: var(--dynamic-rgb-average)">${match}</span>`;
        }
        return match;
    });
    return code;
}
function parseMarkdown(md) {
    const blocks = [];
    md = md.replace(/```[a-z]*\n([\s\S]*?)```/gim, (match, p1) => {
        let code = p1.replace(/</g, "&lt;").replace(/>/g, "&gt;");
        code = highlightJS(code);
        blocks.push(`<pre><code>${code}</code></pre>`);
        return `__CODE_BLOCK_${blocks.length - 1}__`;
    });
    md = md.replace(/`([^`\n]+)`/g, (match, p1) => {
        return `<code>${p1.replace(/</g, "&lt;").replace(/>/g, "&gt;")}</code>`;
    });
    md = md.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    md = md.replace(/^### (.*$)/gm, "<h3>$1</h3>");
    md = md.replace(/^## (.*$)/gm, "<h2>$1</h2>");
    md = md.replace(/^# (.*$)/gm, "<h1>$1</h1>");
    md = md.replace(
        /\[([^\]]+)\]\(([^)]+)\)/g,
        '<a href="$2" target="_blank">$1</a>',
    );
    md = md.replace(/^---$/gm, "<hr>");
    let lines = md.split("\n"),
        out = [],
        inTable = false,
        inList = false;
    for (let i = 0; i < lines.length; i++) {
        let line = lines[i].trim();
        if (line.match(/^\|[\s\-:|]+\|$/)) continue;
        if (line.startsWith("|") && line.endsWith("|")) {
            if (!inTable) {
                out.push("<table>");
                inTable = true;
            }
            let row = line
                .substring(1, line.length - 1)
                .split("|")
                .map((c) => `<td>${c.trim()}</td>`)
                .join("");
            out.push(`<tr>${row}</tr>`);
            continue;
        } else if (inTable) {
            out.push("</table>");
            inTable = false;
        }
        if (line.startsWith("- ")) {
            if (!inList) {
                out.push("<ul>");
                inList = true;
            }
            out.push(`<li>${line.substring(2)}</li>`);
            continue;
        } else if (inList) {
            out.push("</ul>");
            inList = false;
        }
        if (line === "") continue;
        if (line.startsWith("<") || line.startsWith("__CODE_BLOCK_"))
            out.push(line);
        else out.push(`<p>${line}</p>`);
    }
    if (inTable) out.push("</table>");
    if (inList) out.push("</ul>");
    let html = out.join("\n");
    blocks.forEach((block, i) => {
        html = html.replace(`__CODE_BLOCK_${i}__`, block);
    });
    return html;
}
const store = createStore({ clicks: 0 });
const views = {
    "/": () => `
        <div class="hero">
        <div class="control-panel collapsible${isMobile ? " collapsed" : ""}">
          <button class="panel-toggle" aria-label="Toggle section">
            <span class="panel-header">> ABOUT_</span>
            <span class="collapse-icon">${isMobile ? "+" : "−"}</span>
          </button>
          <div class="collapse-content">
            <h1>PROCEDURAL ENGINE</h1>
            <a href="https://github.com/ujjwalvivek/substrate"><img src="https://echopoint.ujjwalvivek.com/svg/project?bg=0b0b0b&border=555555&badgeColor=2b2b2b&textColor=e8e8e8&pctColor=a6a6a6&accentColor=cfcfcf&width=260&repo=substrate"/></a>
            <p>A Lightweight, No-Dependency JavaScript Engine for Composing Dynamic, Procedural Background Animations.</p>
          </div>
        </div>
        <div class="control-panel collapsible">
          <button class="panel-toggle" aria-label="Toggle section">
            <span class="panel-header">> CONTROLS_</span>
            <span class="collapse-icon">−</span>
          </button>
          <div class="collapse-content">
            <div class="panel-header">> PREVIEW_</div>
            <button id="capture-btn" class="action-btn" style="width:100%; margin-bottom: 0.75rem;">CAPTURE FRAME</button>
            <button id="generate-btn" class="action-btn" style="width:100%; margin-bottom: 0.75rem;">GENERATE: ${store.clicks}</button>
            <div id="recipe-display" style="font-family: monospace; font-size: 0.7rem; opacity: 0.6; text-align: center; letter-spacing: 0.05em;margin-bottom: 0.75rem;"></div>
            <hr class="panel-divider">
            <div class="panel-header">> SYSTEM PARAMETERS_</div>
            <div class="control-group">
                <label for="speed-slider"><span>RUNTIME_SPEED:</span> <span><span id="speed-val">0.1</span>x</span></label>
                <input type="range" id="speed-slider" min="0" max="2" step="0.1" value="0.1">
            </div>
            <div class="control-group">
                <label for="density-slider"><span>PARTICLE_DENSITY:</span> <span id="density-val">1.0</span></label>
                <input type="range" id="density-slider" min="0.1" max="4" step="0.1" value="1.0">
            </div>
            <div class="control-group">
                <label for="opacity-slider"><span>EMISSION_OPACITY:</span> <span id="opacity-val">0.8</span></label>
                <input type="range" id="opacity-slider" min="0" max="1" step="0.05" value="0.8">
            </div>
            <hr class="panel-divider">
            <div class="panel-header">> THEMES_</div>
            <div class="theme-grid" id="theme-grid">
                ${buildSwatches()}
            </div>
            <hr class="panel-divider">
            <div class="panel-header">> FRAMERATE_</div>
            <div class="fps-group">
                <button class="fps-btn${systemState.fps === 0 ? " active" : ""}" data-fps="0">STATIC</button>
                <button class="fps-btn${systemState.fps === 30 ? " active" : ""}" data-fps="30">30 FPS</button>
                <button class="fps-btn${systemState.fps === 60 ? " active" : ""}" data-fps="60">60 FPS</button>
            </div>
            <hr class="panel-divider">
            <div class="panel-header">> UNRELATED TO WALLPAPER_</div>
            <div id="global-clicker-mount"></div>
          </div>
        </div>
        </div>
    `,
    "/docs": () => {
        setTimeout(() => {
            const container = document.getElementById("docs-content");
            if (container && !container.dataset.loaded) {
                container.dataset.loaded = "true";
                fetch(
                    "https://cdn.ujjwalvivek.com/scripts/substrate/latest/readme.md",
                )
                    .then((r) => r.text())
                    .then((text) => {
                        const el = document.getElementById("docs-content");
                        if (el) {
                            el.innerHTML = parseMarkdown(text);
                            el.querySelectorAll("pre").forEach((pre) => {
                                const wrapper = document.createElement("div");
                                wrapper.style.position = "relative";
                                wrapper.style.marginBottom = "1.5rem";
                                pre.parentNode.insertBefore(wrapper, pre);
                                wrapper.appendChild(pre);
                                const btn = document.createElement("button");
                                btn.className = "copy-btn";
                                btn.innerText = "COPY";
                                const code = pre.querySelector("code");
                                btn.onclick = () => {
                                    navigator.clipboard
                                        .writeText(code.innerText)
                                        .then(() => {
                                            btn.innerText = "COPIED!";
                                            btn.style.borderColor =
                                                "var(--accent)";
                                            btn.style.color = "var(--accent)";
                                            setTimeout(() => {
                                                btn.innerText = "COPY";
                                                btn.style.borderColor = "";
                                                btn.style.color = "";
                                            }, 2000);
                                        });
                                };
                                wrapper.appendChild(btn);
                            });
                        }
                    })
                    .catch((err) => {
                        const el = document.getElementById("docs-content");
                        if (el)
                            el.innerHTML = "> ERROR: FAILING TO FETCH DOCS.";
                    });
            }
        }, 0);
        return `
        <div class="docs-container">
            <div id="docs-content" class="markdown-body docs-content-wrapper">
                <div style="text-align: center; opacity: 0.5;">[ FETCHING_DOCUMENTATION... ]</div>
            </div>
        </div>
        `;
    },
    "/404": () => `
        <div class="hero">
        <h1>404 NOT FOUND</h1>
        <p>Invalid routing protocol.</p>
        </div>
    `,
};
createRouter(views, "app");
window.addEventListener("popstate", () => {
    updateStrip();
    bindEvents();
});
document.body.addEventListener("click", (e) => {
    if (e.target.matches("[data-link]")) {
        setTimeout(() => {
            updateStrip();
            bindEvents();
        }, 0);
    }
});

function updateStrip() {
    const strip = document.querySelector(".docs-strip");
    if (!strip) return;
    const hash = location.hash.slice(1) || "/";
    const isDocs = hash.startsWith("/docs");
    strip.innerHTML = isDocs ? "\u25C2 go back" : "read the docs here \u25B8";
    strip.href = isDocs ? "/" : "/docs";
}

document.querySelector(".docs-strip")?.addEventListener("click", () => {
    setTimeout(updateStrip, 0);
});

updateStrip();

function bindEvents() {
    const genBtn = document.getElementById("generate-btn");
    if (genBtn) {
        genBtn.addEventListener("click", () => {
            store.clicks += 1;
        });
    }
    const capBtn = document.getElementById("capture-btn");
    if (capBtn) {
        capBtn.addEventListener("click", () => {
            const canvas = document.getElementById("prism-canvas");
            if (canvas) {
                const a = document.createElement("a");
                a.href = canvas.toDataURL("image/png");
                a.download = "substrate_cover.png";
                a.click();
            }
        });
    }
    initClicker(document.getElementById("global-clicker-mount"));
    bindGenerator(canvas, palette, systemState);
    bindSlider("speed-slider", "speed-val", "speed");
    bindSlider("density-slider", "density-val", "density");
    bindSlider("opacity-slider", "opacity-val", "opacity");
    document.querySelectorAll(".theme-swatch").forEach((swatch) => {
        swatch.onclick = () => {
            theme.setColorMode(swatch.dataset.theme);
        };
    });
    document.querySelectorAll(".fps-btn").forEach((btn) => {
        btn.onclick = () => {
            theme.setFps(parseInt(btn.dataset.fps));
        };
    });
    document.querySelectorAll(".panel-toggle").forEach((btn) => {
        btn.onclick = () => {
            const panel = btn.closest(".collapsible");
            panel.classList.toggle("collapsed");
            const icon = btn.querySelector(".collapse-icon");
            icon.textContent = panel.classList.contains("collapsed")
                ? "+"
                : "−";
        };
    });
}
function bindSlider(sliderId, valId, stateKey) {
    const slider = document.getElementById(sliderId);
    const display = document.getElementById(valId);
    if (slider && display) {
        const updateProgress = () => {
            const min = parseFloat(slider.min) || 0;
            const max = parseFloat(slider.max) || 100;
            const val = parseFloat(slider.value);
            const percent = ((val - min) / (max - min)) * 100;
            slider.style.setProperty("--progress", `${percent}%`);
        };
        slider.value = systemState[stateKey];
        display.innerText = systemState[stateKey].toFixed(1);
        updateProgress();
        slider.addEventListener("input", (e) => {
            const val = parseFloat(e.target.value);
            systemState[stateKey] = val;
            display.innerText = val.toFixed(1);
            updateProgress();
        });
    }
}
document.getElementById("theme-toggle").onclick = () => {
    const icon = document.querySelector(".theme-icon");
    if (icon) {
        icon.classList.add("rotate");
        setTimeout(() => icon.classList.remove("rotate"), 400);
    }
    theme.toggleDarkMode();
};
theme.onChange(({ darkMode, colorMode, fps, changeType }) => {
    applyColors();
    const toggle = document.getElementById("theme-toggle");
    if (toggle) {
        const dot = toggle.querySelector(".theme-dot");
        if (dot) dot.classList.toggle("filled", !darkMode);
    }
    const grid = document.getElementById("theme-grid");
    if (grid) {
        grid.innerHTML = buildSwatches();
        grid.querySelectorAll(".theme-swatch").forEach((swatch) => {
            swatch.onclick = () => theme.setColorMode(swatch.dataset.theme);
        });
    }
    document.querySelectorAll(".fps-btn").forEach((b) => {
        b.classList.toggle("active", parseInt(b.dataset.fps) === fps);
    });
    if (changeType === "fps") {
        systemState.fps = fps;
        stop();
        startLoop();
    }
});
window.addEventListener("state:update", (e) => {
    if (e.detail.prop === "clicks") {
        const genBtn = document.getElementById("generate-btn");
        if (genBtn) genBtn.innerText = `GENERATED: ${e.detail.value}`;
    }
});
function initClicker(mountNode) {
    if (!mountNode) return;
    mountNode.innerHTML = `
        <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; width: 100%; margin-top: 0.5rem;">
            <button class="action-btn" id="globalClickBtn" style="width: 100%; transition: transform 0.1s ease;">
                <div id="globalClickScore" style="font-size: 1.5rem; font-weight: bold; color: var(--accent); margin-bottom: 0.75rem; font-family: monospace; letter-spacing: 0.05em; text-shadow: 0 0 10px var(--accent);">...</div>CLICK ME!
            </button>
        </div>
    `;

    const API_BASE = "https://echopoint.ujjwalvivek.com";
    const scoreEl = mountNode.querySelector("#globalClickScore");
    const btnEl = mountNode.querySelector("#globalClickBtn");
    let pendingClicks = 0;
    const wsUrl = "wss://echopoint.ujjwalvivek.com/v1/click";
    if (!window.epClickerSocket) {
        try {
            window.epClickerSocket = new WebSocket(wsUrl);
            window.epClickerSocket.onmessage = (e) => {
                const data = JSON.parse(e.data);
                if (data.global !== undefined) {
                    window.epGlobalScore = data.global;
                    const curScoreEl =
                        document.getElementById("globalClickScore");
                    if (curScoreEl)
                        curScoreEl.innerText = data.global.toLocaleString();
                }
            };
        } catch (err) {
            console.error("WS fail:", err);
        }
    } else {
        if (window.epGlobalScore !== undefined && scoreEl) {
            scoreEl.innerText = window.epGlobalScore.toLocaleString();
        }
    }
    btnEl.addEventListener("click", () => {
        pendingClicks++;
        const current = parseInt(scoreEl.innerText.replace(/,/g, ""), 10) || 0;
        scoreEl.innerText = (current + 1).toLocaleString();
        btnEl.style.transform = "scale(0.97)";
        setTimeout(() => (btnEl.style.transform = ""), 100);
        clearTimeout(btnEl.flushTimer);
        btnEl.flushTimer = setTimeout(() => {
            if (
                window.epClickerSocket &&
                window.epClickerSocket.readyState === WebSocket.OPEN
            ) {
                window.epClickerSocket.send(
                    JSON.stringify({ type: "click", count: pendingClicks }),
                );
            } else {
                fetch(`${API_BASE}/v1/click`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ count: pendingClicks }),
                });
            }
            pendingClicks = 0;
        }, 300);
    });
}
bindEvents();

(function () {
    const CHECK_INTERVAL = 100;
    let lastCheck = 0;
    async function checkReload() {
        if (Date.now() - lastCheck < CHECK_INTERVAL) return;
        lastCheck = Date.now();
        try {
            const res = await fetch("/api/check", { cache: "no-store" });
            const data = await res.json();
            if (data.reload) {
                console.log("Reloading page...");
                location.reload();
            }
        } catch (e) {}
    }
    setInterval(checkReload, CHECK_INTERVAL);
    console.log("Hot-reload enabled");
})();
