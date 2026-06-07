/* @substrate
{
  "name": "heap-corruption",
  "label": "HEAP CORRUPTION",
  "order": 480,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "gridSize",          "slot": 0, "default": 21.0,  "type": "number" },
    { "key": "tearRows",          "slot": 1, "default": 26.0,  "type": "number" },
    { "key": "tearRate",          "slot": 2, "default": 7.0,   "type": "number" },
    { "key": "memcpyRate",        "slot": 3, "default": 1.6,   "type": "number" },
    { "key": "sweepSpeed",        "slot": 4, "default": 0.13,  "type": "number" },
    { "key": "chromaticAberration", "slot": 5, "default": 1.0, "type": "number" },
    { "key": "corruption",        "slot": 6, "default": 1.0,   "type": "number" },
    { "key": "color",             "slot": 7, "default": "primary", "type": "color" }
  ]
}
*/

// Heap Corruption, adapted from Tor Ringstad's shader.
// Copyright Tor Ringstad, 2026.
// Licensed under CC BY 4.0: https://creativecommons.org/licenses/by/4.0/
// More info: https://www.pvv.ntnu.no/~torhr/shaders/
//
// The live allocator grid, corruption field, row tears, memcpy glitches,
// chromatic aberration, and scan treatment are kept as separate stages so
// the generic Substrate speed, density, opacity, and theme controls remain
// useful without changing the composition of the original effect.

struct HcCellResult {
  color: vec3<f32>,
  corruption: f32,
};

fn hcHash12(pIn: vec2<f32>) -> f32 {
  var p = fract(pIn * vec2<f32>(123.34, 456.21));
  p += vec2<f32>(dot(p, p + vec2<f32>(45.32)));
  return fract(p.x * p.y);
}

fn hcHash11(n: f32) -> f32 {
  return fract(sin(n * 127.1) * 43758.5453);
}

fn hcValueNoise(p: vec2<f32>) -> f32 {
  let i = floor(p);
  var f = fract(p);
  f = f * f * (vec2<f32>(3.0) - 2.0 * f);

  let a = hcHash12(i);
  let b = hcHash12(i + vec2<f32>(1.0, 0.0));
  let c = hcHash12(i + vec2<f32>(0.0, 1.0));
  let d = hcHash12(i + vec2<f32>(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

fn hcPressure(time: f32) -> f32 {
  let breathe = 0.5 + 0.5 * sin(time * 0.45);
  let slot = floor(time * 0.8);
  let phase = fract(time * 0.8);
  let spike = step(0.72, hcHash11(slot)) *
    smoothstep(0.0, 0.08, phase) *
    (1.0 - smoothstep(0.55, 1.0, phase));
  return clamp(0.25 + 0.45 * breathe + 0.9 * spike, 0.0, 1.4);
}

fn hcCorruption(p: vec2<f32>, time: f32, strength: f32) -> f32 {
  let pressure = hcPressure(time);
  var noise = hcValueNoise(p * 2.3 + vec2<f32>(time * 0.18, -time * 0.11));
  noise = 0.65 * noise + 0.35 * hcValueNoise(p * 6.1 - vec2<f32>(time * 0.07, time * 0.23));

  let epicenter = vec2<f32>(
    0.9 + 0.55 * sin(time * 0.21),
    0.5 + 0.42 * cos(time * 0.16)
  );
  let blob = 1.0 - smoothstep(0.05, 0.75, distance(p, epicenter));
  let amount = max(strength, 0.0);

  return clamp(
    smoothstep(
      0.72 - 0.35 * pressure * amount,
      0.95,
      noise + 0.35 * blob * pressure * amount
    ),
    0.0,
    1.0
  );
}

fn hcDisplace(
  pIn: vec2<f32>,
  time: f32,
  tearRows: f32,
  tearRate: f32,
  memcpyRate: f32
) -> vec2<f32> {
  var p = pIn;
  let pressure = hcPressure(time);

  let row = floor(p.y * max(tearRows, 1.0));
  let rowRandom = hcHash12(vec2<f32>(row, floor(time * max(tearRate, 0.0))));
  let tearOn = step(0.965 - 0.12 * pressure, rowRandom);
  p.x += tearOn * (rowRandom - 0.5) * 0.7 * pressure;

  let slot = floor(time * max(memcpyRate, 0.0));
  let memcpyPhase = fract(time * max(memcpyRate, 0.0));
  let go = step(0.6, hcHash11(slot + 13.7)) * step(memcpyPhase, 0.4);
  let blockMin = vec2<f32>(hcHash11(slot + 1.1) * 1.4, hcHash11(slot + 2.2) * 0.8);
  let blockSize = vec2<f32>(
    0.25 + 0.5 * hcHash11(slot + 3.3),
    0.06 + 0.18 * hcHash11(slot + 4.4)
  );
  let inBlock = step(blockMin.x, p.x) *
    step(p.x, blockMin.x + blockSize.x) *
    step(blockMin.y, p.y) *
    step(p.y, blockMin.y + blockSize.y);

  p += go * inBlock * (
    vec2<f32>(hcHash11(slot + 5.5), hcHash11(slot + 6.6)) - vec2<f32>(0.5)
  ) * 0.9;
  return p;
}

fn hcCells(
  p: vec2<f32>,
  time: f32,
  gridSize: f32,
  corruptionStrength: f32,
  liveColorBase: vec3<f32>
) -> HcCellResult {
  let corruption = hcCorruption(p, time, corruptionStrength);
  let grid = p * max(gridSize, 1.0);
  let id = floor(grid);
  let local = fract(grid);

  // Healthy cells hold a stable value; corrupted ones reroll rapidly.
  let flick = floor(time * (2.0 + 26.0 * corruption));
  let value = hcHash12(id + flick * 0.1731 * step(0.18, corruption));
  let chunk = hcHash12(floor(id / vec2<f32>(5.0, 3.0)));

  let padMin = vec2<f32>(0.16, 0.14);
  let padMax = vec2<f32>(0.84, 0.86);
  let inPad = step(padMin.x, local.x) * step(local.x, padMax.x) *
    step(padMin.y, local.y) * step(local.y, padMax.y);
  let sub = floor((local - padMin) / (padMax - padMin) * vec2<f32>(3.0, 4.0));
  let bit = step(
    0.62 - 0.34 * value,
    hcHash12(id * 3.17 + sub * vec2<f32>(0.71, 1.33) + flick * 0.031)
  );
  let glyph = bit * inPad;

  let liveLow = mix(vec3<f32>(0.03, 0.22, 0.19), liveColorBase * 0.65, 0.55);
  let liveHigh = mix(vec3<f32>(0.45, 0.95, 0.72), liveColorBase, 0.55);
  let live = mix(liveLow, liveHigh, value) * (0.75 + 0.5 * chunk);

  let rotLow = mix(vec3<f32>(0.95, 0.10, 0.48), g.secondary.rgb, 0.55);
  let rotHigh = mix(vec3<f32>(1.00, 0.55, 0.12), g.accent.rgb, 0.55);
  let rot = mix(rotLow, rotHigh, hcHash12(id + 7.7 + flick * 0.07));

  let sick = smoothstep(0.15, 0.65, corruption);
  let ink = mix(live, rot, sick);
  var color = ink * (0.10 + 1.05 * glyph);

  let solid = step(0.72, corruption) * step(0.55, hcHash12(id + flick + 3.3));
  color = mix(color, rot * 1.15, solid * 0.9);

  let edgeDistance = min(local, vec2<f32>(1.0) - local);
  let boundary = 1.0 - smoothstep(0.0, 0.06, min(edgeDistance.x, edgeDistance.y));
  color += boundary * mix(vec3<f32>(0.02, 0.06, 0.06), vec3<f32>(0.10, 0.02, 0.05), sick) * 2.0;

  let freePages = 1.0 - smoothstep(0.0, 0.35, hcValueNoise(id * 0.13 + vec2<f32>(4.2)));
  color *= 1.0 - 0.55 * freePages * (1.0 - sick);

  return HcCellResult(color, corruption);
}

fn hcScene(
  p: vec2<f32>,
  time: f32,
  gridSize: f32,
  tearRows: f32,
  tearRate: f32,
  memcpyRate: f32,
  sweepSpeed: f32,
  corruptionStrength: f32,
  liveColorBase: vec3<f32>
) -> vec3<f32> {
  let displaced = hcDisplace(p, time, tearRows, tearRate, memcpyRate);
  let cell = hcCells(displaced, time, gridSize, corruptionStrength, liveColorBase);

  let sweep = fract(displaced.y * 0.5 - time * sweepSpeed);
  return cell.color + vec3<f32>(0.06, 0.16, 0.13) *
    (1.0 - smoothstep(0.0, 0.12, sweep)) * (1.0 - cell.corruption);
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let speed = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.05);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let gridSize = max(l.p1.x, 1.0) * pow(density, 0.5);
  let tearRows = max(l.p1.y, 1.0);
  let tearRate = max(l.p1.z, 0.0);
  let memcpyRate = max(l.p1.w, 0.0);
  let sweepSpeed = max(l.p2.x, 0.0);
  let chromaticAberration = max(l.p2.y, 0.0);
  let corruptionStrength = max(l.p2.z, 0.0);
  let liveColor = palette(i32(l.p2.w));

  let time = g.viewport.w * speed;
  let uv = fragCoord / resolution.y;
  let baseCorruption = hcCorruption(uv, time, corruptionStrength);
  let chromaticOffset = (0.002 + 0.010 * baseCorruption * hcPressure(time)) * chromaticAberration;

  let red = hcScene(
    uv + vec2<f32>(chromaticOffset, 0.0),
    time, gridSize, tearRows, tearRate, memcpyRate, sweepSpeed,
    corruptionStrength, liveColor
  ).r;
  let green = hcScene(
    uv,
    time, gridSize, tearRows, tearRate, memcpyRate, sweepSpeed,
    corruptionStrength, liveColor
  ).g;
  let blue = hcScene(
    uv - vec2<f32>(chromaticOffset, 0.0),
    time, gridSize, tearRows, tearRate, memcpyRate, sweepSpeed,
    corruptionStrength, liveColor
  ).b;
  var color = vec3<f32>(red, green, blue);

  color *= 0.92 + 0.08 * sin(fragCoord.y * PI * 0.5);

  let normalized = fragCoord / resolution;
  let vignetteBase = max(
    16.0 * normalized.x * normalized.y * (1.0 - normalized.x) * (1.0 - normalized.y),
    0.0
  );
  color *= 0.55 + 0.45 * pow(vignetteBase, 0.28);
  color *= 0.97 + 0.03 * hcHash11(floor(time * 60.0));

  color = color / (vec3<f32>(1.0) + 0.35 * color);
  color = pow(max(color, vec3<f32>(0.0)), vec3<f32>(0.92));

  return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), opacity);
}
