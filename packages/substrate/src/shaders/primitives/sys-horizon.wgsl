/* @substrate
{
  "name": "sys-horizon",
  "label": "SYS$HORIZON",
  "order": 310,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "horizon",            "slot": 0, "default": 0.10, "type": "number" },
    { "key": "skyFade",            "slot": 1, "default": 0.40, "type": "number" },
    { "key": "paneDepth",          "slot": 2, "default": 0.05, "type": "number" },
    { "key": "reflectionStrength", "slot": 3, "default": 0.25, "type": "number" }
  ]
}
*/

// -----------------------------------------------------------------------------
// SYS$HORIZON
//
// One-file WGSL/Substrate port of the Shadertoy shader:
//   Common + Buffer A + Image
//
// Notes:
// - This one does NOT require persistent feedback textures.
// - Buffer A is a direct scene render.
// - Image only performs post-processing / reflection, so both passes are
//   merged here into one standard `primitiveFull` shader.
// - Interactivity and hue-shift paths are omitted because they were disabled
//   in the supplied source.
// - Colors are made theme-reactive while preserving the original vaporwave
//   menu mood.
//
// Global controls:
//   l.p0.x = SPEED
//   l.p0.y = DENSITY
//   l.p0.z = OPACITY
//
// Shader params:
//   l.p1.x = horizon
//   l.p1.y = skyFade
//   l.p1.z = paneDepth
//   l.p1.w = reflectionStrength
// -----------------------------------------------------------------------------

const SH_PI: f32 = 3.14159265;
const SH_PI2: f32 = 1.57079633;
const SH_INTRO_FRAMES: f32 = 100.0;
const SH_INTRO_DURATION: f32 = SH_INTRO_FRAMES / 60.0;

struct ShZoomResult {
  uv: vec2<f32>,
  fov: vec2<f32>,
};

struct ShEvalResult {
  color: vec3<f32>,
  uv: vec2<f32>,
  fov: vec2<f32>,
};

fn shScreen(a: vec3<f32>, b: vec3<f32>) -> vec3<f32> {
  return a + b * (vec3<f32>(1.0) - a);
}

fn shRand(seed: vec2<f32>) -> f32 {
  return fract(sin(dot(seed, vec2<f32>(12.9898, 78.233))) * 43758.5453);
}

fn shRot(p: vec2<f32>, a: f32) -> vec2<f32> {
  let s = sin(a);
  let c = cos(a);
  let m = mat2x2<f32>(
    vec2<f32>(c, s),
    vec2<f32>(-s, c)
  );
  return p * m;
}

fn shZoom(pIn: vec2<f32>, introT: f32) -> ShZoomResult {
  var p = pIn;
  var fov = vec2<f32>(1.0);

  // DO_INTRO path from the source.
  fov = vec2<f32>(0.5) + vec2<f32>(tan(0.5 * -cos(SH_PI * introT)));
  p   *= fov;

  return ShZoomResult(p, fov);
}

// Signed distance of vec2 [p] from a parallelogram defined by width/height
// [size] and [skew] angle in radians. Ported from Inigo Quilez's formulation.
fn shSdParallelogram(pIn: vec2<f32>, size: vec2<f32>, skew: f32) -> f32 {
  var p = pIn;
  let e = vec2<f32>(skew, size.y);

  if p.y < 0.0 {
    p = -p;
  }

  var w = p - e;
  w.x   -= clamp(w.x, -size.x, size.x);

  var d = vec2<f32>(dot(w, w), -w.y);

  let s = p.x * e.y - p.y * e.x;

  if s < 0.0 {
    p = -p;
  }

  var v = p - vec2<f32>(size.x, 0.0);
  v   -= e * clamp(dot(v, e) / max(dot(e, e), 0.00001), -1.0, 1.0);

  d = min(d, vec2<f32>(dot(v, v), size.x * size.y - abs(s)));
  return sqrt(d.x) * sign(-d.y);
}

fn shSky(p: vec2<f32>, horizon: f32, skyFade: f32) -> f32 {
  return max(0.0, -(horizon - skyFade - p.y));
}

fn shFog(p: vec2<f32>, exponent: f32, horizon: f32) -> f32 {
  var f = 0.0;

  if p.y < horizon {
    f = pow(smoothstep(-horizon, horizon, p.y), 6.0);
  } else {
    // Source uses reversed smoothstep(1.5, HORIZON, p.y).
    f = pow(1.0 - smoothstep(horizon, 1.5, p.y), 3.0);
  }

  return pow(f, exponent);
}

fn shStars(time: f32, p: vec2<f32>, count: f32, radius: f32) -> f32 {
  let id = floor(p * count);
  let f = fract(p * count + vec2<f32>(0.5 * id.y, 0.0)) - vec2<f32>(0.5);

  var m = 0.0;

  if shRand(id.yx + vec2<f32>(0.117, 0.2)) > 0.97 {
    let lenF = max(length(f), 0.0001);

    let star = abs(
        (0.1 / lenF - radius) * (-0.25 + shRand(id) * sin(3.0 * time) * cos(time))
      );

    m   += star * star;
    m = clamp(m * (-p.y + 0.1), 0.0, 1.0);
  }

  return m;
}

fn shGrid(
  p: vec2<f32>,
  count: f32,
  zOffset: f32,
  scaler: vec2<f32>,
  thickness: vec3<f32>,
  planeColor: vec3<f32>,
  gridColor: vec3<f32>,
  purpleColor: vec3<f32>
) -> vec3<f32> {
  var q = (p + vec2<f32>(0.0, zOffset)) / max(p.y * scaler, vec2<f32>(0.0001));
  q = fract(count * q);

  let gridMask = 1.0 - smoothstep(0.0, thickness.x, q.x) * smoothstep(0.0, thickness.x, 1.0 - q.x) * smoothstep(0.0, thickness.y, q.y) * smoothstep(0.0, thickness.y, 1.0 - q.y);

  let glow = 1.0 - smoothstep(0.0, 15.0 * thickness.y, 1.0 - q.y) * smoothstep(0.0, 3.0 * thickness.x, q.x) * smoothstep(0.0, 3.0 * thickness.x, 1.0 - q.x);

  return mix(
    planeColor,
    gridColor,
    pow(gridMask, thickness.z)
  ) + 0.25 * purpleColor * glow;
}

fn shPane(
  p: vec2<f32>,
  offset: f32,
  size: vec2<f32>,
  skew: f32,
  color: vec3<f32>,
  opacity: f32,
  horizon: f32,
  paneDepth: f32,
  introT: f32
) -> vec3<f32> {
  let z = paneDepth + 0.1 * (1.0 - introT);

  let d = shSdParallelogram(
    p + vec2<f32>(offset, size.y - horizon - z),
    size,
    skew
  );

  let paneMask = step(0.0, -900.0 * d);

  if paneMask > 0.0 {
    return opacity * color * paneMask * clamp(-p.y + horizon + z, 0.0, 1.0);
  }

  return vec3<f32>(0.0);
}

fn shColors() -> array<vec3<f32>, 5> {
  let planeColor = mix(g.background.rgb, g.secondary.rgb, 0.08);
  let fogColor = mix(g.background.rgb, g.primary.rgb, 0.56);
  let paneColor = mix(g.primary.rgb, g.secondary.rgb, 0.40);
  let purpleColor = mix(g.accent.rgb, g.primary.rgb, 0.48);
  let gridColor = mix(g.primary.rgb, g.accent.rgb, 0.70);

  return array<vec3<f32>, 5>(
    planeColor,
    fogColor,
    paneColor,
    purpleColor,
    gridColor
  );
}

fn shEvalScene(
  fragCoord: vec2<f32>,
  resolution: vec2<f32>,
  time: f32,
  density: f32,
  horizon: f32,
  skyFade: f32,
  paneDepth: f32,
  introT: f32
) -> ShEvalResult {
  let minDim = max(min(resolution.x, resolution.y), 1.0);

  let rawUv = vec2<f32>(
  0.5 * resolution.x - fragCoord.x,
  fragCoord.y - 0.5 * resolution.y
) / minDim;
  let zoomed = shZoom(rawUv, introT);

  let uv = zoomed.uv;
  let fov = zoomed.fov;

  let colors = shColors();
  let planeColor = colors[0];
  let fogColor = colors[1];
  let paneColor = colors[2];
  let purpleColor = colors[3];
  let gridColor = colors[4];

  let densityClamped = max(density, 0.05);
  let starCount = 40.0 * mix(0.75, 1.65, clamp(sqrt(densityClamped) / 1.5, 0.0, 1.0));
  let gridCount = 3.1 * mix(0.75, 1.60, clamp(sqrt(densityClamped) / 1.5, 0.0, 1.0));

  var c = mix(vec3<f32>(0.01), purpleColor, shSky(uv, horizon, skyFade));
  c = shScreen(c, vec3<f32>(1.0) * shStars(time, uv, starCount, 0.25));

  if uv.y > horizon {
    c = shGrid(
      uv,
      gridCount,
      1.5,
      vec2<f32>(3.15, 2.0),
      vec3<f32>(0.02, 0.04, 5.0),
      planeColor,
      gridColor,
      purpleColor
    );
  }

  c = mix(c, 0.05 * c + 0.95 * fogColor, shFog(uv, 4.0, horizon));

  let noisyFog = shFog(
      uv + vec2<f32>(0.2 * shRand(uv + vec2<f32>(sin(0.25 * time)))),
      10.0,
      horizon
    );

  c   -= vec3<f32>(0.025 * noisyFog);

  let w = 0.25 * sin(1.571 + 1.571 * pow(introT, 0.5));
  let skewer = 0.0;

  c   += shPane(
    uv,
    0.3 + 0.2 * sin(0.125 * time),
    vec2<f32>(0.30 + w, 1.0),
    0.6 - skewer,
    purpleColor,
    0.3,
    horizon,
    paneDepth,
    introT
  );

  c   += shPane(
    uv,
    0.6 + 0.2 * cos(0.1 * time),
    vec2<f32>(0.30 + w, 1.0),
    0.6 - skewer,
    purpleColor,
    0.3,
    horizon,
    paneDepth,
    introT
  );

  c   += shPane(
    uv,
    0.3 + 0.1 * (1.0 + sin(0.075 * time)),
    vec2<f32>(0.20 + w, 1.0),
    0.6 - skewer,
    paneColor,
    0.8,
    horizon,
    paneDepth,
    introT
  );

  c   += shPane(
    uv,
    0.4 + 0.1 * sin(100.0 + 0.175 * time),
    vec2<f32>(0.15 + w, 1.0),
    0.6 - skewer,
    paneColor,
    1.1,
    horizon,
    paneDepth,
    introT
  );

  c   += shPane(
    uv,
    0.3 + 0.05 * sin(200.0 + 0.25 * time),
    vec2<f32>(0.15 + w, 1.0),
    0.6 - skewer,
    paneColor,
    1.1,
    horizon,
    paneDepth,
    introT
  );

  return ShEvalResult(c, uv, fov);
}

fn shReflection(
  p: vec2<f32>,
  coord: vec2<f32>,
  resolution: vec2<f32>,
  time: f32,
  density: f32,
  horizon: f32,
  skyFade: f32,
  paneDepth: f32,
  introT: f32
) -> vec3<f32> {
  var uv = coord / resolution;
  uv.y = 1.0 - uv.y - (horizon + paneDepth * 4.0);
  uv = clamp(uv, vec2<f32>(0.0), vec2<f32>(1.0));

  let sampleCoord = uv * resolution;
  let reflected = shEvalScene(
    sampleCoord,
    resolution,
    time,
    density,
    horizon,
    skyFade,
    paneDepth,
    introT
  ).color;

  let factor = smoothstep(0.0, horizon, p.y - horizon) * (2.5 - 2.0 * p.y);

  return clamp(0.85 * factor * reflected, vec3<f32>(0.0), vec3<f32>(1.0));
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));

  let speed = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.05);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let horizon = clamp(l.p1.x, 0.02, 0.45);
  let skyFade = clamp(l.p1.y, 0.05, 1.25);
  let paneDepth = clamp(l.p1.z, 0.0, 0.25);
  let reflectionStrength = clamp(l.p1.w, 0.0, 1.5);

  let time = g.viewport.w * speed;
  let introT = clamp(time / SH_INTRO_DURATION, 0.0, 1.0);

  let scene = shEvalScene(
    fragCoord,
    resolution,
    time,
    density,
    horizon,
    skyFade,
    paneDepth,
    introT
  );

  var c = scene.color;

  c = shScreen(
    c,
    reflectionStrength * shReflection(
      scene.uv,
      fragCoord,
      resolution,
      time,
      density,
      horizon,
      skyFade,
      paneDepth,
      introT
    )
  );

  c = mix(vec3<f32>(0.0), c, pow(introT, 3.0));

  return vec4<f32>(
    clamp(c, vec3<f32>(0.0), vec3<f32>(1.0)),
    opacity
  );
}
