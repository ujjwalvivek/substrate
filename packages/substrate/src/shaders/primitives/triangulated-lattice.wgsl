/* @substrate
{
  "name": "triangulated-lattice",
  "label": "TRIANGULATED LATTICE",
  "order": 250,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    {
      "key": "sceneScale",
      "slot": 0,
      "default": 4.1,
      "type": "number"
    },
    {
      "key": "jitter",
      "slot": 1,
      "default": 0.45,
      "type": "number"
    },
    {
      "key": "drift",
      "slot": 2,
      "default": 0.15,
      "type": "number"
    },
    {
      "key": "colorVariation",
      "slot": 3,
      "default": 1.0,
      "type": "number"
    }
  ]
}
*/

// -----------------------------------------------------------------------------
// TRIANGULATED LATTICE
//
// Theme-reactive WGSL port of "ice and fire" by mattz.
//
// Preserves:
// - jittered triangular lattice
// - Catmull-Rom motion of lattice vertices
// - barycentric interpolation
// - per-triangle/per-vertex random color variation
// - scene-wide slowly rotating color gradient
// - anti-aliased triangle boundaries
//
// Theme mapping:
//   g.primary / g.secondary / g.accent = moving triangle palette
//   g.background = subtle tonal anchor only
//
// Global controls:
//   l.p0.x = SPEED
//   l.p0.y = DENSITY
//   l.p0.z = OPACITY
//
// Shader params:
//   l.p1.x = sceneScale
//   l.p1.y = jitter
//   l.p1.z = drift
//   l.p1.w = colorVariation
//
// common.wgsl already provides TAU.
// -----------------------------------------------------------------------------

const IFT_S3: f32 = 1.7320508075688772;
const IFT_I3: f32 = 0.5773502691896258;

const IFT_TRI2CART: mat2x2<f32> = mat2x2<f32>(
  vec2<f32>(1.0, 0.0),
  vec2<f32>(-0.5, 0.5 * IFT_S3)
);

const IFT_CART2TRI: mat2x2<f32> = mat2x2<f32>(
  vec2<f32>(1.0, 0.0),
  vec2<f32>(IFT_I3, 2.0 * IFT_I3)
);

struct IftTriVert {
  pos: vec2<f32>,
  id: vec2<f32>,
};

fn iftHash12(p: vec2<f32>) -> f32 {
  var p3 = fract(vec3<f32>(p.x, p.y, p.x) * 0.1031);
  let d = dot(
    p3,
    vec3<f32>(p3.y, p3.z, p3.x) + vec3<f32>(19.19)
  );
  p3   += vec3<f32>(d);
  return fract((p3.x + p3.y) * p3.z);
}

fn iftHash23(pIn: vec3<f32>) -> vec2<f32> {
  var p3 = fract(
    pIn * vec3<f32>(443.897, 441.423, 437.195)
  );

  let d = dot(
    p3,
    vec3<f32>(p3.y, p3.z, p3.x) + vec3<f32>(19.19)
  );

  p3   += vec3<f32>(d);

  return fract(
    (vec2<f32>(p3.x, p3.x) + vec2<f32>(p3.y, p3.z)) * vec2<f32>(p3.z, p3.y)
  );
}

fn iftBary(
  v0: vec2<f32>,
  v1: vec2<f32>,
  v2: vec2<f32>
) -> vec3<f32> {
  let denom = v0.x * v1.y - v1.x * v0.y;

  // The jittered lattice should never be truly degenerate, but protect the
  // fragment shader from NaNs if two animated vertices get extremely close.
  let safeDenom = select(
    -0.000001,
    0.000001,
    denom >= 0.0
  );

  let invDenom = 1.0 / select(
    safeDenom,
    denom,
    abs(denom) > 0.000001
  );

  let v = (v2.x * v1.y - v1.x * v2.y) * invDenom;
  let w = (v0.x * v2.y - v2.x * v0.y) * invDenom;
  let u = 1.0 - v - w;

  return vec3<f32>(u, v, w);
}

fn iftDseg(
  xa: vec2<f32>,
  ba: vec2<f32>
) -> f32 {
  let denom = max(dot(ba, ba), 0.000001);
  let h = clamp(dot(xa, ba) / denom, 0.0, 1.0);
  return length(xa - ba * h);
}

fn iftRandCircle(p: vec3<f32>) -> vec2<f32> {
  let rt = iftHash23(p);
  let r = sqrt(rt.x);
  let theta = TAU * rt.y;

  return r * vec2<f32>(
    cos(theta),
    sin(theta)
  );
}

fn iftRandCircleSpline(
  p: vec2<f32>,
  timeIn: f32
) -> vec2<f32> {
  let t1 = floor(timeIn);
  let t = fract(timeIn);

  let pa = iftRandCircle(vec3<f32>(p, t1 - 1.0));
  let p0 = iftRandCircle(vec3<f32>(p, t1));
  let p1 = iftRandCircle(vec3<f32>(p, t1 + 1.0));
  let pb = iftRandCircle(vec3<f32>(p, t1 + 2.0));

  let m0 = 0.5 * (p1 - pa);
  let m1 = 0.5 * (pb - p0);

  let c3 = 2.0 * p0 - 2.0 * p1 + m0 + m1;
  let c2 = -3.0 * p0 + 3.0 * p1 - 2.0 * m0 - m1;
  let c1 = m0;
  let c0 = p0;

  return (((c3 * t + c2) * t + c1) * t + c0) * 0.8;
}

fn iftTriPoint(
  p: vec2<f32>,
  time: f32,
  jitter: f32,
  drift: f32
) -> vec2<f32> {
  let t0 = iftHash12(p);

  return
    IFT_TRI2CART * p + jitter * iftRandCircleSpline(
        p,
        drift * time + t0
      );
}

// Cosine-like three-way theme palette.
//
// Instead of the source's baked RGB cosine palette, use three 120-degree
// cosine lobes to continuously blend Substrate primary/secondary/accent.
fn iftPalette(
  tIn: f32,
  variation: f32
) -> vec3<f32> {
  let t = fract(tIn);

  let phase = TAU * t;

  let w0 = 0.5 + 0.5 * cos(phase);
  let w1 = 0.5 + 0.5 * cos(phase - TAU / 3.0);
  let w2 = 0.5 + 0.5 * cos(phase - 2.0 * TAU / 3.0);

  let sumW = max(w0 + w1 + w2, 0.000001);

  var col = (g.primary.rgb * w0 + g.secondary.rgb * w1 + g.accent.rgb * w2) / sumW;

  // Preserve some of the original shader's high-contrast "ice/fire" feel.
  let contrast = mix(0.78, 1.22, clamp(variation, 0.0, 1.5) / 1.5);
  col = (col - vec3<f32>(0.5)) * contrast + vec3<f32>(0.5);

  // Tiny theme-background anchor; not enough to muddy the tessellation.
  col = mix(
    clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)),
    g.background.rgb,
    0.035
  );

  return clamp(
    col,
    vec3<f32>(0.0),
    vec3<f32>(1.0)
  );
}

fn iftTriColor(
  p: vec2<f32>,
  t0: IftTriVert,
  t1: IftTriVert,
  t2: IftTriVert,
  scl: f32,
  time: f32,
  variation: f32
) -> vec4<f32> {
  let p0 = p - t0.pos;
  let p10 = t1.pos - t0.pos;
  let p20 = t2.pos - t0.pos;

  let bary = iftBary(
    p10,
    p20,
    p0
  );

  let d10 = iftDseg(p0, p10);
  let d20 = iftDseg(p0, p20);
  let d21 = iftDseg(
    p - t1.pos,
    t2.pos - t1.pos
  );

  var d = min(
    min(d10, d20),
    d21
  );

  d   *= -sign(
    min(
      bary.x,
      min(bary.y, bary.z)
    )
  );

  if d >= 0.5 * scl {
    return vec4<f32>(0.0);
  }

  let tsum = t0.id + t1.id + t2.id;

  var hTri = vec3<f32>(
    iftHash12(tsum + t0.id),
    iftHash12(tsum + t1.id),
    iftHash12(tsum + t2.id)
  );

  let center = (t0.pos + t1.pos + t2.pos) / 3.0;

  let theta = 1.0 + 0.01 * time;

  let direction = vec2<f32>(
    cos(theta),
    sin(theta)
  );

  let gradInput = dot(center, direction) - sin(0.05 * time);

  let h0 = sin(0.7 * gradInput) * 0.5 + 0.5;

  // Source used 0.4 random vertex variation.
  let randomBias = 0.4 * clamp(variation, 0.0, 1.5);

  hTri = mix(
    vec3<f32>(h0),
    hTri,
    randomBias
  );

  let h = dot(hTri, bary);

  let color = iftPalette(
      h,
      variation
    );

  // Source uses reversed smoothstep edges to get an inverse AA ramp.
  // Express that explicitly in WGSL instead of relying on reversed-edge
  // smoothstep behavior.
  let weight = 1.0 - smoothstep(
      -0.5 * scl,
       0.5 * scl,
       d
    );

  return vec4<f32>(
    weight * color,
    weight
  );
}

fn primitiveFull(
  pix: vec2<f32>,
  l: Layer
) -> vec4<f32> {
  let viewport = max(
      g.viewport.xy,
      vec2<f32>(1.0)
    );

  let speed = max(l.p0.x, 0.0);

  let density = max(l.p0.y, 0.05);

  let opacity = clamp(
      l.p0.z,
      0.0,
      1.0
    );

  let baseSceneScale = max(l.p1.x, 0.25);

  let jitter = clamp(
      l.p1.y,
      0.0,
      1.25
    );

  let drift = max(
      l.p1.z,
      0.0
    );

  let variation = max(
      l.p1.w,
      0.0
    );

  let time = g.viewport.w * speed;

  // Density means actual triangle density here:
  // higher values create more/smaller triangles, lower values fewer/larger.
  // sqrt keeps the control from behaving like an aggressive camera zoom.
  let sceneScale = baseSceneScale * sqrt(density);

  let scl = sceneScale / viewport.y;

  let p = (pix - vec2<f32>(0.5) - 0.5 * viewport) * scl;

  let tfloor = floor(
      IFT_CART2TRI * p + vec2<f32>(0.5)
    );

  var pts: array<vec2<f32>, 9>;

  for (var i: i32 = 0; i < 3; i = i + 1
  ) {
    for (var j: i32 = 0; j < 3; j = j + 1
    ) {
      let id = tfloor + vec2<f32>(
          f32(i - 1),
          f32(j - 1)
        );

      pts[3 * i + j] = iftTriPoint(
          id,
          time,
          jitter,
          drift
        );
    }
  }

  var cw = vec4<f32>(0.0);

  for (var i: i32 = 0; i < 2; i = i + 1
  ) {
    for (var j: i32 = 0; j < 2; j = j + 1
    ) {
      let t00 = IftTriVert(
        pts[3 * i + j],
        tfloor + vec2<f32>(
          f32(i - 1),
          f32(j - 1)
        )
      );

      let t10 = IftTriVert(
        pts[3 * i + j + 3],
        tfloor + vec2<f32>(
          f32(i),
          f32(j - 1)
        )
      );

      let t01 = IftTriVert(
        pts[3 * i + j + 1],
        tfloor + vec2<f32>(
          f32(i - 1),
          f32(j)
        )
      );

      let t11 = IftTriVert(
        pts[3 * i + j + 4],
        tfloor + vec2<f32>(
          f32(i),
          f32(j)
        )
      );

      cw   += iftTriColor(
        p,
        t00,
        t10,
        t11,
        scl,
        time,
        variation
      );

      cw   += iftTriColor(
        p,
        t00,
        t11,
        t01,
        scl,
        time,
        variation
      );
    }
  }

  // Normally one of the surrounding triangles always covers the pixel.
  // Guard the divide anyway to avoid NaN propagation during extreme jitter.
  if cw.w <= 0.000001 {
    return vec4<f32>(
      g.background.rgb,
      opacity
    );
  }

  let color = cw.xyz / cw.w;

  return vec4<f32>(
    clamp(
      color,
      vec3<f32>(0.0),
      vec3<f32>(1.0)
    ),
    opacity
  );
}
