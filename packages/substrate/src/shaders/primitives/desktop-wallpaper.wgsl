/* @substrate
{
  "name": "desktop-wallpaper",
  "label": "DESKTOP WALLPAPER",
  "order": 410,
  "modes": ["full"],
  "blend": "source-over",
  "params": []
}
*/

// Port of movAX13h's "Desktop Wallpaper" fragment shader.
// The original iMouse color switch is omitted because it is not part of the
// shared Substrate primitive ABI. This remains a separate primitive from the
// existing `invaders` shader.

fn dwRand(value: f32) -> f32 {
  return fract(sin(value) * 4358.5453);
}

fn dwRand2(co: vec2<f32>) -> f32 {
  return fract(sin(dot(co, vec2<f32>(12.9898, 78.233))) * 3758.5357);
}

fn dwInvader(pIn: vec2<f32>, seed: f32) -> f32 {
  var p = pIn;
  p.x = abs(p.x);
  p.y = -floor(p.y - 5.0);
  let bit = floor(p.x + p.y * 3.0);
  let pattern = exp2(bit);
  return step(p.x, 2.0) * step(
    1.0,
    floor(modp(seed / max(pattern, 1.0), 2.0))
  );
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let speed = max(l.p0.x, 0.0);
  let density = clamp(l.p0.y, 0.1, 4.0);
  let opacity = clamp(l.p0.z, 0.0, 1.0);
  let time = g.viewport.w * speed;

  let p = fragCoord;
  let uv = p / resolution - vec2<f32>(0.5);

  // Keep the original radial shading, but do not add the source shader's
  // per-column random brightness to the visible background. That term creates
  // hard vertical bars at every 1024-pixel column boundary.
  var amount = -0.3 * smoothstep(0.0, 0.7, length(uv));

  // Keep glyph scale independent from density. Density controls how many
  // cells participate below; shrinking the cells made the high end unreadable
  // and also made the low end sparse by reducing the number of available cells.
  let cellSize = 12.0;
  let cell = fract(p / cellSize) * 8.0 - vec2<f32>(4.0);
  let random = dwRand2(floor(p / cellSize));
  let invaderLight = dwInvader(cell, 809999.0 * random);
  let packing = smoothstep(0.1, 4.0, density);
  let gate = mix(0.36, 0.72, packing);
  amount += (
    0.09 + max(0.0, 0.2 * sin(10.0 * random * time))
  ) * invaderLight * step(random, gate);

  let base = mix(g.background.rgb, g.primary.rgb, 0.42);
  let highlight = mix(g.secondary.rgb, g.accent.rgb, 0.5 + 0.5 * sin(time * 0.35));
  let signal = clamp(0.30 + amount * 1.9, 0.0, 1.0);
  var color = mix(base, highlight, signal * 0.7);
  color += g.accent.rgb * max(amount, 0.0) * 0.18;

  return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), opacity);
}
