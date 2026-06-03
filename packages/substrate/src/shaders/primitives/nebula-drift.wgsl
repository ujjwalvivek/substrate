/* @substrate
{
  "name": "nebula-drift",
  "label": "NEBULA DRIFT",
  "order": 350,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "zoomSpeed",  "slot": 0, "default": 0.5, "type": "number" },
    { "key": "zoomAmount", "slot": 1, "default": 0.5, "type": "number" },
    { "key": "zoomOffset", "slot": 2, "default": 1.0, "type": "number" },
    { "key": "brightness", "slot": 3, "default": 2.0, "type": "number" }
  ]
}
*/

// Nebula Drift - Dynamic Cosmic Flow.
// Adapted from the supplied Shadertoy-style shader to Substrate's full-frame
// WGSL ABI. The zoom controls are exposed as primitive parameters.

fn ndRandom(point: vec2<f32>) -> f32 {
  return fract(100.0 * sin(point.x + fract(100.0 * sin(point.y))));
}

fn ndNoise(st: vec2<f32>) -> f32 {
  let i = floor(st);
  let f = fract(st);
  let a = ndRandom(i);
  let b = ndRandom(i + vec2<f32>(1.0, 0.0));
  let c = ndRandom(i + vec2<f32>(0.0, 1.0));
  let d = ndRandom(i + vec2<f32>(1.0, 1.0));
  let u = f * f * (vec2<f32>(3.0) - 2.0 * f);
  return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

fn ndFbm(pIn: vec2<f32>) -> f32 {
  var p = pIn;
  var value = 0.0;
  var frequency = 1.0;
  var amplitude = 0.5;
  for (var i: i32 = 0; i < 7; i++) {
    value += amplitude * ndNoise((p - vec2<f32>(1.0)) * frequency);
    frequency *= 1.9;
    amplitude *= 0.6;
  }
  return value;
}

fn ndPattern(p: vec2<f32>, time: f32, density: f32) -> f32 {
  let scale = max(density, 0.1);
  let aPos = vec2<f32>(sin(time * 0.05), sin(time * 0.1)) * 6.0;
  let a = ndFbm(p * vec2<f32>(3.0) * scale + aPos);

  let bPos = vec2<f32>(sin(time * 0.1), sin(time * 0.1));
  let b = ndFbm((p + a) * vec2<f32>(0.5) + bPos);

  let cPos = vec2<f32>(-0.6, -0.5) + vec2<f32>(sin(-time * 0.01), sin(time * 0.1)) * 2.0;
  return ndFbm((p + b) * vec2<f32>(2.0) * scale + cPos);
}

fn ndPalette(t: f32) -> vec3<f32> {
  let low = mix(g.background.rgb, g.primary.rgb, 0.28);
  let middle = mix(g.primary.rgb, g.secondary.rgb, 0.5 + 0.5 * cos(t * TAU));
  let high = mix(g.secondary.rgb, g.accent.rgb, 0.5 + 0.5 * sin(t * TAU + 1.0));
  var color = mix(low, middle, smoothstep(0.0, 0.52, t));
  color = mix(color, high, smoothstep(0.42, 1.0, t));
  return color;
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let time = g.viewport.w * l.p0.x;
  let density = clamp(l.p0.y, 0.1, 4.0);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  var uv = fragCoord / resolution * 2.0 - vec2<f32>(1.0);
  uv.x *= resolution.x / resolution.y;

  let zoomSpeed = max(l.p1.x, 0.0);
  let zoomAmount = clamp(l.p1.y, 0.0, 1.0);
  let zoomOffset = max(l.p1.z, 0.1);
  let zoomFactor = clamp(zoomOffset + sin(time * zoomSpeed) * zoomAmount, 0.5, 2.5);
  uv /= zoomFactor;

  uv += vec2<f32>(sin(time * 0.1), cos(time * 0.1)) * 0.02;

  let shakeSeed = vec2<f32>(floor(time * 0.01));
  let shakeInterval = 10.0 + ndRandom(shakeSeed) * 20.0;
  let shakeStart = select(0.0, 1.0, modp(time, shakeInterval) < 0.2);
  let shakeIntensity = 0.02 * shakeStart * sin(time * 125.0);
  uv += vec2<f32>(
    ndRandom(uv + vec2<f32>(time)) - 0.5,
    ndRandom(uv + vec2<f32>(time * 2.0)) - 0.5
  ) * shakeIntensity;

  let value = pow(max(ndPattern(uv, time, density), 0.0), 2.0);
  var color = ndPalette(value);
  color = pow(max(color, vec3<f32>(0.0)), vec3<f32>(2.0));
  color *= max(l.p1.w, 0.0);
  color = mix(g.background.rgb, color, 0.72);

  return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), opacity);
}
