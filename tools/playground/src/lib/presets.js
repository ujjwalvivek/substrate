import { compose, primitives } from "@ujjwalvivek/substrate";

export const presets = {
    quantum: [
        { fn: primitives.background },
        { fn: primitives.nodes, options: { density: 1.2 } },
        { fn: primitives.vignette, options: { opacity: 0.6 } },
    ],
    holo: [
        { fn: primitives.background },
        { fn: primitives.scanlines, options: { opacity: 0.5 } },
        { fn: primitives.wireframes, options: { density: 1 } },
        { fn: primitives.grid, options: { opacity: 0.4 } },
        { fn: primitives.vignette },
    ],
    sacred: [
        { fn: primitives.background },
        { fn: primitives.mandala, options: { density: 1.2 } },
        {
            fn: primitives.particles,
            options: { density: 0.5, minRadius: 200, maxRadius: 450 },
        },
        { fn: primitives.vignette },
    ],
    organic: [
        { fn: primitives.background },
        { fn: primitives.grid, options: { opacity: 0.3, spacing: 120 } },
        { fn: primitives.branches, options: { density: 1 } },
        { fn: primitives.streams, options: { density: 0.8 } },
        { fn: primitives.vignette },
    ],
    nebula: [
        { fn: primitives.background },
        {
            fn: primitives.particles,
            options: { density: 2, minRadius: 50, maxRadius: 400 },
        },
        { fn: primitives.nodes, options: { density: 0.5, opacity: 0.4 } },
        { fn: primitives.vignette, options: { opacity: 0.5 } },
    ],
    mono: [
        { fn: primitives.background },
        {
            fn: primitives.grid,
            options: { spacing: 60, opacity: 0.6, warpAmount: 2 },
        },
        { fn: primitives.vignette, options: { opacity: 0.8 } },
    ],
    overload: [
        { fn: primitives.background },
        { fn: primitives.grid },
        { fn: primitives.scanlines },
        { fn: primitives.nodes, options: { density: 0.8 } },
        { fn: primitives.wireframes, options: { density: 0.5 } },
        { fn: primitives.particles, options: { density: 0.8 } },
        { fn: primitives.streams, options: { density: 0.5 } },
        { fn: primitives.vignette },
    ],
};

const COMPOSABLE = [
    [
        "grid",
        3,
        () => ({
            spacing: rand(60, 140),
            warpAmount: rand(2, 10),
            opacity: rand(0.3, 0.7),
        }),
    ],
    ["scanlines", 2, () => ({ spacing: rand(3, 8), opacity: rand(0.4, 0.9) })],
    [
        "particles",
        4,
        () => ({
            density: rand(0.6, 2.2),
            minRadius: rand(40, 160),
            maxRadius: rand(200, 500),
        }),
    ],
    [
        "nodes",
        4,
        () => ({ density: rand(0.6, 1.8), curveAmount: rand(15, 60) }),
    ],
    [
        "wireframes",
        3,
        () => ({ density: rand(0.4, 1.2), cubeSize: rand(25, 60) }),
    ],
    [
        "branches",
        2,
        () => ({ density: rand(0.5, 1.2), baseLength: rand(50, 100) }),
    ],
    [
        "mandala",
        3,
        () => ({
            layers: Math.floor(rand(3, 8)),
            basePetals: Math.floor(rand(4, 9)),
        }),
    ],
    [
        "streams",
        3,
        () => ({
            density: rand(0.5, 1.5),
            trailLength: Math.floor(rand(4, 10)),
        }),
    ],
    [
        "hyperstring",
        2,
        () => ({ density: rand(0.6, 1.4), scale: rand(0.25, 0.45) }),
    ],
    [
        "topography",
        2,
        () => ({ density: rand(0.5, 1.2), amplitude: rand(30, 80) }),
    ],
]
    .filter(([name]) => primitives[name])
    .map(([name, weight, options]) => ({ name, weight, options }));

export function rand(min, max) {
    return Math.random() * (max - min) + min;
}

export function weightedSample(pool, count) {
    const items = [...pool];
    const picked = [];
    for (let i = 0; i < Math.min(count, items.length); i++) {
        const total = items.reduce((sum, item) => sum + item.weight, 0);
        let random = Math.random() * total;
        let index = items.findIndex((item) => (random -= item.weight) < 0);
        if (index < 0) index = 0;
        picked.push(items.splice(index, 1)[0]);
    }
    return picked;
}

export function generateRandomScene() {
    const picked = weightedSample(COMPOSABLE, Math.floor(rand(2, 5)));
    return compose([
        { fn: primitives.background },
        ...picked.map((item) => ({
            fn: primitives[item.name],
            options: item.options(),
        })),
        { fn: primitives.vignette, options: { opacity: rand(0.4, 0.8) } },
    ]);
}
