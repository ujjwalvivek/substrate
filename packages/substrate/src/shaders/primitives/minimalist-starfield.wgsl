/* @substrate
{
  "name": "minimalist-starfield",
  "label": "MINIMALIST STARFIELD",
  "order": 270,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "gridSize", "slot": 0, "default": 8.0,  "type": "number" },
    { "key": "starSize", "slot": 1, "default": 0.05, "type": "number" },
    { "key": "orbit",    "slot": 2, "default": 0.50, "type": "number" },
    { "key": "rotation", "slot": 3, "default": 1.0,  "type": "number" }
  ]
}
*/

// Textureless, mouse-free Substrate port of paperu's minimalist starfield.
// The source mouse vector is replaced by the same autonomous circular motion
// already present in the original shader.
// Theme colors replace hard-coded near-black and white.

fn msfBoxDistance(p: vec2<f32>, s: f32, r: f32) -> f32 {
  return length(abs(p) - vec2<f32>(s)) - r;
}

fn msfRot(a: f32) -> mat2x2<f32> {
  let c = cos(a);
  let s = sin(a);
  return mat2x2<f32>(
    vec2<f32>( c, s),
    vec2<f32>(-s, c)
  );
}

fn msfAsympt(x: f32, sp: f32) -> f32 {
  return x / (sp + x);
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let viewport = max(g.viewport.xy, vec2<f32>(1.0));
  let speed = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.05);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let baseGrid = max(l.p1.x, 1.0);
  let starSize = clamp(l.p1.y, 0.005, 0.20);
  let orbitAmount = max(l.p1.z, 0.0);
  let rotationAmount = l.p1.w;

  var st = (fragCoord - 0.5 * viewport) / viewport.y;

  let time = g.viewport.w * speed;
  let t = time * 0.25;

  let m = vec2<f32>(
      cos(0.5 * t),
      sin(0.5 * t)
    ) * orbitAmount;

  // Density changes the number of star cells, not the camera scale.
  let sz = baseGrid * sqrt(density) * (1.0 - m.y * 0.5);

  let aa = sz / viewport.y;

  let age = max(time - 1.0, 0.0);
  let tB = clamp(msfAsympt(age, 3.0), 0.0, 1.0);

  var p = st + m * 0.5;

  p = msfRot(
      (TAU * 0.125 + m.y * TAU * 0.125) * rotationAmount
    ) * p;

  let pF = floor(p * sz);

  p = fract(p * sz) - vec2<f32>(0.5);

  p = msfRot(
      pF.x * TAU * 0.333
    ) * p;

  p = abs(p) - vec2<f32>(0.042);

  let sizeOsc = 0.4 * tB - (0.5 + 0.5 * cos(length(pF) * 10.5 - t)) * 0.5;

  var d = msfBoxDistance(
      p,
      sizeOsc,
      starSize
    );

  d = smoothstep(
      -aa,
       aa,
      abs(d) - aa * 0.25
    );

  let star = mix(
      g.primary.rgb,
      g.accent.rgb,
      0.45
    );

  let color = mix(
      g.background.rgb,
      star,
      1.0 - d
    );

  return vec4<f32>(
    clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)),
    opacity
  );
}
