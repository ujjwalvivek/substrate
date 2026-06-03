/* @substrate
{
  "name": "last-relay",
  "label": "THE LAST RELAY",
  "order": 400,
  "modes": ["full"],
  "blend": "source-over",
  "params": []
}
*/

// Port of Marco van Hylckama Vlieg's "The Last Relay" home screen shader.
// Shadertoy's iMouse input is intentionally omitted: Substrate's generic
// primitive ABI currently supplies viewport, time, palette, and layer controls.

const LR_TIME_SCALE: f32 = 0.5;

fn lrHash11(pIn: f32) -> f32 {
  var p = fract(pIn * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

fn lrHash21(p: vec2<f32>) -> f32 {
  var p3 = fract(vec3<f32>(p.x, p.y, p.x) * 0.1031);
  p3 += dot(p3, p3.yzx + vec3<f32>(33.33));
  return fract((p3.x + p3.y) * p3.z);
}

fn lrRainLayer(
  uv: vec2<f32>,
  scale: f32,
  speed: f32,
  seed: f32,
  time: f32
) -> vec3<f32> {
  var q = uv * vec2<f32>(scale, scale * 0.68);
  q.y += time * speed;

  let cell = floor(q);
  let f = fract(q) - vec2<f32>(0.5);

  let columnRandom = lrHash11(cell.x + seed * 17.13);
  let streamLength = floor(mix(10.0, 30.0, columnRandom));
  let head = modp(
    time * speed * 8.0 + columnRandom * streamLength,
    streamLength
  );
  let row = modp(cell.y + streamLength * 10.0, streamLength);
  let distanceFromHead = modp(head - row + streamLength, streamLength);

  var trail = exp(-0.23 * distanceFromHead);
  trail *= 1.0 - smoothstep(
    streamLength * 0.65,
    streamLength * 0.95,
    distanceFromHead
  );

  let glyphGrid = vec2<f32>(3.0, 5.0);
  let glyphCell = floor((f + vec2<f32>(0.5)) * glyphGrid);
  let glyphUv = fract((f + vec2<f32>(0.5)) * glyphGrid) - vec2<f32>(0.5);

  let pixel = 1.0 - smoothstep(
    0.28,
    0.42,
    max(abs(glyphUv.x), abs(glyphUv.y))
  );
  let bit = step(
    0.5,
    lrHash21(
      cell * vec2<f32>(7.31, 11.17) + glyphCell + vec2<f32>(seed)
    )
  );
  let bounds = step(abs(f.x), 0.37) * step(abs(f.y), 0.45);
  let flicker = 0.65 + 0.35 * lrHash21(
    cell + floor(vec2<f32>(time * 8.0)) + vec2<f32>(seed)
  );

  let glyph = pixel * bit * bounds * trail * flicker;
  let headFlash = exp(-2.4 * distanceFromHead) * glyph;

  // Preserve the source's emerald/cyan language while routing every color
  // through the active Substrate theme.
  let emerald = mix(g.primary.rgb, g.secondary.rgb, 0.22);
  let cyan = mix(g.secondary.rgb, g.accent.rgb, 0.35);
  let mint = mix(g.accent.rgb, vec3<f32>(1.0), 0.25);
  let tintMix = lrHash11(cell.x * 2.7 + seed * 3.1);
  let glyphColor = mix(emerald, cyan, tintMix * 0.50);

  return glyph * glyphColor + headFlash * mint * 1.8;
}

fn lrParticles(uv: vec2<f32>, time: f32, density: f32) -> vec3<f32> {
  var color = vec3<f32>(0.0);
  let grid = uv * 22.0 * density;
  let id = floor(grid);
  let f = fract(grid) - vec2<f32>(0.5);

  let particleA = mix(g.primary.rgb, g.secondary.rgb, 0.30);
  let particleB = mix(g.secondary.rgb, g.accent.rgb, 0.50);

  for (var j: i32 = -1; j <= 1; j = j + 1) {
    for (var i: i32 = -1; i <= 1; i = i + 1) {
      let offset = vec2<f32>(f32(i), f32(j));
      let cell = id + offset;
      let random = lrHash21(cell + vec2<f32>(19.7));

      let basePosition = vec2<f32>(
        lrHash21(cell + vec2<f32>(1.3)),
        lrHash21(cell + vec2<f32>(8.1))
      ) - vec2<f32>(0.5);

      var direction = vec2<f32>(
        lrHash21(cell + vec2<f32>(4.7)),
        lrHash21(cell + vec2<f32>(9.3))
      ) * 2.0 - vec2<f32>(1.0);
      direction = normalize(direction + vec2<f32>(1e-4));

      let phase = fract(time * (0.03 + random * 0.05) + random);
      let position = basePosition + direction * ((phase - 0.5) * 0.70);
      let distanceToParticle = length(f - offset - position);
      let spark = exp(-distanceToParticle * 10.0) * (0.25 + 0.75 * random);
      let particleColor = mix(particleA, particleB, random * 0.5);

      color += particleColor * spark * 0.07;
    }
  }

  return color;
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let density = sqrt(clamp(l.p0.y, 0.1, 4.0));
  let time = g.viewport.w * max(l.p0.x, 0.0) * LR_TIME_SCALE;
  let uv = (2.0 * fragCoord - resolution) / resolution.y;
  let p = uv;

  // Slightly lifted base so the relay remains legible over the active theme.
  var color = mix(g.background.rgb, g.primary.rgb, 0.035);

  let radial = exp(-length(p) * 1.35);
  color += mix(g.secondary.rgb, g.accent.rgb, 0.35) * radial * 0.06;

  color += mix(g.secondary.rgb, g.accent.rgb, 0.50)
    * smoothstep(1.2, -0.8, uv.y) * 0.016;

  let grain = lrHash21(floor(fragCoord * 0.5) + floor(vec2<f32>(time * 15.0)));
  color += mix(g.secondary.rgb, g.accent.rgb, 0.55) * grain * 0.0022;

  color += lrParticles(p, time, density);
  color += lrRainLayer(p + vec2<f32>(0.10, 0.0), 14.0 * density, 0.70, 3.0, time) * 0.22;
  color += lrRainLayer(p * 1.10 - vec2<f32>(0.18, 0.0), 20.0 * density, 1.00, 17.0, time) * 0.16;
  color += lrRainLayer(p * 1.24 + vec2<f32>(0.27, 0.0), 28.0 * density, 1.28, 41.0, time) * 0.10;

  let scanBand1 = exp(-90.0 * abs(fract(uv.y * 20.0 - time * 0.42) - 0.5));
  let scanBand2 = exp(-120.0 * abs(fract(uv.y * 31.0 + time * 0.27) - 0.5));
  color += mix(g.secondary.rgb, g.accent.rgb, 0.50) * scanBand1 * 0.010;
  color += mix(g.primary.rgb, g.accent.rgb, 0.50) * scanBand2 * 0.006;

  let scanlines = smoothstep(0.18, 0.82, fract(fragCoord.y * 0.5));
  color *= 0.978 + 0.022 * scanlines;

  let vignette = 1.0 - 0.34 * smoothstep(0.3, 1.6, length(uv));
  color *= vignette;

  color = 1.0 - exp(-max(color, vec3<f32>(0.0)) * 1.28);
  color *= vec3<f32>(0.92, 1.03, 1.05);
  color = pow(max(color, vec3<f32>(0.0)), vec3<f32>(0.94));

  return vec4<f32>(
    clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)),
    clamp(l.p0.z, 0.0, 1.0)
  );
}
