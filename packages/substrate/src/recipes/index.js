// Named recipes in format v1 (see src/gpu/recipe.js). Plain data with no imports, so the "./recipes" entry stays
// small and independent of the GPU runtime. Pass one to recipeToScene() from the main entry to get a scene.

// root: the six-layer stack ujjwalvivek.com root uses today (root/static/js/background.js), copied exactly.
const root = {
    recipe: 1,
    name: "root",
    layers: [
        {
            name: "digital-rain",
            opacity: 1,
            speed: 0.03,
            density: 3,
            params: { cellSize: 20, trailLength: 10, glyphDensity: 0.6, flicker: 15 },
        },
        {
            name: "desktop-wallpaper",
            opacity: 0.7,
            speed: 0.25,
            density: 3,
            params: {},
        },
        {
            name: "particles",
            opacity: 0.35,
            speed: 0.05,
            density: 3,
            params: { maxRadius: 1200, minRadius: 120 },
        },
        {
            name: "floating-squares",
            opacity: 1,
            speed: 0.35,
            density: 0,
            params: { minSize: 2, maxSize: 20, count: 0 },
        },
        {
            name: "vignette",
            opacity: 1,
            speed: 0,
            density: 0,
            params: { innerRadius: 0.1, outerRadius: 0.8 },
        },
        {
            name: "city-skyline",
            opacity: 0.25,
            speed: 2,
            density: 3,
            params: {
                buildingCount: 15,
                windowDensity: 0.5,
                horizon: -1,
                color: "background",
                waterDepth: 0,
            },
        },
    ],
};

// CANDIDATE, not yet reviewed on screen; may be rejected.
// nebula: soft and deep. A pixel starfield base, slow nebula clouds washed over it so the stars show through, large
// dim glows for depth, a few slow streams for motion, and a wide vignette.
const nebula = {
    recipe: 1,
    name: "nebula",
    layers: [
        {
            name: "pixel-nebula-stars",
            opacity: 1,
            speed: 0.4,
            density: 0.5,
            params: { starSize: 3, starSpeed: 30, nebulaStrength: 0.6, twinkle: 1 },
        },
        {
            name: "nebula-drift",
            opacity: 0.45,
            speed: 0.1,
            density: 0.6,
            params: { zoomSpeed: 0.15, zoomAmount: 0.2, zoomOffset: 1.2, brightness: 1.6 },
        },
        {
            name: "particles",
            opacity: 0.3,
            speed: 0.04,
            density: 2,
            params: { minRadius: 150, maxRadius: 900 },
        },
        {
            name: "streams",
            opacity: 0.25,
            speed: 0.3,
            density: 0.6,
            params: { trailLength: 10 },
        },
        {
            name: "vignette",
            opacity: 1,
            speed: 0,
            density: 0,
            params: { innerRadius: 0.2, outerRadius: 0.85 },
        },
    ],
};

// CANDIDATE, not yet reviewed on screen; may be rejected.
// signal: structured and technical. A dark laser grid base, a faint voronoi mosaic and scanlines for texture, a
// drifting node network for motion, the sys$horizon panes washed in at low opacity for depth, and a vignette.
const signal = {
    recipe: 1,
    name: "signal",
    layers: [
        {
            name: "laser-grid",
            opacity: 1,
            speed: 0.2,
            density: 0.6,
            params: { spacing: 140, lineWidth: 0.01, warpAmount: 3, color: "secondary" },
        },
        {
            name: "voronoi-perlin",
            opacity: 0.12,
            speed: 0.05,
            density: 0.6,
            params: { voronoiScale: 24, perlinScale: 5, noiseSpeed: 0.2, contrast: 0.6 },
        },
        {
            name: "scanlines",
            opacity: 0.5,
            speed: 1,
            density: 1,
            params: { spacing: 3, maxAlpha: 0.06, color: "primary" },
        },
        {
            name: "nodes",
            opacity: 0.5,
            speed: 0.3,
            density: 0.6,
            params: { maxDist: 0.12, nodeSize: 1.5, curveAmount: 20 },
        },
        {
            name: "sys-horizon",
            opacity: 0.18,
            speed: 0.3,
            density: 1,
            params: { horizon: 0.1, skyFade: 0.4, paneDepth: 0.05, reflectionStrength: 0.25 },
        },
        {
            name: "vignette",
            opacity: 1,
            speed: 0,
            density: 0,
            params: { innerRadius: 0.15, outerRadius: 0.85 },
        },
    ],
};

function deepFreeze(value) {
    if (value && typeof value === "object") {
        Object.values(value).forEach(deepFreeze);
        Object.freeze(value);
    }
    return value;
}

export const recipes = deepFreeze({ root, nebula, signal });
export const recipeNames = Object.freeze(Object.keys(recipes));

// A fresh, mutable copy of the named recipe, or undefined if there is none.
export function getRecipe(name) {
    const recipe = Object.hasOwn(recipes, name) ? recipes[name] : undefined;
    return recipe ? JSON.parse(JSON.stringify(recipe)) : undefined;
}
