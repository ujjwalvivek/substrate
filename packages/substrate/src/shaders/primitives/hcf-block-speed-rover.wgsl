/* @substrate
{
  "name": "hcf-block-speed-rover",
  "label": "HCF BLOCK SPEED ROVER",
  "order": 420,
  "modes": ["feedback"],
  "blend": "source-over",
  "feedback": { "format": "rgba16float" },
  "params": []
}
*/

// Port of HCF Block Speed Rover by Chimel.
//
// This primitive keeps the supplied two-pass design:
//   - primitiveFeedback updates the rover state in the persistent buffer.
//   - primitiveFeedbackPresent renders the Image pass from that state.
//
// The original shader uses iChannel0, iTime, and iFrame. The feedback texture,
// shared globals, and layer controls provide their Substrate equivalents.

const HCF_TRAIL_FADE: f32 = 0.98;
const HCF_MASS_FADE: f32 = 1.0;
const HCF_MIN_SPEED: f32 = 1.0;
const HCF_MAX_SPEED: f32 = 3.95;
const HCF_PHASE_RATE: f32 = 0.13;
const HCF_NEIGHBOR_RADIUS: i32 = 7;

fn hcfCanvasCells() -> vec2<f32> {
  return vec2<f32>(320.0, 200.0);
}

fn hcfGrid(density: f32) -> vec2<f32> {
  // Keep the source's 320x200 model at the default while allowing the
  // generic density control to make the logical grid only gently finer/coarser.
  let d = sqrt(clamp(density, 0.1, 4.0));
  return hcfCanvasCells() * (0.82 + 0.18 * d);
}

fn hcfHash11(p: f32) -> f32 {
  return fract(sin(p * 127.1) * 43758.5453123);
}

fn hcfHash21(p: vec2<f32>) -> f32 {
  return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453123);
}

fn hcfRectMask(p: vec2<f32>, r: vec4<f32>) -> f32 {
  let a = step(r.xy, p);
  let b = step(p, r.zw);
  return a.x * a.y * b.x * b.y;
}

fn hcfBgValue(uv: vec2<f32>, time: f32) -> f32 {
  let cells = hcfCanvasCells();
  let q = floor(uv * cells) / cells;

  var band = 0.18 + 0.48 * smoothstep(0.0, 1.0, q.x);
  band += 0.12 * sin((q.y * 7.0 + floor(time * 0.55) * 0.21) * TAU);
  band += 0.08 * sin((q.y * 23.0 - time * 0.11) * TAU);

  band += 0.32 * smoothstep(0.50, 0.97, q.x);
  band += 0.20 * hcfRectMask(q, vec4<f32>(0.62, 0.17, 0.95, 0.74));
  band += 0.14 * hcfRectMask(q, vec4<f32>(0.58, 0.00, 1.00, 0.22));
  band += 0.11 * hcfRectMask(q, vec4<f32>(0.45, 0.70, 0.86, 0.98));

  band -= 0.48 * hcfRectMask(q, vec4<f32>(0.00, 0.59, 0.38, 0.77));
  band -= 0.32 * hcfRectMask(q, vec4<f32>(0.22, 0.47, 0.56, 0.63));
  band -= 0.38 * hcfRectMask(q, vec4<f32>(0.00, 0.16, 0.24, 0.35));
  band -= 0.22 * hcfRectMask(q, vec4<f32>(0.33, 0.24, 0.52, 0.44));

  let block = floor(q * vec2<f32>(28.0, 17.0));
  let h = hcfHash21(block + floor(time * 1.3));
  let fragment = step(0.72, h) * (hcfHash21(block + 19.7) - 0.5);
  band += fragment * 0.34;

  let scan = step(
    0.985,
    hcfHash21(vec2<f32>(floor(q.y * 210.0), floor(time * 5.0)))
  );
  band += scan * 0.42;

  let darkScan = step(
    0.990,
    hcfHash21(vec2<f32>(floor(q.y * 170.0) + 44.0, floor(time * 4.0)))
  );
  band -= darkScan * 0.50;

  var streak = 0.0;
  for (var i: i32 = 0; i < 18; i = i + 1) {
    let fi = f32(i);
    let y = hcfHash11(fi + 6.0) * 0.92 + 0.04;
    let x0 = hcfHash11(fi + 12.0) * 0.88;
    let len = 0.05 + hcfHash11(fi + 33.0) * 0.25;
    let th = 0.0016 + hcfHash11(fi + 57.0) * 0.0030;
    let drift = fract(time * (0.015 + hcfHash11(fi) * 0.035) + hcfHash11(fi + 91.0));
    let x = fract(q.x + drift * 0.035);

    streak += (1.0 - smoothstep(0.0, th, abs(q.y - y))) *
      hcfRectMask(vec2<f32>(x, q.y), vec4<f32>(x0, 0.0, min(x0 + len, 0.995), 1.0));
  }

  band += streak * 0.42;
  return clamp(band, 0.0, 1.0);
}

fn hcfWrapCell(cell: vec2<f32>, grid: vec2<f32>) -> vec2<f32> {
  return vec2<f32>(
    modp(modp(cell.x, grid.x) + grid.x, grid.x),
    modp(modp(cell.y, grid.y) + grid.y, grid.y)
  );
}

fn hcfEncodeOffset(offset: vec2<f32>) -> f32 {
  // Store two normalized 8-bit components in one float channel. This is
  // portable across the rgba16float feedback target and avoids GLSL packing
  // intrinsics that are not available in every WGSL implementation.
  let q = floor(clamp(offset + vec2<f32>(0.5), vec2<f32>(0.0), vec2<f32>(1.0)) * 255.0 + 0.5);
  return (q.x * 256.0 + q.y) / 65535.0;
}

fn hcfDecodeOffset(encoded: f32) -> vec2<f32> {
  let packed = floor(clamp(encoded, 0.0, 1.0) * 65535.0 + 0.5);
  let x = floor(packed / 256.0);
  let y = packed - x * 256.0;
  return vec2<f32>(x, y) / 255.0 - vec2<f32>(0.5);
}

fn hcfGetRover(cell: vec2<f32>, grid: vec2<f32>) -> vec4<f32> {
  let wrapped = hcfWrapCell(cell, grid);
  return textureSample(feedbackTexture, feedbackSampler, (wrapped + vec2<f32>(0.5)) / grid);
}

fn hcfSameCell(a: vec2<f32>, b: vec2<f32>) -> bool {
  return i32(a.x) == i32(b.x) && i32(a.y) == i32(b.y);
}

fn hcfLocalSpeed(pos: vec2<f32>, grid: vec2<f32>, time: f32) -> f32 {
  let uv = (hcfWrapCell(pos, grid) + vec2<f32>(0.5)) / grid;
  let value = hcfBgValue(uv, time);

  var t = pow(smoothstep(0.10, 0.92, value), 1.35);
  let stepped = floor(t * 5.0) / 5.0;
  t = mix(t, stepped, 0.45);

  return mix(HCF_MIN_SPEED, HCF_MAX_SPEED, t);
}

fn primitiveFeedback(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let speedControl = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.1);
  let grid = hcfGrid(density);
  let time = g.viewport.w * speedControl;
  let cell = floor(fragCoord / resolution * grid);

  let oldHere = hcfGetRover(cell, grid);
  var outMass = 0.0;
  var outPos = vec2<f32>(0.0);
  var outPhase = 0.0;
  var outTrail = oldHere.a * HCF_TRAIL_FADE;

  for (var y: i32 = -HCF_NEIGHBOR_RADIUS; y <= HCF_NEIGHBOR_RADIUS; y = y + 1) {
    for (var x: i32 = -HCF_NEIGHBOR_RADIUS; x <= HCF_NEIGHBOR_RADIUS; x = x + 1) {
      let nCell = cell + vec2<f32>(f32(x), f32(y));
      let packet = hcfGetRover(nCell, grid);
      let mass = packet.r;

      if (mass > 0.0001) {
        let oldOffset = hcfDecodeOffset(packet.g);
        let oldPos = nCell + oldOffset;
        let roverSpeed = hcfLocalSpeed(oldPos, grid, time);
        let yWobble = sin(time * 0.85 + oldPos.x * 0.045) * 0.045;
        let newPos = oldPos + vec2<f32>(roverSpeed, yWobble);

        let targetCell = hcfWrapCell(floor(newPos + vec2<f32>(0.5)), grid);
        if (hcfSameCell(targetCell, cell)) {
          outMass += mass;
          outPos += newPos * mass;
          outPhase += fract(packet.b + roverSpeed * HCF_PHASE_RATE) * mass;
          outTrail = max(outTrail, mass);
        }
      }
    }
  }

  var state = vec4<f32>(
    0.0,
    hcfEncodeOffset(vec2<f32>(0.0)),
    0.0,
    clamp(outTrail, 0.0, 1.0)
  );

  if (outMass > 0.000001) {
    outPos /= outMass;
    outPhase /= outMass;

    let wrappedPos = hcfWrapCell(outPos, grid);
    let centerCell = floor(wrappedPos + vec2<f32>(0.5));
    let offset = clamp(wrappedPos - centerCell, vec2<f32>(-0.5), vec2<f32>(0.5));

    state = vec4<f32>(
      clamp(outMass * HCF_MASS_FADE, 0.0, 1.0),
      hcfEncodeOffset(offset),
      fract(outPhase),
      clamp(outTrail, 0.0, 1.0)
    );
  }

  if (g.info.y == 0.0) {
    let startCell = vec2<f32>(20.0, grid.y * 0.50);
    if (distance(cell, startCell) < 0.85) {
      state = vec4<f32>(1.0, hcfEncodeOffset(vec2<f32>(0.0)), 0.0, 1.0);
    } else {
      state = vec4<f32>(0.0, hcfEncodeOffset(vec2<f32>(0.0)), 0.0, 0.0);
    }
  }

  return state;
}

fn hcfPalette(valueIn: f32) -> vec3<f32> {
  let value = clamp(valueIn, 0.0, 1.0);
  var color = mix(g.background.rgb, g.primary.rgb, smoothstep(0.00, 0.20, value));
  color = mix(color, g.secondary.rgb, smoothstep(0.15, 0.48, value));
  color = mix(color, g.accent.rgb, smoothstep(0.42, 0.78, value));
  color = mix(color, vec3<f32>(1.0), smoothstep(0.78, 1.00, value) * 0.35);
  return color;
}

fn hcfBackgroundColor(uv: vec2<f32>, time: f32) -> vec3<f32> {
  let value = hcfBgValue(uv, time);
  var color = hcfPalette(value);
  let grain = hcfHash21(floor(uv * hcfCanvasCells()) + floor(time * 12.0));
  color += (grain - 0.5) * 0.055;
  color *= 0.94 + 0.08 * sin(uv.y * 900.0 + time * 7.0);
  return clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));
}

fn primitiveFeedbackPresent(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let speedControl = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.1);
  let grid = hcfGrid(density);
  let time = g.viewport.w * speedControl;
  let uv = fragCoord / resolution;
  let cell = floor(uv * grid);
  let cellUv = (cell + vec2<f32>(0.5)) / grid;

  var color = hcfBackgroundColor(cellUv, time);
  let rover = hcfGetRover(cell, grid);
  let mass = clamp(rover.r, 0.0, 1.0);
  let trail = clamp(rover.a, 0.0, 1.0);
  let pulse = 0.72 + 0.28 * sin(TAU * rover.b);

  let trailColor = mix(g.primary.rgb, g.secondary.rgb, 0.55);
  let glowColor = mix(g.secondary.rgb, g.accent.rgb, 0.45);
  let coreColor = mix(g.accent.rgb, vec3<f32>(1.0), 0.35);

  color = mix(color, trailColor, clamp(trail * 0.30, 0.0, 1.0));
  color += glowColor * trail * 0.08;
  color = mix(color, glowColor, mass * 0.55 * pulse);
  color += coreColor * mass * (0.32 + 0.24 * pulse);

  let opacity = clamp(l.p0.z, 0.0, 1.0);
  return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), opacity);
}
