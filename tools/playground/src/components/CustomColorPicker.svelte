<script>
    import { onMount } from "svelte";

    export let value = "#00ffff";
    export let onValueChange = () => {};

    let picker;
    let surface;
    let open = false;
    let currentColor = normalizeHex(value) || "#00ffff";
    let hexDraft = currentColor.toUpperCase();
    let { h: initialHue, s: initialSaturation, v: initialValue } =
        rgbToHsv(currentColor);
    let hue = initialHue;
    let saturation = initialSaturation;
    let brightness = initialValue;

    function clamp(number, min, max) {
        return Math.min(max, Math.max(min, number));
    }

    function normalizeHex(input) {
        const normalized = String(input || "").trim().replace(/^#?/, "#");
        return /^#[0-9a-f]{6}$/i.test(normalized)
            ? normalized.toLowerCase()
            : "";
    }

    function hexToRgb(hex) {
        return {
            r: parseInt(hex.slice(1, 3), 16),
            g: parseInt(hex.slice(3, 5), 16),
            b: parseInt(hex.slice(5, 7), 16),
        };
    }

    function rgbToHsv(hex) {
        let { r, g, b } = hexToRgb(hex);
        r /= 255;
        g /= 255;
        b /= 255;

        const max = Math.max(r, g, b);
        const min = Math.min(r, g, b);
        const delta = max - min;
        let nextHue = 0;

        if (delta) {
            if (max === r) nextHue = ((g - b) / delta) % 6;
            else if (max === g) nextHue = (b - r) / delta + 2;
            else nextHue = (r - g) / delta + 4;
            nextHue = Math.round(nextHue * 60);
            if (nextHue < 0) nextHue += 360;
        }

        return {
            h: nextHue,
            s: max === 0 ? 0 : delta / max,
            v: max,
        };
    }

    function hsvToHex(nextHue, nextSaturation, nextBrightness) {
        const h = (((Number(nextHue) % 360) + 360) % 360) / 60;
        const s = clamp(Number(nextSaturation), 0, 1);
        const v = clamp(Number(nextBrightness), 0, 1);
        const chroma = v * s;
        const x = chroma * (1 - Math.abs((h % 2) - 1));
        const match = v - chroma;
        let rgb;

        if (h < 1) rgb = [chroma, x, 0];
        else if (h < 2) rgb = [x, chroma, 0];
        else if (h < 3) rgb = [0, chroma, x];
        else if (h < 4) rgb = [0, x, chroma];
        else if (h < 5) rgb = [x, 0, chroma];
        else rgb = [chroma, 0, x];

        return (
            "#" +
            rgb
                .map((channel) =>
                    Math.round((channel + match) * 255)
                        .toString(16)
                        .padStart(2, "0"),
                )
                .join("")
        );
    }

    function emitColor(nextColor) {
        currentColor = nextColor;
        hexDraft = nextColor.toUpperCase();
        value = nextColor;
        onValueChange(nextColor);
    }

    function setFromHex(input, emit = true) {
        const nextColor = normalizeHex(input);
        if (!nextColor) return false;

        const next = rgbToHsv(nextColor);
        hue = next.h;
        saturation = next.s;
        brightness = next.v;
        if (emit) emitColor(nextColor);
        else {
            currentColor = nextColor;
            hexDraft = nextColor.toUpperCase();
        }
        return true;
    }

    function setFromHsv(nextHue, nextSaturation, nextBrightness) {
        hue = clamp(Number(nextHue), 0, 360);
        saturation = clamp(Number(nextSaturation), 0, 1);
        brightness = clamp(Number(nextBrightness), 0, 1);
        emitColor(hsvToHex(hue, saturation, brightness));
    }

    function updateSurface(event) {
        if (!surface) return;
        const rect = surface.getBoundingClientRect();
        const nextSaturation = clamp(
            (event.clientX - rect.left) / rect.width,
            0,
            1,
        );
        const nextBrightness = clamp(
            1 - (event.clientY - rect.top) / rect.height,
            0,
            1,
        );
        setFromHsv(hue, nextSaturation, nextBrightness);
    }

    function handleSurfacePointerDown(event) {
        event.preventDefault();
        updateSurface(event);

        const handlePointerMove = (moveEvent) => updateSurface(moveEvent);
        const handlePointerUp = () => {
            window.removeEventListener("pointermove", handlePointerMove);
            window.removeEventListener("pointerup", handlePointerUp);
        };
        window.addEventListener("pointermove", handlePointerMove);
        window.addEventListener("pointerup", handlePointerUp, { once: true });
    }

    function handleSurfaceKeydown(event) {
        let nextSaturation = saturation;
        let nextBrightness = brightness;
        const step = event.shiftKey ? 0.1 : 0.02;

        if (event.key === "ArrowRight") nextSaturation += step;
        else if (event.key === "ArrowLeft") nextSaturation -= step;
        else if (event.key === "ArrowUp") nextBrightness += step;
        else if (event.key === "ArrowDown") nextBrightness -= step;
        else return;

        event.preventDefault();
        setFromHsv(hue, nextSaturation, nextBrightness);
    }

    function handleHueInput(event) {
        setFromHsv(event.currentTarget.value, saturation, brightness);
    }

    function handleHexInput(event) {
        hexDraft = event.currentTarget.value.toUpperCase();
        setFromHex(hexDraft);
    }

    function commitHex() {
        if (!setFromHex(hexDraft)) hexDraft = currentColor.toUpperCase();
    }

    $: if (value && normalizeHex(value) !== currentColor) {
        setFromHex(value, false);
    }

    onMount(() => {
        const closeOnOutsidePointer = (event) => {
            if (!picker?.contains(event.target)) open = false;
        };
        const closeOnEscape = (event) => {
            if (event.key === "Escape") {
                open = false;
            }
        };

        document.addEventListener("pointerdown", closeOnOutsidePointer);
        document.addEventListener("keydown", closeOnEscape);
        return () => {
            document.removeEventListener("pointerdown", closeOnOutsidePointer);
            document.removeEventListener("keydown", closeOnEscape);
        };
    });
</script>

<div class="custom-picker" bind:this={picker}>
    <button
        class="custom-picker-trigger"
        type="button"
        aria-label="Open custom color picker"
        aria-expanded={open}
        onclick={() => (open = !open)}
    >
        <span
            class="custom-picker-preview"
            style={`--picker-color:${currentColor}`}
            aria-hidden="true"
        ></span>
        <span class="custom-picker-value">{currentColor.toUpperCase()}</span>
        <span class="custom-picker-caret" aria-hidden="true"
            >{open ? "−" : "+"}</span
        >
    </button>

    {#if open}
        <div class="custom-picker-popover" role="dialog" aria-label="Custom color picker">
            <div
                bind:this={surface}
                class="custom-picker-surface"
                style={`--picker-hue:${hue}`}
                role="slider"
                tabindex="0"
                aria-label="Color saturation and brightness"
                aria-valuemin="0"
                aria-valuemax="100"
                aria-valuenow={Math.round(saturation * 100)}
                aria-valuetext={currentColor.toUpperCase()}
                onpointerdown={handleSurfacePointerDown}
                onkeydown={handleSurfaceKeydown}
            >
                <span
                    class="custom-picker-cursor"
                    style={`left:${saturation * 100}%;top:${(1 - brightness) * 100}%`}
                    aria-hidden="true"
                ></span>
            </div>

            <label class="custom-picker-hue-label">
                <span>HUE</span>
                <input
                    class="custom-picker-hue"
                    type="range"
                    min="0"
                    max="360"
                    step="1"
                    value={hue}
                    aria-label="Hue"
                    oninput={handleHueInput}
                />
            </label>

            <label class="custom-picker-hex-label">
                <span>HEX</span>
                <input
                    class="custom-picker-hex"
                    type="text"
                    value={hexDraft}
                    maxlength="7"
                    inputmode="text"
                    spellcheck="false"
                    aria-label="Hex color value"
                    oninput={handleHexInput}
                    onblur={commitHex}
                    onkeydown={(event) => event.key === "Enter" && commitHex()}
                />
            </label>
        </div>
    {/if}
</div>

<style>
    .custom-picker {
        position: relative;
        width: 100%;
        margin-top: 5px;
    }

    .custom-picker-trigger {
        display: flex;
        align-items: center;
        gap: 8px;

        width: 100%;
        height: 32px;
        margin: 0;
        padding: 4px 7px;

        border: 1px solid var(--control-border);
        border-radius: 0;

        background: var(--control-bg);
        color: var(--text);

        font: inherit;
        font-size: 9px;
        letter-spacing: 0.04em;
        text-align: left;
    }

    .custom-picker-trigger:hover,
    .custom-picker-trigger:focus-visible {
        border-color: var(--control-border-hover);
        background: var(--control-bg-hover);
    }

    .custom-picker-preview {
        width: 24px;
        height: 20px;
        flex: 0 0 24px;

        border: 1px solid rgba(255, 255, 255, 0.45);
        background: var(--picker-color);
    }

    .custom-picker-value {
        min-width: 0;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    .custom-picker-caret {
        margin-left: auto;
        color: var(--text-muted);
        font-size: 14px;
        line-height: 1;
    }

    .custom-picker-popover {
        display: grid;
        gap: 8px;

        margin-top: 6px;
        padding: 8px;

        border: 1px solid var(--control-border-focus);
        border-radius: 0;
        background: var(--control-bg);
        box-shadow: 0 10px 24px rgba(0, 0, 0, 0.45);
    }

    .custom-picker-surface {
        position: relative;
        height: 130px;

        border: 1px solid rgba(255, 255, 255, 0.25);
        background:
            linear-gradient(to top, #000, transparent),
            linear-gradient(
                to right,
                #fff,
                hsl(var(--picker-hue), 100%, 50%)
            );
        cursor: crosshair;
        touch-action: none;
    }

    .custom-picker-surface:focus-visible {
        outline: 1px solid var(--control-border-focus);
        outline-offset: 2px;
    }

    .custom-picker-cursor {
        position: absolute;
        width: 12px;
        height: 12px;

        border: 2px solid #fff;
        border-radius: 50%;
        box-shadow: 0 0 0 1px #000;

        transform: translate(-50%, -50%);
        pointer-events: none;
    }

    .custom-picker-hue-label,
    .custom-picker-hex-label {
        display: grid;
        gap: 4px;

        margin: 0;
        color: var(--text-muted);
        font-size: 8px;
        letter-spacing: 0.08em;
    }

    .custom-picker-hue {
        display: block;
        width: 100%;
        height: 12px;
        margin: 0;
        padding: 0;

        border: 0;
        border-radius: 0;
        outline: 0;

        appearance: none;
        -webkit-appearance: none;
        background: linear-gradient(
            to right,
            #ff0000,
            #ffff00,
            #00ff00,
            #00ffff,
            #0000ff,
            #ff00ff,
            #ff0000
        );
        cursor: pointer;
    }

    .custom-picker-hue::-webkit-slider-thumb {
        width: 10px;
        height: 16px;

        border: 1px solid #fff;
        border-radius: 0;
        background: #111117;

        appearance: none;
        -webkit-appearance: none;
    }

    .custom-picker-hue::-moz-range-thumb {
        width: 10px;
        height: 16px;

        border: 1px solid #fff;
        border-radius: 0;
        background: #111117;
    }

    .custom-picker-hex {
        width: 100%;
        height: 28px;
        margin: 0;
        padding: 5px 7px;

        border: 1px solid var(--control-border);
        border-radius: 0;
        outline: 0;

        background: var(--control-bg);
        color: var(--text);

        font: inherit;
        font-size: 10px;
        letter-spacing: 0.04em;
        text-transform: uppercase;
    }

    .custom-picker-hex:focus {
        border-color: var(--control-border-focus);
        background: var(--control-bg-active);
    }
</style>
