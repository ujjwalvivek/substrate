/**
 * theme.js [Theme Engine]
 *
 * Dark/light mode management + theme preset selection with localStorage persistence.
 * Designed as a CDN-level engine script alongside substrate.js, core.js, and color.js.
 *
 * Usage:
 *   import { createTheme, PRESETS } from './theme.js'
 *
 *   const theme = createTheme()
 *   theme.toggleDarkMode()        // flips dark ↔ light
 *   theme.setColorMode('ocean')   // switch palette
 *   theme.setFps(60)              // switch framerate
 *
 *   theme.onChange(({ darkMode, colorMode, fps }) => {
 *     // react to any theme change
 *   })
 */

export const PRESETS = [
    { id: "cyber", label: "CYBER" },
    { id: "ocean", label: "OCEAN" },
    { id: "forest", label: "FOREST" },
    { id: "synthwave", label: "SYNTHWAVE" },
];

function loadPref(key, fallback) {
    try {
        const v = localStorage.getItem(key);
        return v !== null ? JSON.parse(v) : fallback;
    } catch {
        return fallback;
    }
}

function savePref(key, value) {
    try {
        localStorage.setItem(key, JSON.stringify(value));
    } catch {}
}

/**
 * Create the theme controller. Call once at app init.
 * @returns {{ darkMode: boolean, colorMode: string, fps: number, toggleDarkMode, setColorMode, setFps, onChange, presets }}
 */
export function createTheme() {
    let darkMode = loadPref("darkMode", true);
    let colorMode = loadPref("colorMode", "cyber");
    let fps = loadPref("fps", 30);
    const listeners = [];
    applyDarkMode(darkMode);
    function applyDarkMode(isDark) {
        if (isDark) {
            document.body.classList.add("dark-mode");
            document.body.classList.remove("light-mode");
        } else {
            document.body.classList.remove("dark-mode");
            document.body.classList.add("light-mode");
        }
        document.documentElement.style.overflow = "hidden";
        setTimeout(() => {
            document.documentElement.style.overflow = "";
        }, 1);
    }

    function notify(changeType) {
        const detail = { darkMode, colorMode, fps, changeType };
        listeners.forEach((fn) => fn(detail));
        window.dispatchEvent(new CustomEvent("theme:change", { detail }));
    }

    return {
        get darkMode() {
            return darkMode;
        },
        get colorMode() {
            return colorMode;
        },
        get fps() {
            return fps;
        },
        get presets() {
            return PRESETS;
        },
        toggleDarkMode() {
            darkMode = !darkMode;
            savePref("darkMode", darkMode);
            applyDarkMode(darkMode);
            notify("darkMode");
        },
        setColorMode(mode) {
            colorMode = mode;
            savePref("colorMode", mode);
            notify("colorMode");
        },
        setFps(value) {
            fps = value;
            savePref("fps", fps);
            notify("fps");
        },
        /**
         * Register a callback for any theme/fps change.
         * @param {Function} fn receives { darkMode, colorMode, fps, changeType }
         */
        onChange(fn) {
            listeners.push(fn);
        },
    };
}
