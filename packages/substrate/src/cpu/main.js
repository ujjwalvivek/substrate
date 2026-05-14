/**
 * substrate.js [Primitive Engine]
 *
 * A compositional engine. Each primitive is a pure drawing function.
 * Compose them freely. Mix. Override. Extend.
 *
 * Usage:
 *
 *   import { compose, loop, stop, primitives } from './generator/substrate.js'
 *
 *   //? Pick primitives, set per-primitive overrides
 *   const scene = compose([
 *     { fn: primitives.grid,        options: { opacity: 0.4 } },
 *     { fn: primitives.particles,   options: { density: 2.0 } },
 *     { fn: primitives.nodes,       options: { speed: 0.5   } },
 *   ])
 *
 *   //? Animate on a canvas
 *   loop(canvas, scene, {
 *     primary:    '#00ffff',
 *     secondary:  '#ff00ff',
 *     accent:     '#ffff00',
 *     background: '#0a0a0f',
 *   })
 *
 *   stop() // cancel
 *
 * Every primitive signature:
 *   fn(ctx, width, height, time, palette, options)
 *   time    // seconds (float)
 *   palette // { primary, secondary, accent, background }
 *   options // { speed, density, opacity, ...primitive-specific }
 */

function hexToRgb(hex) {
    return {
        r: parseInt(hex.slice(1, 3), 16),
        g: parseInt(hex.slice(3, 5), 16),
        b: parseInt(hex.slice(5, 7), 16),
    };
}

function rgba(hex, alpha) {
    if (typeof hex !== "string" || !/^#[0-9a-fA-F]{6}$/.test(hex))
        return `rgba(0,0,0,0)`;
    const { r, g, b } = hexToRgb(hex);
    return `rgba(${r},${g},${b},${alpha})`;
}

function lerpColor(hexA, hexB, t) {
    const a = hexToRgb(hexA),
        b = hexToRgb(hexB);
    const r = Math.round(a.r + (b.r - a.r) * t);
    const g = Math.round(a.g + (b.g - a.g) * t);
    const bl = Math.round(a.b + (b.b - a.b) * t);
    return `rgb(${r},${g},${bl})`;
}

const DEFAULTS = {
    speed: 1,
    density: 1,
    opacity: 0.8,
};

function opts(incoming) {
    return { ...DEFAULTS, ...incoming };
}

export const primitives = {
    /**
     * options: { colorStop? } // array of [position, paletteKey] pairs
     */
    background(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const stops = o.colorStops ?? [
            [0, "background", "30"],
            [0.5, "primary", "10"],
            [1, "background", "05"],
        ];
        const cx = o.cx ?? width / 2;
        const cy = o.cy ?? height / 2;
        const r = Math.max(width, height) * (o.radius ?? 1);
        const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
        stops.forEach(([pos, key, alpha = "FF"]) => {
            g.addColorStop(
                pos,
                rgba(
                    palette[key] ?? palette.background,
                    parseInt(alpha, 16) / 255,
                ),
            );
        });
        ctx.globalAlpha = 1;
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, width, height);
    },
    /**
     * options: { spacing, warpAmount, horizontal, vertical, color }
     */
    grid(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const sp = o.spacing ?? 100;
        const wa = o.warpAmount ?? 5;
        const col = o.color ?? "secondary";
        ctx.strokeStyle = palette[col] ?? palette.secondary;
        ctx.lineWidth = 0.5;
        ctx.globalAlpha = o.opacity * 0.12;
        if (o.horizontal !== false) {
            for (let y = sp; y < height; y += sp) {
                const oy = y + Math.sin(time * o.speed + y * 0.01) * wa;
                ctx.beginPath();
                for (let x = 0; x <= width; x += 20) {
                    const ty =
                        oy +
                        Math.sin(time * o.speed * 1.1 + x * 0.02) * wa * 0.5;
                    x === 0 ? ctx.moveTo(x, ty) : ctx.lineTo(x, ty);
                }
                ctx.stroke();
            }
        }
        if (o.vertical !== false) {
            for (let x = sp; x < width; x += sp) {
                const ox = x + Math.cos(time * o.speed + x * 0.01) * wa;
                ctx.beginPath();
                for (let y = 0; y <= height; y += 20) {
                    const tx =
                        ox +
                        Math.cos(time * o.speed * 1.1 + y * 0.02) * wa * 0.5;
                    y === 0 ? ctx.moveTo(tx, y) : ctx.lineTo(tx, y);
                }
                ctx.stroke();
            }
        }
        ctx.globalAlpha = 1;
    },
    /**
     * options: { spacing, color, maxAlpha }
     */
    scanlines(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const sp = o.spacing ?? 4;
        const col = o.color ?? "primary";
        const max = o.maxAlpha ?? 0.08;
        ctx.strokeStyle = palette[col] ?? palette.primary;
        ctx.lineWidth = 1;
        for (let y = 0; y < height; y += sp) {
            const intensity =
                Math.sin(time * o.speed * 2 + y * 0.01) * 0.5 + 0.5;
            const offset = Math.sin(time * o.speed + y * 0.02) * 2;
            if (intensity > 0.3) {
                ctx.globalAlpha = max * intensity * o.opacity;
                ctx.beginPath();
                ctx.moveTo(0, y + offset);
                ctx.lineTo(width, y + offset);
                ctx.stroke();
            }
        }
        ctx.globalAlpha = 1;
    },
    /**
     * options: { count, minRadius, maxRadius, color, glowSize }
     */
    particles(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const n = Math.floor(80 * o.density);
        const cx = width / 2,
            cy = height / 2;
        const min = o.minRadius ?? 80;
        const max = o.maxRadius ?? Math.min(width, height) * 0.45;
        for (let i = 0; i < n; i++) {
            const phase = time * o.speed * 3 + i * 0.1;
            const angle = ((i * 2.39998) % (Math.PI * 2)) + phase * 0.05;
            const radius =
                min + ((i % n) / n) * (max - min) + Math.sin(phase * 2) * 30;
            const px = cx + Math.cos(angle) * radius;
            const py = cy + Math.sin(angle) * radius;
            if (px < 0 || px > width || py < 0 || py > height) continue;
            const intensity = Math.sin(phase * 7) * 0.5 + 0.5;
            const size = 1.5 + Math.sin(phase * 11) * 2.5;
            const col = [palette.primary, palette.secondary, palette.accent][
                Math.floor((phase * 3) % 3)
            ];
            ctx.globalAlpha = intensity * o.opacity * 0.7;
            const glow = Math.max(size * 3, 1);
            const gr = ctx.createRadialGradient(px, py, 0, px, py, glow);
            gr.addColorStop(0, rgba(col, 1));
            gr.addColorStop(0.5, rgba(col, 0.5));
            gr.addColorStop(1, rgba(col, 0));
            ctx.fillStyle = gr;
            ctx.beginPath();
            ctx.arc(px, py, glow, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalAlpha = intensity * o.opacity;
            ctx.fillStyle = col;
            ctx.beginPath();
            ctx.arc(px, py, Math.max(size, 0.5), 0, Math.PI * 2);
            ctx.fill();
        }
        ctx.globalAlpha = 1;
    },
    /**
     * options: { count, maxDist, nodeSize, curveAmount } // node state persists on ctx._prismNodes between frames.
     */
    nodes(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const n = Math.floor(50 + o.density * 30);
        const maxD = Math.min(width, height) * (o.maxDist ?? 0.15);
        if (!ctx._prismNodes || ctx._prismNodes.length !== n) {
            ctx._prismNodes = Array.from({ length: n }, () => ({
                x: Math.random() * width,
                y: Math.random() * height,
                vx: (Math.random() - 0.5) * 0.3,
                vy: (Math.random() - 0.5) * 0.3,
                energy: Math.random(),
                phase: Math.random() * Math.PI * 2,
            }));
        }
        const nodes = ctx._prismNodes;
        const t = time * o.speed;
        nodes.forEach((nd) => {
            nd.vx += Math.sin(t * 2 + nd.phase) * 0.5 * 0.02;
            nd.vy += Math.cos(t * 1.7 + nd.phase) * 0.5 * 0.02;
            nd.vx *= 0.98;
            nd.vy *= 0.98;
            nd.x += nd.vx;
            nd.y += nd.vy;
            if (nd.x < 0) nd.x = width;
            if (nd.x > width) nd.x = 0;
            if (nd.y < 0) nd.y = height;
            if (nd.y > height) nd.y = 0;
            nd.energy =
                (Math.sin(t * 3 + nd.x * 0.01) +
                    Math.cos(t * 2.5 + nd.y * 0.01)) *
                    0.5 +
                0.5;
        });
        nodes.forEach((a) => {
            nodes.forEach((b) => {
                if (a === b) return;
                const dx = b.x - a.x,
                    dy = b.y - a.y;
                const d = Math.sqrt(dx * dx + dy * dy);
                if (d > maxD) return;
                const strength =
                    (1 - d / maxD) * (Math.sin(t * 5 + d * 0.02) * 0.5 + 0.5);
                if (strength < 0.3) return;
                const energy = (a.energy + b.energy) / 2;
                const col =
                    energy > 0.7
                        ? palette.accent
                        : energy > 0.4
                          ? palette.primary
                          : palette.secondary;
                ctx.save();
                ctx.globalAlpha = strength * 0.6 * energy * o.opacity;
                ctx.strokeStyle = col;
                ctx.lineWidth = 0.5 + strength * 2;
                ctx.shadowColor = col;
                ctx.shadowBlur = 8;
                const mx =
                    (a.x + b.x) / 2 +
                    Math.sin(t * 8 + d * 0.03) * (o.curveAmount ?? 30);
                const my =
                    (a.y + b.y) / 2 +
                    Math.cos(t * 6 + d * 0.03) * (o.curveAmount ?? 30);
                ctx.beginPath();
                ctx.moveTo(a.x, a.y);
                ctx.quadraticCurveTo(mx, my, b.x, b.y);
                ctx.stroke();
                ctx.restore();
            });
        });
        nodes.forEach((nd) => {
            const sz = (o.nodeSize ?? 2) + nd.energy * 4;
            const col = nd.energy > 0.6 ? palette.accent : palette.primary;
            ctx.save();
            ctx.globalAlpha = (0.8 + nd.energy * 0.2) * o.opacity;
            try {
                const ng = ctx.createRadialGradient(
                    nd.x,
                    nd.y,
                    0,
                    nd.x,
                    nd.y,
                    sz * 2,
                );
                ng.addColorStop(0, "#ffffff");
                ng.addColorStop(0.5, col);
                ng.addColorStop(1, rgba(col, 0));
                ctx.fillStyle = ng;
            } catch {
                ctx.fillStyle = col;
            }
            ctx.shadowColor = col;
            ctx.shadowBlur = 12;
            ctx.beginPath();
            ctx.arc(nd.x, nd.y, sz, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        });
    },
    /**
     * options: { count, cubeSize, perspectiveDist }
     */
    wireframes(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const n = Math.floor(8 * o.density);
        const t = time * o.speed;
        const VERTS = [
            [-1, -1, -1],
            [1, -1, -1],
            [1, 1, -1],
            [-1, 1, -1],
            [-1, -1, 1],
            [1, -1, 1],
            [1, 1, 1],
            [-1, 1, 1],
        ];
        const EDGES = [
            [0, 1],
            [1, 2],
            [2, 3],
            [3, 0],
            [4, 5],
            [5, 6],
            [6, 7],
            [7, 4],
            [0, 4],
            [1, 5],
            [2, 6],
            [3, 7],
        ];
        for (let i = 0; i < n; i++) {
            const it = t + i * 2.5;
            const ox =
                width * 0.2 + (i % 3) * width * 0.3 + Math.sin(it * 0.7) * 80;
            const oy =
                height * 0.2 +
                Math.floor(i / 3) * height * 0.25 +
                Math.cos(it * 0.9) * 60;
            const oz = Math.sin(it) * 100 + 200;
            const rx = it * 0.8,
                ry = it * 1.2,
                rz = it * 0.5;
            const sz = (o.cubeSize ?? 40) + Math.sin(it * 1.5) * 15;
            const persp = o.perspectiveDist ?? 500;
            const proj = VERTS.map(([x, y, z]) => {
                x *= sz;
                y *= sz;
                z *= sz;
                const cX = Math.cos(rx),
                    sX = Math.sin(rx),
                    cY = Math.cos(ry),
                    sY = Math.sin(ry),
                    cZ = Math.cos(rz),
                    sZ = Math.sin(rz);
                let ny = y * cX - z * sX,
                    nz = y * sX + z * cX;
                y = ny;
                z = nz;
                let nx = x * cY + z * sY;
                nz = -x * sY + z * cY;
                x = nx;
                z = nz;
                nx = x * cZ - y * sZ;
                ny = x * sZ + y * cZ;
                const sc = persp / (persp + nz + oz);
                return [ox + nx * sc, oy + ny * sc, sc];
            });
            EDGES.forEach(([a, b]) => {
                const [x1, y1, s1] = proj[a],
                    [x2, y2, s2] = proj[b];
                const avg = (s1 + s2) * 0.5;
                ctx.globalAlpha = o.opacity * avg * 0.6;
                ctx.strokeStyle =
                    i % 2 === 0 ? palette.primary : palette.accent;
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(x1, y1);
                ctx.lineTo(x2, y2);
                ctx.stroke();
                if (Math.sin(t * 0.005 + i + a + b) * 0.5 + 0.5 > 0.8) {
                    ctx.globalAlpha = o.opacity * 0.4;
                    ctx.strokeStyle = palette.secondary;
                    ctx.lineWidth = 3;
                    ctx.stroke();
                }
            });
            proj.forEach(([x, y, sc], j) => {
                const pulse = Math.sin(t * 0.008 + i + j) * 0.5 + 0.5;
                ctx.globalAlpha = o.opacity * sc * pulse * 0.8;
                ctx.fillStyle = palette.accent;
                ctx.beginPath();
                ctx.arc(x, y, 3 * sc, 0, Math.PI * 2);
                ctx.fill();
            });
        }
        ctx.globalAlpha = 1;
    },
    /**
     * options: { count, maxDepth, baseLength, color }
     */
    branches(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const n = Math.floor(8 * o.density);
        const maxD = o.maxDepth ?? 9;
        const t = time * o.speed;
        for (let i = 0; i < n; i++) {
            const rootX = (i * width) / (n + 1) + width / (n + 1);
            const rootY = height + Math.sin(t * o.speed + i) * 30;
            const tp = t + i * 2.3;
            function draw(x, y, angle, length, depth, energy) {
                if (depth > maxD || length < 8) return;
                const gp = Math.sin(tp + depth * 0.3) * 0.2 + 1;
                const len = length * gp;
                const ang = angle + Math.sin(tp + depth + x * 0.01) * 0.1;
                const ex = x + Math.cos(ang) * len;
                const ey = y - Math.sin(ang) * len;
                const col =
                    depth < 2
                        ? palette.primary
                        : depth < 5
                          ? palette.secondary
                          : palette.accent;
                const lw = Math.max(1, 6 - depth);
                ctx.globalAlpha = o.opacity * energy * 0.8;
                ctx.strokeStyle = col;
                ctx.lineWidth = lw;
                ctx.beginPath();
                ctx.moveTo(x, y);
                ctx.lineTo(ex, ey);
                ctx.stroke();
                if (depth % 2 === 0 && len > 12) {
                    const nx = x + Math.cos(ang) * len * 0.7,
                        ny = y - Math.sin(ang) * len * 0.7;
                    const na = Math.sin(tp * 2 + depth + i) * 0.5 + 0.5;
                    ctx.globalAlpha = o.opacity * energy * na;
                    ctx.fillStyle = palette.accent;
                    ctx.beginPath();
                    ctx.arc(nx, ny, 3 + na * 2, 0, Math.PI * 2);
                    ctx.fill();
                }
                if (len > 15) {
                    for (let b = 0; b < 2; b++) {
                        const ba =
                            angle +
                            (b - 0.5) * 0.7 +
                            Math.sin(tp + depth) * 0.2;
                        draw(
                            ex,
                            ey,
                            ba,
                            length * 0.75,
                            depth + 1,
                            energy * 0.85,
                        );
                    }
                }
            }
            draw(
                rootX,
                rootY,
                Math.PI / 2 + Math.sin(tp) * 0.2,
                (o.baseLength ?? 70) + Math.sin(tp * 0.8) * 25,
                0,
                1,
            );
        }
        ctx.globalAlpha = 1;
    },
    /**
     * options: { layers, basePetals, centerRadius }
     */
    mandala(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const n = Math.floor((o.layers ?? 6) * o.density);
        const t = time * o.speed;
        const cx = o.cx ?? width / 2;
        const cy = o.cy ?? height / 2;
        for (let layer = 0; layer < n; layer++) {
            const lp = t + layer * 0.8;
            const lr =
                (o.baseRadius ?? 50) + layer * 30 + Math.sin(lp * 0.7) * 20;
            const lrot = lp * (layer % 2 === 0 ? 1 : -1) * 0.3;
            const petals = (o.basePetals ?? 5) + layer * 2;
            for (let p = 0; p < petals; p++) {
                const pa = (p / petals) * Math.PI * 2 + lrot;
                const pp = lp + p * 0.2;
                const ps = 0.7 + Math.sin(pp * 1.5) * 0.5;
                const pr = lr * ps;
                const inner = pr * 0.3,
                    outer = pr * 0.8;
                const col = [
                    palette.primary,
                    palette.secondary,
                    palette.accent,
                ][Math.floor((pp + layer) % 3)];
                ctx.globalAlpha = o.opacity * (0.6 + Math.sin(pp * 2) * 0.4);
                ctx.beginPath();
                for (let pt = 0; pt <= 20; pt++) {
                    const pta =
                        pa +
                        (pt / 20) * (Math.PI / petals) -
                        Math.PI / (petals * 2);
                    const ptr =
                        inner +
                        (outer - inner) *
                            (0.5 + 0.5 * Math.sin((pt * Math.PI) / 10));
                    const wr = ptr * (1 + Math.sin(pp * 3 + pt * 0.3) * 0.2);
                    const x = cx + Math.cos(pta) * wr,
                        y = cy + Math.sin(pta) * wr;
                    pt === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                }
                ctx.closePath();
                ctx.strokeStyle = col;
                ctx.lineWidth = 1 + Math.sin(pp * 4);
                ctx.stroke();
                if (layer < 4) {
                    for (let s = 0; s < 3; s++) {
                        const sa = pa + (s - 1) * 0.2,
                            sr = pr * (0.4 + s * 0.1);
                        ctx.globalAlpha = o.opacity * 0.6;
                        ctx.fillStyle =
                            s % 2 === 0 ? palette.accent : palette.secondary;
                        ctx.beginPath();
                        ctx.arc(
                            cx + Math.cos(sa) * sr,
                            cy + Math.sin(sa) * sr,
                            2 + Math.sin(pp * 5 + s) * 2,
                            0,
                            Math.PI * 2,
                        );
                        ctx.fill();
                    }
                }
            }
        }
        ctx.globalAlpha = 1;
    },
    /**
     * options: { count, trailLength, color }
     */
    streams(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const n = Math.floor(25 * o.density);
        const t = time * o.speed;
        for (let i = 0; i < n; i++) {
            const phase = (t * 0.04 + i * 0.3) % 1;
            const pt = i % 4;
            let sx, sy, px, py;
            switch (pt) {
                case 0:
                    sx = phase * width;
                    sy = height * 0.4 + Math.sin(phase * Math.PI * 3 + i) * 80;
                    px = sx - 12;
                    py =
                        height * 0.4 +
                        Math.sin((phase - 0.02) * Math.PI * 3 + i) * 80;
                    break;
                case 1:
                    sx = width * 0.3 + Math.cos(phase * Math.PI * 2 + i) * 60;
                    sy = phase * height;
                    px = sx - 12;
                    py = sy - 12;
                    break;
                case 2: {
                    const a = phase * Math.PI * 6 + i,
                        r = 100 + phase * 150;
                    sx = width / 2 + Math.cos(a) * r;
                    sy = height / 2 + Math.sin(a) * r;
                    const pa = (phase - 0.02) * Math.PI * 6 + i;
                    const pr = 100 + (phase - 0.02) * 150;
                    px = width / 2 + Math.cos(pa) * pr;
                    py = height / 2 + Math.sin(pa) * pr;
                    break;
                }
                default:
                    sx = phase * width;
                    sy = height * 0.6 + Math.sin(phase * Math.PI * 4) * 100;
                    px = sx - 15;
                    py = sy;
            }
            const energy = Math.sin(t * 0.012 + i * 0.7) * 0.5 + 0.5;
            const size = 2 + Math.sin(t * 0.008 + i) * 2;
            ctx.globalAlpha = o.opacity * energy * 0.9;
            ctx.fillStyle = i % 2 === 0 ? palette.primary : palette.accent;
            ctx.beginPath();
            ctx.arc(sx, sy, Math.max(size, 0.5), 0, Math.PI * 2);
            ctx.fill();
            for (let tr = 1; tr <= (o.trailLength ?? 6); tr++) {
                const tp2 = tr / (o.trailLength ?? 6);
                ctx.globalAlpha = o.opacity * (1 - tp2) * energy * 0.6;
                ctx.fillStyle = palette.secondary;
                ctx.beginPath();
                ctx.arc(
                    sx + (px - sx) * tp2,
                    sy + (py - sy) * tp2,
                    Math.max(size * (1 - tp2 * 0.5), 0.5),
                    0,
                    Math.PI * 2,
                );
                ctx.fill();
            }
        }
        ctx.globalAlpha = 1;
    },
    /**
     * options: { threshold, color }
     */
    glitch(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const t = time * o.speed;
        if (Math.sin(t * 0.003) * 0.5 + 0.5 < (o.threshold ?? 0.95)) return;
        const n = Math.floor(5 * o.density);
        ctx.globalCompositeOperation = "screen";
        for (let g = 0; g < n; g++) {
            ctx.globalAlpha = o.opacity * 0.3;
            ctx.fillStyle = g % 2 === 0 ? palette.primary : palette.accent;
            ctx.fillRect(
                (g * 234.5) % width,
                (g * 123.7) % height,
                50 + ((g * 43) % 100),
                3 + ((g * 17) % 8),
            );
        }
        ctx.globalCompositeOperation = "source-over";
        ctx.globalAlpha = 1;
    },
    /**
     * options: { color, innerRadius, outerRadius }
     */
    vignette(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const cx = width / 2,
            cy = height / 2;
        const r = Math.max(width, height);
        const g = ctx.createRadialGradient(
            cx,
            cy,
            r * (o.innerRadius ?? 0.3),
            cx,
            cy,
            r * (o.outerRadius ?? 0.9),
        );
        g.addColorStop(0, rgba(palette.background, 0));
        g.addColorStop(1, rgba(palette.background, o.opacity * 0.7));
        ctx.fillStyle = g;
        ctx.globalAlpha = 1;
        ctx.fillRect(0, 0, width, height);
    },
    /**
     * options: { spacing }
     */
    foam(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const t = time * o.speed;
        const spacing = o.spacing ?? 25;
        const cx = width / 2;
        const cy = height / 2;
        ctx.globalAlpha = o.opacity;
        for (let x = 0; x <= width + spacing; x += spacing) {
            for (let y = 0; y <= height + spacing; y += spacing) {
                const dx = x - cx;
                const dy = y - cy;
                const dist = Math.sqrt(dx * dx + dy * dy);
                const angle = Math.atan2(dy, dx);
                const wave1 = Math.sin(dist * 0.02 - t * 3 + angle * 2);
                const wave2 = Math.cos(dist * 0.01 + t * 1.5 - angle);
                const interference = (wave1 + wave2) / 2;
                if (interference > 0.4) {
                    const size = (interference - 0.4) * 6;
                    ctx.fillStyle =
                        interference > 0.8 ? palette.accent : palette.secondary;
                    ctx.beginPath();
                    ctx.arc(x, y, size, 0, Math.PI * 2);
                    ctx.fill();
                } else {
                    ctx.fillStyle = palette.primary;
                    ctx.globalAlpha = o.opacity * 0.2;
                    ctx.fillRect(x, y, 1, 1);
                    ctx.globalAlpha = o.opacity;
                }
            }
        }
    },
    /**
     * options: { points, scale }
     */
    hyperstring(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const t = time * o.speed;
        const cx = width / 2;
        const cy = height / 2;
        const numPoints = Math.floor(1000 * o.density);
        const scale = Math.min(width, height) * (o.scale ?? 0.35);
        ctx.lineWidth = 2.0;
        ctx.lineJoin = "round";
        ctx.beginPath();
        for (let i = 0; i <= numPoints; i++) {
            const phi = (i / numPoints) * Math.PI * 2;
            const p = 3 + Math.sin(t * 0.2) * 2.5;
            const q = 7 + Math.cos(t * 0.15) * 3;
            const r = Math.cos(q * phi) + 2;
            let x = r * Math.cos(p * phi);
            let y = r * Math.sin(p * phi);
            let z = -Math.sin(q * phi);
            x += Math.sin(t + y * 2) * 0.3;
            y += Math.cos(t + z * 2) * 0.3;
            const rotX = t * 0.3;
            const rotY = t * 0.5;
            let finalY = Math.cos(rotX) * y - Math.sin(rotX) * z;
            let finalZ = Math.sin(rotX) * y + Math.cos(rotX) * z;
            let finalX = Math.cos(rotY) * x + Math.sin(rotY) * finalZ;
            finalZ = -Math.sin(rotY) * x + Math.cos(rotY) * finalZ;
            const persp = 4;
            const projScale = persp / (persp + finalZ);
            const px = cx + finalX * projScale * scale;
            const py = cy + finalY * projScale * scale;
            if (i === 0) ctx.moveTo(px, py);
            else ctx.lineTo(px, py);
        }
        const g = ctx.createLinearGradient(
            cx - scale,
            cy - scale,
            cx + scale,
            cy + scale,
        );
        g.addColorStop(0, palette.primary);
        g.addColorStop(0.5, palette.secondary);
        g.addColorStop(1, palette.accent);
        ctx.globalAlpha = o.opacity;
        ctx.strokeStyle = g;
        ctx.shadowColor = palette.accent;
        ctx.shadowBlur = 15;
        ctx.stroke();
        ctx.shadowBlur = 0;
        ctx.globalAlpha = 1;
    },
    /**
     * options: { resolution, thickness, color, amplitude }
     */
    topography(ctx, width, height, time, palette, incoming = {}) {
        const o = opts(incoming);
        const t = time * o.speed;
        const lines = Math.floor(40 * o.density);
        const steps = Math.floor(100 * (o.resolution ?? 1.0));
        ctx.lineWidth = o.thickness ?? 1;
        ctx.globalAlpha = o.opacity;
        ctx.strokeStyle = palette[o.color ?? "secondary"] || palette.secondary;
        for (let i = 0; i < lines; i++) {
            ctx.beginPath();
            const yBase = (i / lines) * height;
            for (let j = 0; j <= steps; j++) {
                const x = (j / steps) * width;
                const amplitude = o.amplitude ?? 50;
                const wave1 =
                    Math.sin(x * 0.01 + t * 0.5 + i * 0.1) *
                    Math.cos(x * 0.02 - t * 0.2) *
                    amplitude;
                const wave2 = Math.sin(x * 0.005 + t * 0.1) * (amplitude * 1.5);
                const y = yBase + wave1 + wave2;
                if (j === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
    },
};

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
        { fn: primitives.glitch, options: { opacity: 0.8 } },
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
        { fn: primitives.glitch, options: { opacity: 0.6, threshold: 0.98 } },
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
        { fn: primitives.glitch },
        { fn: primitives.vignette },
    ],
};

/**
 * @param {Array<{fn: Function, options?: object}>} layers
 * @returns {Function} composed render function
 */
export function compose(layers) {
    return function render(
        ctx,
        width,
        height,
        time,
        palette,
        globalOptions = {},
    ) {
        layers.forEach(({ fn, options: localOptions = {} }) => {
            ctx.save();
            fn(ctx, width, height, time, palette, {
                ...globalOptions,
                ...localOptions,
            });
            ctx.restore();
        });
    };
}

let _raf = null;
let _stop = false;
const DEFAULT_PALETTE = {
    primary: "#00ffff",
    secondary: "#ff00ff",
    accent: "#ffff00",
    background: "#0a0a0f",
};

/**
 * Start animating a composed scene onto a canvas.
 * @param {HTMLCanvasElement} canvas
 * @param {Function} scene
 * @param {object}   palette
 * @param {object}   globalOptions
 */
export function loop(
    canvas,
    scene,
    palette = DEFAULT_PALETTE,
    globalOptions = {},
) {
    stop();
    _stop = false;
    const render = typeof scene === "function" ? scene : compose(scene);
    const dpr = window.devicePixelRatio || 1;
    const fps = globalOptions.fps ?? 30;

    function drawFrame(ts) {
        const w = parseInt(canvas.style.width);
        const h = parseInt(canvas.style.height);
        const ctx = canvas.getContext("2d");
        ctx.save();
        ctx.scale(dpr, dpr);
        ctx.clearRect(0, 0, w, h);
        render(ctx, w, h, ts / 1000, palette, globalOptions);
        ctx.restore();
    }

    function setSize() {
        const parent = canvas.parentElement ?? document.body;
        const w =
            parent === document.body ? window.innerWidth : parent.offsetWidth;
        const h =
            parent === document.body ? window.innerHeight : parent.offsetHeight;
        canvas.style.width = w + "px";
        canvas.style.height = h + "px";
        canvas.width = Math.round(w * dpr);
        canvas.height = Math.round(h * dpr);
        if (fps === 0) drawFrame(0);
    }
    setSize();
    const ro =
        typeof ResizeObserver !== "undefined"
            ? new ResizeObserver(setSize)
            : null;
    ro?.observe(canvas.parentElement ?? document.body);

    if (fps === 0) {
        drawFrame(0);
        return;
    }

    const interval = 1000 / fps;
    let last = 0;
    function frame(ts) {
        if (_stop) {
            ro?.disconnect();
            return;
        }
        _raf = requestAnimationFrame(frame);
        if (ts - last < interval) return;
        last = ts;
        drawFrame(ts);
    }
    _raf = requestAnimationFrame(frame);
}

export function stop() {
    _stop = true;
    if (_raf) {
        cancelAnimationFrame(_raf);
        _raf = null;
    }
}

export function renderStatic(
    canvas,
    scene,
    palette = DEFAULT_PALETTE,
    globalOptions = {},
) {
    const render = typeof scene === "function" ? scene : compose(scene);
    const dpr = window.devicePixelRatio || 1;
    const parent = canvas.parentElement ?? document.body;
    const w = parent === document.body ? window.innerWidth : parent.offsetWidth;
    const h =
        parent === document.body ? window.innerHeight : parent.offsetHeight;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    canvas.style.width = w + "px";
    canvas.style.height = h + "px";
    const ctx = canvas.getContext("2d");
    ctx.scale(dpr, dpr);
    render(ctx, w, h, 0, palette, globalOptions);
}

const COMPOSABLE = [
    {
        name: "grid",
        fn: primitives.grid,
        weight: 3,
        options: () => ({
            spacing: rand(60, 140),
            warpAmount: rand(2, 10),
            opacity: rand(0.3, 0.7),
        }),
    },
    {
        name: "scanlines",
        fn: primitives.scanlines,
        weight: 2,
        options: () => ({ spacing: rand(3, 8), opacity: rand(0.4, 0.9) }),
    },
    {
        name: "particles",
        fn: primitives.particles,
        weight: 4,
        options: () => ({
            density: rand(0.6, 2.2),
            minRadius: rand(40, 160),
            maxRadius: rand(200, 500),
        }),
    },
    {
        name: "nodes",
        fn: primitives.nodes,
        weight: 4,
        options: () => ({ density: rand(0.6, 1.8), curveAmount: rand(15, 60) }),
    },
    {
        name: "wireframes",
        fn: primitives.wireframes,
        weight: 3,
        options: () => ({ density: rand(0.4, 1.2), cubeSize: rand(25, 60) }),
    },
    {
        name: "branches",
        fn: primitives.branches,
        weight: 2,
        options: () => ({ density: rand(0.5, 1.2), baseLength: rand(50, 100) }),
    },
    {
        name: "mandala",
        fn: primitives.mandala,
        weight: 3,
        options: () => ({
            layers: Math.floor(rand(3, 8)),
            basePetals: Math.floor(rand(4, 9)),
        }),
    },
    {
        name: "streams",
        fn: primitives.streams,
        weight: 3,
        options: () => ({
            density: rand(0.5, 1.5),
            trailLength: Math.floor(rand(4, 10)),
        }),
    },
    {
        name: "glitch",
        fn: primitives.glitch,
        weight: 1,
        options: () => ({
            threshold: rand(0.93, 0.99),
            opacity: rand(0.5, 1.0),
        }),
    },
    {
        name: "hyperstring",
        fn: primitives.hyperstring,
        weight: 2,
        options: () => ({ density: rand(0.6, 1.4), scale: rand(0.25, 0.45) }),
    },
    {
        name: "topography",
        fn: primitives.topography,
        weight: 2,
        options: () => ({ density: rand(0.5, 1.2), amplitude: rand(30, 80) }),
    },
];

export function rand(min, max) {
    return Math.random() * (max - min) + min;
}

export function weightedSample(pool, count) {
    const items = [...pool];
    const picked = [];
    for (let i = 0; i < Math.min(count, items.length); i++) {
        const totalWeight = items.reduce((s, p) => s + p.weight, 0);
        let r = Math.random() * totalWeight;
        const idx = items.findIndex((p) => (r -= p.weight) < 0) ?? 0;
        picked.push(items.splice(Math.max(idx, 0), 1)[0]);
    }
    return picked;
}

let currentRecipe = [];

export function updateRecipeDisplay() {
    const el = document.getElementById("recipe-display");
    if (!el) return;
    const names = currentRecipe.map((p) => p.name.toUpperCase());
    el.textContent = "[ " + names.join(" + ") + " ]";
}

export function generateRandom(canvas, palette, systemState) {
    const count = Math.floor(rand(2, 5));
    const picked = weightedSample(COMPOSABLE, count);
    currentRecipe = picked;
    const layers = [
        { fn: primitives.background },
        ...picked.map((p) => ({ fn: p.fn, options: p.options() })),
        { fn: primitives.vignette, options: { opacity: rand(0.4, 0.8) } },
    ];
    stop();
    loop(canvas, compose(layers), palette, systemState);
    updateRecipeDisplay();
}

export function bindGenerator(canvas, palette, systemState) {
    const genBtn = document.getElementById("generate-btn");
    if (genBtn) {
        genBtn.onclick = () => generateRandom(canvas, palette, systemState);
        updateRecipeDisplay();
    }
}
