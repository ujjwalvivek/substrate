<script>
    import { onMount } from "svelte";
    import "./styles/global.css";
    import Dropdown from "./components/Dropdown.svelte";
    import CustomColorPicker from "./components/CustomColorPicker.svelte";
    import GlobalClicker from "./components/GlobalClicker.svelte";
    import {
        SubstrateGPU,
        compose,
        primitives,
        shaderDescriptors,
        effectiveLayerOptions,
    } from "@ujjwalvivek/substrate";
    import { presets, generateRandomScene } from "./lib/presets.js";
    import * as CPU from "@ujjwalvivek/substrate/cpu";
    import { getThemeColors } from "@ujjwalvivek/substrate/colors";
    import { downloadCanvasFrame, downloadCanvasGif } from "./lib/capture.js";

    const COLLAPSE_STORAGE_KEY = "substrate-playground:collapse-state";
    const DEFAULT_COLLAPSE_STATE = {
        panelOpen: true,
        aboutOpen: false,
        previewOpen: false,
        clickerOpen: false,
    };
    const themeNames = Object.keys(getThemeColors(true));
    const fpsOptions = [
        { value: 0, label: "STATIC" },
        { value: 30, label: "30" },
        { value: 60, label: "60" },
    ];
    const presetOptions = [
        { value: "", label: "ISOLATED" },
        ...Object.keys(presets).map((name) => ({
            value: name,
            label: name.toUpperCase(),
        })),
    ];
    const primitiveOptions = [
        { value: "", label: "PICK ONE" },
        ...shaderDescriptors.map((descriptor) => ({
            value: descriptor.name,
            label: descriptor.label,
        })),
    ];
    let gpuCanvas;
    let cpuCanvas;
    let renderer;
    let errorMessage = "";
    let status = "DISCOVERING WGSL SHADERS";
    let selectedPreset = "sacred";
    let selectedPrimitive = "";
    let theme = "cyber";
    let customColor = "#00ffff";
    let dark = true;
    let compare = false;
    let speed = 1;
    let density = 1;
    let densityMinimum = 0.1;
    let opacity = 0.8;
    let fps = 30;
    let cpuRunning = false;
    let currentLayers = presets.sacred;
    let aboutOpen = DEFAULT_COLLAPSE_STATE.aboutOpen;
    let previewOpen = DEFAULT_COLLAPSE_STATE.previewOpen;
    let clickerOpen = DEFAULT_COLLAPSE_STATE.clickerOpen;
    let panelOpen = DEFAULT_COLLAPSE_STATE.panelOpen;
    let collapseStateLoaded = false;
    let generatedCount = 0;
    let captureStatus = "";
    let gifRecording = false;
    let gifProgress = 0;
    let captureStatusTimer;
    let themeOptions = [];

    function persistCollapseState() {
        if (!collapseStateLoaded) return;
        try {
            localStorage.setItem(
                COLLAPSE_STORAGE_KEY,
                JSON.stringify({
                    panelOpen,
                    aboutOpen,
                    previewOpen,
                    clickerOpen,
                }),
            );
        } catch {
            // Storage can be unavailable in private or restricted contexts.
        }
    }

    function loadCollapseState() {
        try {
            const saved = JSON.parse(
                localStorage.getItem(COLLAPSE_STORAGE_KEY) || "null",
            );
            if (saved && typeof saved === "object") {
                if (typeof saved.panelOpen === "boolean")
                    panelOpen = saved.panelOpen;
                if (typeof saved.aboutOpen === "boolean")
                    aboutOpen = saved.aboutOpen;
                if (typeof saved.previewOpen === "boolean")
                    previewOpen = saved.previewOpen;
                if (typeof saved.clickerOpen === "boolean")
                    clickerOpen = saved.clickerOpen;
            }
        } catch {
            // Ignore malformed or unavailable saved state.
        }
        collapseStateLoaded = true;
    }

    function toggleSection(section) {
        if (section === "about") aboutOpen = !aboutOpen;
        if (section === "preview") previewOpen = !previewOpen;
        if (section === "clicker") clickerOpen = !clickerOpen;
        persistCollapseState();
    }

    function setPanelOpen(open) {
        panelOpen = open;
        persistCollapseState();
    }

    $: recipeLayers = namesOf(currentLayers);
    $: recipe = `[ ${recipeLayers
        .map((name) => name.toUpperCase())
        .join(" + ")} ]`;
    $: densityMinimum = selectedPrimitive === "coastal-landscape" ? 0.9 : 0.1;

    function globalOptions() {
        return {
            speed: Number(speed),
            density: Number(density),
            opacity: Number(opacity),
            fps: Number(fps),
        };
    }

    function mixHex(hex, target, amount) {
        const parse = (value) => {
            const s = value.replace("#", "");
            return [0, 2, 4].map((i) => parseInt(s.slice(i, i + 2), 16));
        };
        const a = parse(hex);
        const b = parse(target);
        return (
            "#" +
            a
                .map((channel, i) =>
                    Math.round(channel + (b[i] - channel) * amount)
                        .toString(16)
                        .padStart(2, "0"),
                )
                .join("")
        );
    }

    function themeSwatch(name) {
        const colors = getThemeColors(dark)[name];
        return colors ? [colors.primary, colors.secondary, colors.accent] : [];
    }

    $: themeOptions = [
        ...themeNames.map((name) => ({
            value: name,
            label: name.toUpperCase(),
            swatch: themeSwatch(name),
        })),
        {
            value: "custom",
            label: "CUSTOM",
            swatch: [
                customColor,
                mixHex(
                    customColor,
                    dark ? "#000000" : "#ffffff",
                    dark ? 0.28 : 0.22,
                ),
                mixHex(
                    customColor,
                    dark ? "#ffffff" : "#000000",
                    dark ? 0.38 : 0.18,
                ),
            ],
        },
    ];

    function palette() {
        const background = dark ? "#0a0a0a" : "#f8f9fa";
        if (theme === "custom") {
            return {
                primary: customColor,
                secondary: mixHex(
                    customColor,
                    dark ? "#000000" : "#ffffff",
                    dark ? 0.28 : 0.22,
                ),
                accent: mixHex(
                    customColor,
                    dark ? "#ffffff" : "#000000",
                    dark ? 0.38 : 0.18,
                ),
                background,
            };
        }
        return { ...getThemeColors(dark)[theme], background };
    }

    function nameOf(layer) {
        return (
            layer.fn?.primitiveName ||
            Object.entries(CPU.primitives).find(
                ([, fn]) => fn === layer.fn,
            )?.[0] ||
            "?"
        );
    }

    function namesOf(layers) {
        return layers.map(nameOf);
    }

    function cpuSceneFromGpu(layers) {
        const converted = [];
        for (const layer of layers) {
            const name = nameOf(layer);
            const cpuPrimitive = CPU.primitives[name];
            if (!cpuPrimitive) continue;
            const effective = effectiveLayerOptions(
                name,
                layer.options || {},
                globalOptions(),
            );
            converted.push({
                fn: cpuPrimitive,
                options: {
                    ...(layer.options || {}),
                    speed: effective.speed,
                    density: effective.density,
                    opacity: effective.opacity,
                },
            });
        }
        return CPU.compose(converted);
    }

    function restartCpu() {
        CPU.stop();
        cpuRunning = true;
        CPU.loop(cpuCanvas, cpuSceneFromGpu(currentLayers), palette(), {
            speed: 1,
            density: 1,
            opacity: 0.8,
            fps: Number(fps),
        });
    }

    function applyScene(layers) {
        currentLayers = layers;
        renderer?.setScene(compose(layers));
        renderer?.setPalette(palette());
        renderer?.setOptions(globalOptions());
        if (cpuRunning) restartCpu();
    }

    function applyPalette() {
        renderer?.setPalette(palette());
        if (cpuRunning) restartCpu();
    }

    function handlePresetChange(value) {
        selectedPreset = value;
        if (!selectedPreset || !presets[selectedPreset]) return;
        selectedPrimitive = "";
        applyScene(presets[selectedPreset]);
    }

    function handlePrimitiveChange(value) {
        selectedPrimitive = value;
        if (value === "coastal-landscape" && Number(density) < 0.9) {
            density = 0.9;
        }
        isolate(value);
    }

    function handleThemeChange(value) {
        theme = value;
        applyPalette();
    }

    function handleCustomColorChange(value) {
        customColor = value;
        applyPalette();
    }

    function isolate(name) {
        if (!name) return;
        selectedPreset = "";
        if (name === "background") {
            applyScene([{ fn: primitives.background }]);
            return;
        }
        if (name === "vignette") {
            applyScene([
                { fn: primitives.background },
                { fn: primitives.vignette },
            ]);
            return;
        }
        const layers = [];
        if (primitives.background) layers.push({ fn: primitives.background });
        layers.push({ fn: primitives[name] });
        if (primitives.vignette) layers.push({ fn: primitives.vignette });
        applyScene(layers);
    }

    function handleSliderInput() {
        speed = Number(speed);
        density = Number(density);
        opacity = Number(opacity);
        renderer?.setOptions(globalOptions());
        if (cpuRunning) restartCpu();
    }

    function handleFpsChange(value) {
        fps = Number(value);
        renderer?.setOptions(globalOptions());
        renderer?.start();
        if (cpuRunning) restartCpu();
    }

    function handleCompareChange() {
        document.body.classList.toggle("compare", compare);
        if (compare) {
            restartCpu();
        } else {
            cpuRunning = false;
            CPU.stop();
        }
    }

    function generate() {
        const scene = generateRandomScene();
        generatedCount += 1;
        selectedPrimitive = "";
        selectedPreset = "";
        applyScene(
            scene.layers.map((layer) => ({
                fn: primitives[layer.name],
                options: layer.options,
            })),
        );
    }

    function showCaptureStatus(message) {
        captureStatus = message;
        clearTimeout(captureStatusTimer);
        captureStatusTimer = setTimeout(() => (captureStatus = ""), 4000);
    }

    async function captureFrame() {
        try {
            await downloadCanvasFrame(gpuCanvas);
            showCaptureStatus("FRAME SAVED AS PNG");
        } catch (error) {
            showCaptureStatus(error?.message || String(error));
        }
    }

    async function captureGif() {
        if (gifRecording) return;
        gifRecording = true;
        gifProgress = 0;
        const originalFps = Number(fps);
        try {
            if (originalFps === 0) {
                renderer?.setOptions({ ...globalOptions(), fps: 12 });
                renderer?.start();
            }
            await downloadCanvasGif(gpuCanvas, {
                duration: 3000,
                fps: 12,
                onProgress: (progress) => (gifProgress = progress),
            });
            showCaptureStatus("ANIMATION SAVED AS GIF");
        } catch (error) {
            showCaptureStatus(error?.message || String(error));
        } finally {
            if (originalFps === 0) {
                renderer?.setOptions(globalOptions());
                renderer?.start();
            }
            gifRecording = false;
            gifProgress = 0;
        }
    }

    onMount(() => {
        loadCollapseState();
        let disposed = false;

        async function boot() {
            const instance = new SubstrateGPU(gpuCanvas);
            renderer = instance;
            try {
                await instance.init();
                if (disposed) {
                    instance.destroy();
                    return;
                }
                applyScene(currentLayers);
                instance.start();
                status = `${shaderDescriptors.length} SHADERS ACTIVE`;
            } catch (error) {
                if (disposed) return;
                errorMessage = error?.message || String(error);
                status = "WEBGPU ERROR";
                console.error(error);
            }
        }

        boot();

        return () => {
            disposed = true;
            document.body.classList.remove("compare");
            CPU.stop();
            renderer?.destroy();
            renderer = null;
            clearTimeout(captureStatusTimer);
        };
    });
</script>

<svelte:head>
    <title>Substrate Playground</title>
</svelte:head>

<main class="app">
    <section class="stage">
        <div class="pane gpu-pane">
            <canvas bind:this={gpuCanvas} aria-label="Substrate WebGPU output"
            ></canvas>
        </div>

        <div class="pane cpu-pane">
            <canvas
                bind:this={cpuCanvas}
                aria-label="Original Canvas2D reference"
            ></canvas>
        </div>
    </section>

    {#if panelOpen}
        <aside class="panel" aria-label="Substrate playground controls">
            <button
                class="panel-collapse-toggle"
                type="button"
                aria-label="Collapse controls"
                title="Collapse controls"
                aria-expanded={panelOpen}
                onclick={() => setPanelOpen(false)}
            >
                <span>&gt; CONTROLS_</span>
                <span class="panel-collapse-icon" aria-hidden="true">−</span>
            </button>
            <section
                class="panel-hud hud"
                aria-label="Substrate playground status"
            >
                <div class="brand">S U B S T R A T E</div>

                <div class="hud-status">
                    <span class="status-indicator" aria-hidden="true"></span>
                    <span id="status" class="status">{status}</span>
                </div>

                <div
                    id="recipe"
                    class="recipe"
                    aria-label={`Recipe: ${recipe}`}
                >
                    <span class="recipe-layers">
                        {#each recipeLayers as name, index}
                            <span class="recipe-layer-group">
                                {#if index > 0}
                                    <span class="recipe-join" aria-hidden="true"
                                        >+</span
                                    >
                                {/if}
                                <span class="recipe-layer"
                                    >{name.toUpperCase()}</span
                                >
                            </span>
                        {/each}
                    </span>
                </div>

                <div class="hud-badges" aria-label="Render targets">
                    <span class="hud-badge">WGSL / GPU</span>
                    {#if compare}
                        <span class="hud-badge">ORIGINAL / CPU</span>
                    {/if}
                </div>
            </section>
            <section class="panel-section about-section">
                <button
                    class="panel-toggle"
                    type="button"
                    aria-expanded={aboutOpen}
                    aria-controls="about-content"
                    onclick={() => toggleSection("about")}
                >
                    <span class="panel-header">&gt; ABOUT_</span>
                    <span class="collapse-icon">{aboutOpen ? "−" : "+"}</span>
                </button>
                {#if aboutOpen}
                    <div id="about-content" class="about-content">
                        <a
                            href="https://github.com/ujjwalvivek/substrate"
                            target="_blank"
                            rel="noreferrer"
                        >
                            <img
                                class="product-card"
                                src="https://echopoint.ujjwalvivek.com/svg/project?bg=0b0b0b&badgeColor=2b2b2b&textColor=e8e8e8&pctColor=a6a6a6&accentColor=cfcfcf&width=260&repo=substrate"
                                alt="Substrate project status"
                            />
                        </a>
                    </div>
                {/if}
            </section>

            <hr class="panel-divider" />

            <section class="panel-section controls-section">
                <button
                    class="panel-toggle"
                    type="button"
                    aria-expanded={previewOpen}
                    aria-controls="preview-content"
                    onclick={() => toggleSection("preview")}
                >
                    <span class="panel-header">&gt; PREVIEW_</span>
                    <span class="collapse-icon">{previewOpen ? "−" : "+"}</span>
                </button>
                {#if previewOpen}
                    <div id="preview-content">
                        <div class="capture-actions">
                            <button
                                class="action-btn"
                                type="button"
                                onclick={captureFrame}
                            >
                                CAPTURE FRAME
                            </button>
                            <button
                                class="action-btn"
                                type="button"
                                disabled={gifRecording}
                                onclick={captureGif}
                            >
                                {gifRecording
                                    ? `GIF ${Math.round(gifProgress * 100)}%`
                                    : "EXPORT GIF"}
                            </button>
                        </div>
                        <button
                            class="action-btn generate-btn"
                            type="button"
                            onclick={generate}
                        >
                            {generatedCount
                                ? `GENERATED: ${generatedCount}`
                                : "GENERATE RECIPE"}
                        </button>
                        {#if captureStatus}
                            <div class="capture-status" aria-live="polite">
                                {captureStatus}
                            </div>
                        {/if}
                    </div>
                {/if}
            </section>

            <hr class="panel-divider" />

            <div class="row two">
                <label class="control-label">
                    <span>PRESET</span>
                    <span class="select-shell">
                        <Dropdown
                            value={selectedPreset}
                            options={presetOptions}
                            ariaLabel="Preset"
                            onValueChange={handlePresetChange}
                        />
                    </span>
                </label>

                <label class="control-label">
                    <span>ISOLATE</span>
                    <span class="select-shell">
                        <Dropdown
                            value={selectedPrimitive}
                            options={primitiveOptions}
                            ariaLabel="Isolate shader"
                            onValueChange={handlePrimitiveChange}
                        />
                    </span>
                </label>
            </div>

            <div class="row two theme-row">
                <label class="control-label">
                    <span>THEME</span>
                    <span class="select-shell">
                        <Dropdown
                            value={theme}
                            options={themeOptions}
                            ariaLabel="Theme"
                            onValueChange={handleThemeChange}
                        />
                    </span>
                </label>

                <label class="control-label">
                    <span>FPS</span>
                    <span class="select-shell">
                        <Dropdown
                            value={fps}
                            options={fpsOptions}
                            ariaLabel="Frames per second"
                            onValueChange={handleFpsChange}
                        />
                    </span>
                </label>
            </div>

            <div
                id="custom-color-wrap"
                class="color-control"
                hidden={theme !== "custom"}
            >
                <span class="color-control-head">
                    <span>CUSTOM THEME COLOR</span>
                    <output>{customColor.toUpperCase()}</output>
                </span>
                <CustomColorPicker
                    value={customColor}
                    onValueChange={handleCustomColorChange}
                />
            </div>

            <label class="slider">
                <span class="slider-head">
                    <span>SPEED</span>
                    <output id="speed-v">{Number(speed).toFixed(2)}</output>
                </span>
                <input
                    id="speed"
                    class="ui-range"
                    type="range"
                    min="0"
                    max="3"
                    step="0.01"
                    bind:value={speed}
                    oninput={handleSliderInput}
                />
            </label>

            <label class="slider">
                <span class="slider-head">
                    <span>DENSITY</span>
                    <output id="density-v">{Number(density).toFixed(2)}</output>
                </span>
                <input
                    id="density"
                    class="ui-range"
                    type="range"
                    min={densityMinimum}
                    max="2.25"
                    step="0.01"
                    bind:value={density}
                    oninput={handleSliderInput}
                />
            </label>

            <label class="slider">
                <span class="slider-head">
                    <span>OPACITY</span>
                    <output id="opacity-v">{Number(opacity).toFixed(2)}</output>
                </span>
                <input
                    id="opacity"
                    class="ui-range"
                    type="range"
                    min="0"
                    max="1"
                    step="0.01"
                    bind:value={opacity}
                    oninput={handleSliderInput}
                />
            </label>

            <div class="toggles">
                <label>
                    <input
                        id="dark"
                        class="ui-check"
                        type="checkbox"
                        bind:checked={dark}
                        onchange={applyPalette}
                    />
                    <span>DARK</span>
                </label>

                <label>
                    <input
                        id="compare"
                        class="ui-check"
                        type="checkbox"
                        bind:checked={compare}
                        onchange={handleCompareChange}
                    />
                    <span>CPU / GPU SPLIT</span>
                </label>
            </div>

            <hr class="panel-divider" />

            <section class="panel-section clicker-section">
                <button
                    class="panel-toggle"
                    type="button"
                    aria-expanded={clickerOpen}
                    aria-controls="clicker-content"
                    onclick={() => toggleSection("clicker")}
                >
                    <span class="panel-header"
                        >&gt; UNRELATED TO WALLPAPER_</span
                    >
                    <span class="collapse-icon">{clickerOpen ? "−" : "+"}</span>
                </button>
                {#if clickerOpen}
                    <div id="clicker-content">
                        <GlobalClicker />
                    </div>
                {/if}
            </section>
        </aside>
    {:else}
        <button
            class="panel-reopen"
            type="button"
            aria-label="Open controls"
            aria-expanded={panelOpen}
            onclick={() => setPanelOpen(true)}
        >
            + CONTROLS
        </button>
    {/if}

    <pre id="error" hidden={!errorMessage}>{errorMessage}</pre>
</main>
