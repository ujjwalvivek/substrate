/**
 * color.js [Color Engine]
 *
 * Pure color utilities, theme presets, and dynamic CSS variable injection.
 * Designed as a CDN-level engine script alongside substrate.js and core.js.
 *
 * Usage:
 *   import { getCurrentColors, updateColorVariables, getThemeColors } from './color.js'
 *
 *   const colors = getCurrentColors('cyber', true)
 *   //? => { primary: '#ff0080', secondary: '#8000ff', accent: '#00ffff', background: '#0a0a0a' }
 *
 *   updateColorVariables('cyber', true)
 *   //? sets --dynamic-theme-primary, --dynamic-rgb-average, etc. on :root
 */

export function hexToRgb(hex) {
    if (!hex) return { r: 0, g: 0, b: 0 };
    const s = String(hex).trim();
    if (!/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(s))
        return { r: 0, g: 0, b: 0 };
    return {
        r: parseInt(s.slice(1, 3), 16),
        g: parseInt(s.slice(3, 5), 16),
        b: parseInt(s.slice(5, 7), 16),
    };
}

export function rgbToHex(r, g, b) {
    const h = (n) => {
        const x = Math.round(Math.max(0, Math.min(255, n))).toString(16);
        return x.length === 1 ? "0" + x : x;
    };
    return `#${h(r)}${h(g)}${h(b)}`;
}

function rgbToHsl(r, g, b) {
    r /= 255;
    g /= 255;
    b /= 255;
    const max = Math.max(r, g, b),
        min = Math.min(r, g, b);
    let h,
        s,
        l = (max + min) / 2;
    if (max === min) {
        h = s = 0;
    } else {
        const d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        switch (max) {
            case r:
                h = (g - b) / d + (g < b ? 6 : 0);
                break;
            case g:
                h = (b - r) / d + 2;
                break;
            case b:
                h = (r - g) / d + 4;
                break;
            default:
                h = 0;
        }
        h /= 6;
    }
    return { h: h * 360, s: s * 100, l: l * 100 };
}

function hslToRgb(h, s, l) {
    h /= 360;
    s /= 100;
    l /= 100;
    const hue2rgb = (p, q, t) => {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    };
    if (s === 0)
        return {
            r: Math.round(l * 255),
            g: Math.round(l * 255),
            b: Math.round(l * 255),
        };
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    return {
        r: Math.round(hue2rgb(p, q, h + 1 / 3) * 255),
        g: Math.round(hue2rgb(p, q, h) * 255),
        b: Math.round(hue2rgb(p, q, h - 1 / 3) * 255),
    };
}

function averageRgbColors(colors) {
    if (!colors || !colors.length) return { r: 0, g: 0, b: 0 };
    const sum = colors.reduce(
        (a, c) => ({ r: a.r + c.r, g: a.g + c.g, b: a.b + c.b }),
        { r: 0, g: 0, b: 0 },
    );
    return {
        r: Math.round(sum.r / colors.length),
        g: Math.round(sum.g / colors.length),
        b: Math.round(sum.b / colors.length),
    };
}

function averageRgbColorsHSL(colors) {
    if (!colors || !colors.length) return { r: 0, g: 0, b: 0 };
    const hslArr = colors.map(({ r, g, b }) => rgbToHsl(r, g, b));
    let avgS = 0,
        avgL = 0,
        validHues = [];
    hslArr.forEach(({ h, s, l }) => {
        avgS += s;
        avgL += l;
        if (s > 5) validHues.push(h);
    });
    let avgH = 0;
    if (validHues.length > 0) {
        const x =
            validHues.reduce((s, h) => s + Math.cos((h * Math.PI) / 180), 0) /
            validHues.length;
        const y =
            validHues.reduce((s, h) => s + Math.sin((h * Math.PI) / 180), 0) /
            validHues.length;
        avgH = (Math.atan2(y, x) * 180) / Math.PI;
        if (avgH < 0) avgH += 360;
    }
    return hslToRgb(avgH, avgS / hslArr.length, avgL / hslArr.length);
}

function getDominantColor(colors) {
    if (!colors || !colors.length) return { r: 0, g: 0, b: 0 };
    let maxSat = 0,
        dominant = colors[0];
    colors.forEach((c) => {
        const hsl = rgbToHsl(c.r, c.g, c.b);
        if (hsl.s > maxSat) {
            maxSat = hsl.s;
            dominant = c;
        }
    });
    return dominant;
}

export function getThemeColors(darkMode) {
    return {
        cyber: darkMode
            ? { primary: "#ff0080", secondary: "#8000ff", accent: "#00ffff" }
            : { primary: "#d63384", secondary: "#6f42c1", accent: "#0dcaf0" },
        ocean: darkMode
            ? { primary: "#00aaff", secondary: "#0066aa", accent: "#00ffff" }
            : { primary: "#0d6efd", secondary: "#0a58ca", accent: "#17a2b8" },
        fire: darkMode
            ? { primary: "#ff4500", secondary: "#ff6600", accent: "#ffff00" }
            : { primary: "#fd7e14", secondary: "#dc3545", accent: "#ffc107" },
        spark: darkMode
            ? { primary: "#00ff41", secondary: "#0080ff", accent: "#ff4500" }
            : { primary: "#28a745", secondary: "#007bff", accent: "#fd7e14" },
        forest: darkMode
            ? { primary: "#90EE90", secondary: "#8FBC8F", accent: "#F0E68C" }
            : { primary: "#6B8E23", secondary: "#9ACD32", accent: "#DEB887" },
        synthwave: darkMode
            ? { primary: "#ff6ec7", secondary: "#7209b7", accent: "#00f5ff" }
            : { primary: "#e91e63", secondary: "#9c27b0", accent: "#00bcd4" },
        sunset: darkMode
            ? { primary: "#ff6b35", secondary: "#f7931e", accent: "#ffcd3c" }
            : { primary: "#ff5722", secondary: "#ff9800", accent: "#ffc107" },
        midnight: darkMode
            ? { primary: "#1e3a8a", secondary: "#3730a3", accent: "#6366f1" }
            : { primary: "#1565c0", secondary: "#1976d2", accent: "#42a5f5" },
        aurora: darkMode
            ? { primary: "#10b981", secondary: "#06b6d4", accent: "#8b5cf6" }
            : { primary: "#059669", secondary: "#0891b2", accent: "#7c3aed" },
        neon: darkMode
            ? { primary: "#39ff14", secondary: "#ff073a", accent: "#ff9f00" }
            : { primary: "#4caf50", secondary: "#f44336", accent: "#ff9800" },
    };
}

export function getCurrentColors(colorMode, darkMode, customColor) {
    const themes = getThemeColors(darkMode);
    const bg = darkMode ? "#0a0a0a" : "#f8f9fa";
    if (colorMode === "custom" && customColor) {
        return {
            primary: customColor,
            secondary: customColor + "80",
            accent: customColor + "60",
            background: bg,
        };
    }
    if (themes[colorMode]) {
        return { ...themes[colorMode], background: bg };
    }
    return { ...themes.cyber, background: bg };
}

export function getAverageHex(
    colorMode,
    darkMode,
    customColor,
    includeBackground = false,
    method = "hsl",
) {
    try {
        const colors = getCurrentColors(colorMode, darkMode, customColor);
        const vals = [colors.primary, colors.secondary, colors.accent];
        if (includeBackground) vals.push(colors.background);
        const rgbArr = vals
            .filter((c) => c && typeof c === "string")
            .map((c) => hexToRgb(c));
        let avg;
        switch (method) {
            case "hsl":
                avg = averageRgbColorsHSL(rgbArr);
                break;
            case "dominant":
                avg = getDominantColor(rgbArr);
                break;
            default:
                avg = averageRgbColors(rgbArr);
        }
        return rgbToHex(avg.r, avg.g, avg.b);
    } catch (e) {
        console.error("Error calculating average hex:", e);
        return darkMode ? "#e0e0e0" : "#202020";
    }
}

export function updateColorVariables(
    colorMode,
    darkMode,
    customColor,
    element = document.documentElement,
) {
    try {
        const colors = getCurrentColors(colorMode, darkMode, customColor);
        Object.entries(colors).forEach(([name, color]) => {
            const rgb = hexToRgb(color);
            element.style.setProperty(`--dynamic-theme-${name}`, String(color));
            element.style.setProperty(
                `--dynamic-theme-${name}-rgb`,
                `${rgb.r}, ${rgb.g}, ${rgb.b}`,
            );
        });
        const rgbAvg = getAverageHex(
            colorMode,
            darkMode,
            customColor,
            false,
            "rgb",
        );
        const hslAvg = getAverageHex(
            colorMode,
            darkMode,
            customColor,
            false,
            "hsl",
        );
        const dominant = getAverageHex(
            colorMode,
            darkMode,
            customColor,
            false,
            "dominant",
        );
        const rgbAvgRgb = hexToRgb(rgbAvg);
        const hslAvgRgb = hexToRgb(hslAvg);
        const dominantRgb = hexToRgb(dominant);
        element.style.setProperty("--dynamic-rgb-average", rgbAvg);
        element.style.setProperty(
            "--dynamic-rgb-average-rgb",
            `${rgbAvgRgb.r}, ${rgbAvgRgb.g}, ${rgbAvgRgb.b}`,
        );
        element.style.setProperty("--dynamic-hsl-average", hslAvg);
        element.style.setProperty(
            "--dynamic-hsl-average-rgb",
            `${hslAvgRgb.r}, ${hslAvgRgb.g}, ${hslAvgRgb.b}`,
        );
        element.style.setProperty("--dynamic-dominant-color", dominant);
        element.style.setProperty(
            "--dynamic-dominant-color-rgb",
            `${dominantRgb.r}, ${dominantRgb.g}, ${dominantRgb.b}`,
        );
    } catch (e) {
        console.error("Error updating CSS color variables:", e);
    }
}
