/* @substrate
{
  "name": "floating-squares",
  "label": "FLOATING SQUARES",
  "order": 220,
  "modes": ["full", "sprite"],
  "blend": "source-over",
  "params": [
    {
      "key": "count",
      "slot": 0,
      "default": 240,
      "type": "number"
    },
    {
      "key": "minSize",
      "slot": 1,
      "default": 8,
      "type": "number"
    },
    {
      "key": "maxSize",
      "slot": 2,
      "default": 72,
      "type": "number"
    },
    {
      "key": "wander",
      "slot": 3,
      "default": 38,
      "type": "number"
    }
  ],
  "draw": {
    "sprite": [
      "max",
      0,
      [
        "floor",
        [
          "*",
          "count",
          "density"
        ]
      ]
    ]
  }
}
*/

// -----------------------------------------------------------------------------
// Floating Squares
//
// Theme-native Substrate primitive:
// - no hard-coded scene colors
// - background field is derived from g.background / g.primary / g.secondary
// - squares use g.primary / g.secondary / g.accent
// - global SPEED / DENSITY / OPACITY map through l.p0
//
// common.wgsl already provides:
//   PI, TAU, Globals g, Layer, SpriteData, invalidSprite(), palette(), modp()
// -----------------------------------------------------------------------------

fn fsqHash11(n: f32) -> f32 {
  return fract(sin(n * 12.9898 + 78.233) * 43758.5453123);
}

fn fsqHash21(p: vec2<f32>) -> f32 {
  return fract(sin(dot(p, vec2<f32>(12.9898, 78.233))) * 43758.5453);
}

fn fsqNoise(pIn: vec2<f32>) -> f32 {
  let p = pIn * 2.8;
  let i = floor(p);
  let f = fract(p);
  let u = f * f * (vec2<f32>(3.0) - 2.0 * f);

  return mix(
    mix(
      fsqHash21(i + vec2<f32>(0.0, 0.0)),
      fsqHash21(i + vec2<f32>(1.0, 0.0)),
      u.x
    ),
    mix(
      fsqHash21(i + vec2<f32>(0.0, 1.0)),
      fsqHash21(i + vec2<f32>(1.0, 1.0)),
      u.x
    ),
    u.y
  );
}

fn fsqFbm(uvIn: vec2<f32>) -> f32 {
  var uv = uvIn * 5.0;

  let m = mat2x2<f32>(
    vec2<f32>( 1.6,  1.2),
    vec2<f32>(-1.2,  1.6)
  );

  var f = 0.0;
  f   += 0.5000 * fsqNoise(uv);
  uv = m * uv;

  f   += 0.2500 * fsqNoise(uv);
  uv = m * uv;

  f   += 0.1250 * fsqNoise(uv);
  uv = m * uv;

  f   += 0.0625 * fsqNoise(uv);

  return 0.5 + 0.5 * f;
}

// -----------------------------------------------------------------------------
// Theme-reactive atmospheric layer.
//
// The original shader had a fixed blue background. Here the exact same role is
// filled by the active Substrate palette, so CYBER / FOREST / OCEAN / CUSTOM,
// dark/light mode, etc. all feed the shader automatically.
// -----------------------------------------------------------------------------

fn primitiveFull(p: vec2<f32>, l: Layer) -> vec4<f32> {
  let viewport = max(g.viewport.xy, vec2<f32>(1.0));
  let aspect = viewport.x / viewport.y;

  var uv = p / viewport;
  uv = uv * 2.0 - vec2<f32>(1.0);
  uv.x   *= aspect;

  let t = g.viewport.w * l.p0.x;

  let n0 = fsqFbm(
    uv * vec2<f32>(0.42, 0.60) + vec2<f32>(t * 0.025, -t * 0.010)
  );

  let n1 = fsqFbm(
    uv * vec2<f32>(0.75, 0.38) + vec2<f32>(-t * 0.016, t * 0.008) + vec2<f32>(7.13, 3.71)
  );

  let centerBand = 1.0 - smoothstep(0.15, 1.15, abs(uv.y));
  let cloud = clamp(n0 * 0.68 + n1 * 0.32, 0.0, 1.0);
  let glow = clamp(pow(max(cloud - 0.48, 0.0) * 1.9, 1.45) * centerBand, 0.0, 1.0);

  var col = mix(
    g.background.rgb,
    g.primary.rgb,
    cloud * 0.24
  );

  col = mix(
    col,
    g.secondary.rgb,
    glow * 0.22
  );

  col = mix(
    col,
    g.accent.rgb,
    pow(glow, 2.0) * 0.10
  );

  // This is an overlay over Substrate's normal BACKGROUND layer, not a
  // replacement for the theme engine.
  let alpha = clamp(0.56 * l.p0.z, 0.0, 0.82);

  return vec4<f32>(col, alpha);
}

// -----------------------------------------------------------------------------
// GPU sprite square.
//
// Each square gets deterministic random:
// - start position
// - direction
// - linear speed
// - size
// - wander amplitude/frequencies/phases
// - active theme color
//
// No per-pixel loop over all squares: each square is one GPU sprite.
// -----------------------------------------------------------------------------

fn primitiveSprite(idx: u32, l: Layer) -> SpriteData {
  let fi = f32(idx);

  let minSize = max(l.p1.y, 1.0);
  let maxSize = max(l.p1.z, minSize);
  let wanderBase = max(l.p1.w, 0.0);

  let seed0 = fsqHash11(fi * 1.137 + 1.0);
  let seed1 = fsqHash11(fi * 2.713 + 7.0);
  let seed2 = fsqHash11(fi * 4.193 + 13.0);
  let seed3 = fsqHash11(fi * 7.917 + 23.0);
  let seed4 = fsqHash11(fi * 11.731 + 31.0);
  let seed5 = fsqHash11(fi * 17.113 + 47.0);
  let seed6 = fsqHash11(fi * 23.771 + 59.0);
  let seed7 = fsqHash11(fi * 31.337 + 71.0);

  // Strongly biased toward smaller squares while retaining occasional
  // large foreground squares.
  let sizeRnd = pow(seed2, 2.15);
  let size = mix(minSize, maxSize, sizeRnd);
  let halfSize = size * 0.5;

  let margin = maxSize + wanderBase + 8.0;
  let span = g.viewport.xy + vec2<f32>(margin * 2.0);

  let start = vec2<f32>(
    seed0 * span.x - margin,
    seed1 * span.y - margin
  );

  let angle = seed3 * TAU;
  let dir = vec2<f32>(cos(angle), sin(angle));
  let side = vec2<f32>(-dir.y, dir.x);

  let moveSpeed = mix(16.0, 88.0, seed4) * max(l.p0.x, 0.0);

  let t = g.viewport.w;

  // Two independent low-frequency oscillations prevent the collection from
  // reading like a set of straight conveyor belts.
  let freqA = mix(0.10, 0.43, seed5);
  let freqB = mix(0.08, 0.31, seed6);

  let phaseA = seed6 * TAU;
  let phaseB = seed7 * TAU;

  let wander = wanderBase * mix(0.35, 1.0, seed7);

  let noiseOffset = side * sin(t * freqA + phaseA) * wander + dir * cos(t * freqB + phaseB) * wander * 0.38;

  let rawPos = start + dir * (t * moveSpeed) + noiseOffset;

  let center = vec2<f32>(
    modp(rawPos.x + margin, span.x) - margin,
    modp(rawPos.y + margin, span.y) - margin
  );

  // Entirely theme driven. No source-shader blue remains.
  let mixPS = fsqHash11(fi * 41.71 + 5.0);
  var col = mix(g.primary.rgb, g.secondary.rgb, mixPS);

  let accentPick = fsqHash11(fi * 53.17 + 19.0);
  if accentPick > 0.78 {
    col = mix(col, g.accent.rgb, 0.72);
  }

  let alphaVariation = mix(
    0.24,
    0.82,
    fsqHash11(fi * 67.31 + 29.0)
  );

  let alpha = alphaVariation * clamp(l.p0.z, 0.0, 1.0);

  // Sprite mode 3 = rectangle in the current shared renderer.
  // extent is the generated quad radius; params.xy are rectangle half extents.
  return SpriteData(
    center,
    halfSize + 1.5,
    3u,
    vec4<f32>(halfSize, halfSize, 0.0, 0.0),
    vec4<f32>(col, alpha),
    vec4<f32>(0.0)
  );
}
