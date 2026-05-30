/* @substrate
{
  "name": "cyber-glyph-grid",
  "label": "CYBER GLYPH GRID",
  "order": 320,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "gridScale",       "slot": 0, "default": 20.0, "type": "number" },
    { "key": "glitchAmount",    "slot": 1, "default": 0.005, "type": "number" },
    { "key": "scanStrength",    "slot": 2, "default": 0.55, "type": "number" },
    { "key": "sparkleStrength", "slot": 3, "default": 0.25, "type": "number" }
  ]
}
*/

// -----------------------------------------------------------------------------
// CYBER GLYPH GRID
//
// Theme-reactive port of the supplied cyberpunk composite shader.
//
// Global:
//   l.p0.x = SPEED
//   l.p0.y = DENSITY
//   l.p0.z = OPACITY
//
// Density does NOT zoom the scene. It controls glyph/sparkle population and
// detail contribution. gridScale remains the actual spatial grid scale.
// -----------------------------------------------------------------------------

const CGG_PHI: f32 = 1.61803398875;

fn cggHash(p: vec2<f32>) -> f32 {
  return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn cggWavePattern(uv: vec2<f32>, time: f32) -> f32 {
  return sin(uv.x * CGG_PHI * 5.0 + time) * cos(uv.y * TAU - time * 0.5);
}

fn cggFractalNoise(uvIn: vec2<f32>, time: f32) -> f32 {
  var uv = uvIn;
  var sum = 0.0;
  var scale = 1.0;

  for (var i: i32 = 0; i < 5; i = i + 1) {
    sum   += cggWavePattern(uv * scale, time) / scale;
    scale   *= 1.5;
  }

  return sum;
}

fn cggGlyph(uv: vec2<f32>, time: f32, density: f32) -> f32 {
  let grid = floor(uv * 20.0);
  let timeShift = fract((grid.y - time * 5.0) / 10.0) * 10.0;
  let gate = smoothstep(0.2, 0.8, timeShift);

  // Organic feature population rather than scaling the glyph grid itself.
  let presence = 1.0 - smoothstep(
    clamp(density, 0.0, 1.0),
    clamp(density, 0.0, 1.0) + 0.12,
    cggHash(grid + vec2<f32>(19.3, 7.1))
  );

  return cggHash(grid) * gate * presence;
}

fn cggGridOverlay(uv: vec2<f32>) -> f32 {
  let g2 = abs(fract(uv) - vec2<f32>(0.5));
  let lineWidth = 0.02;

  return clamp(
    smoothstep(0.5 - lineWidth, 0.5, g2.x) + smoothstep(0.5 - lineWidth, 0.5, g2.y),
    0.0,
    1.0
  );
}

fn cggScanLines(uv: vec2<f32>, time: f32, strength: f32) -> f32 {
  let s = 0.5 + 0.5 * sin(uv.y * 600.0 + time * 20.0);
  return mix(1.0, s, clamp(strength, 0.0, 1.0));
}

fn cggRadialBoost(uv: vec2<f32>) -> f32 {
  let d = length(uv);
  return 1.0 + 0.3 * (1.0 - smoothstep(0.0, 0.9, d));
}

fn cggThemeColor(tIn: f32) -> vec3<f32> {
  let t = fract(tIn);

  let w0 = 0.5 + 0.5 * sin(TAU * t);
  let w1 = 0.5 + 0.5 * sin(TAU * t + 2.094);
  let w2 = 0.5 + 0.5 * sin(TAU * t + 4.188);

  let sumW = max(w0 + w1 + w2, 0.00001);

  return (g.primary.rgb * w0 + g.secondary.rgb * w1 + g.accent.rgb * w2) / sumW;
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let speed = max(l.p0.x, 0.0);
  let density = clamp(l.p0.y, 0.0, 1.0);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let gridScale = max(l.p1.x, 1.0);
  let glitchAmount = max(l.p1.y, 0.0);
  let scanStrength = clamp(l.p1.z, 0.0, 1.0);
  let sparkleStrength = max(l.p1.w, 0.0);

  let time = g.viewport.w * speed;

  var uv = fragCoord / resolution - vec2<f32>(0.5);
  uv.x   *= resolution.x / resolution.y;

  let dUv = uv + glitchAmount * vec2<f32>(
    sin(time + uv.y * 40.0),
    cos(time + uv.x * 40.0)
  );

  let pattern = cggFractalNoise(dUv * 1.5, time);
  let symbols = cggGlyph(dUv, time, density);
  let baseLayer = mix(symbols, pattern, 0.5);

  let grid = cggGridOverlay(uv * gridScale);
  let scan = cggScanLines(uv, time, scanStrength);

  let grain = 0.05 * (cggHash(uv * 100.0 + floor(time * 2.0)) - 0.5);

  var combined = mix(baseLayer, grid, 0.35);
  combined   *= scan;
  combined   += grain;

  let pulse = smoothstep(0.2, 0.8, sin(time * 2.0) * 0.5 + 0.5);
  let intensity = combined + pulse * 0.3;

  var color = cggThemeColor(time * 0.1 + intensity);
  color   *= max(intensity, 0.0) * 1.5;

  color   +=
    mix(g.primary.rgb, g.accent.rgb, 0.65) * 0.3 * pow(max(intensity, 0.0), 2.0);

  color   *= cggRadialBoost(uv);

  let sparklePresence = 1.0 - smoothstep(
    density,
    min(density + 0.08, 1.0001),
    cggHash(floor((fragCoord / resolution) * 200.0))
  );

  let sparkle = smoothstep(
      0.985,
      1.0,
      cggHash((fragCoord / resolution) * 200.0 + vec2<f32>(time))
    ) * sparklePresence;

  color   += mix(g.accent.rgb, vec3<f32>(1.0), 0.25) * sparkle * sparkleStrength;

  return vec4<f32>(
    clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)),
    opacity
  );
}
