/* @substrate
{
  "name": "invaders",
  "label": "INVADERS",
  "order": 390,
  "modes": ["full"],
  "blend": "source-over",
  "params": []
}
*/

// Port of movAX13h's 2015 desktop wallpaper shader.
// The optional mouse color switch is omitted because Substrate's generic GPU
// ABI does not expose Shadertoy's iMouse uniform.

fn invRand(value: f32) -> f32 {
  return fract(sin(value) * 4358.5453);
}

fn invRand2(co: vec2<f32>) -> f32 {
  return fract(sin(dot(co, vec2<f32>(12.9898, 78.233))) * 3758.5357);
}

fn invader(pIn: vec2<f32>, seed: f32) -> f32 {
  var p = pIn;
  p.x = abs(p.x);
  p.y = -floor(p.y - 5.0);
  let bit = floor(p.x + p.y * 3.0);
  let pattern = floor(pow(2.0, bit));
  return step(p.x, 2.0) * step(1.0, floor(seed / max(pattern, 1.0)) - 2.0 * floor(seed / max(pattern * 2.0, 1.0)));
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let time = g.viewport.w * max(l.p0.x, 0.0);
  let density = sqrt(clamp(l.p0.y, 0.1, 4.0));
  let p = fragCoord;
  let uv = p / resolution - vec2<f32>(0.5);
  let width = 24.0 / density;

  let id1 = invRand(floor(p.x / width));
  let id2 = invRand(floor((p.x - 1.0) / width));
  var amount = 0.3 * id1;
  amount += 0.1 * step(id2, id1 - 0.08);
  amount -= 0.1 * step(id1 + 0.08, id2);
  amount -= 0.3 * smoothstep(0.0, 0.7, length(uv));

  let cellSize = 8.0 / density;
  let cell = fract(p / cellSize) * 8.0 - vec2<f32>(4.0);
  let random = invRand2(floor(p / cellSize));
  let invaderLight = invader(cell, 809999.0 * random);
  amount += (
    0.06 + max(0.0, 0.2 * sin(10.0 * random * time))
  ) * invaderLight * step(id1, 0.1);

  let base = mix(g.background.rgb, g.primary.rgb, 0.42);
  let highlight = mix(g.secondary.rgb, g.accent.rgb, 0.5 + 0.5 * sin(time * 0.35));
  let signal = clamp(0.30 + amount * 1.9, 0.0, 1.0);
  var color = mix(base, highlight, signal * 0.7);
  color += g.accent.rgb * max(amount, 0.0) * 0.18;
  return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), clamp(l.p0.z, 0.0, 1.0));
}
