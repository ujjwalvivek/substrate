/* @substrate
{
  "name": "gris-pause",
  "label": "GRIS PAUSE",
  "order": 450,
  "modes": ["feedback"],
  "blend": "source-over",
  "feedback": { "format": "rgba16float" },
  "params": [
    { "key": "turn", "slot": 0, "default": 0.0, "type": "number" },
    { "key": "lift", "slot": 1, "default": 0.0, "type": "number" }
  ]
}
*/

// Port of Genis Sole's GRIS pause-menu shader.
//
// Buffer A stores the two scalar controls used by the original keyboard
// texture. Image reads that state and draws the animated dotted geometry.
// Substrate maps the original left/right/up inputs to l.p1.x / l.p1.y:
//   turn: negative = left, positive = right
//   lift: positive = up/brake

const GRIS_PI: f32 = 3.14159;

fn grisPoint(uv: vec2<f32>, edge: f32, width: f32, radius: f32) -> f32 {
  return 1.0 - smoothstep(width, width + edge, length(uv) - radius);
}

fn grisCircle(uv: vec2<f32>, edge: f32, width: f32, radius: f32) -> f32 {
  return 1.0 - smoothstep(width, width + edge, abs(length(uv) - radius));
}

fn grisDottedCircle(
  uv: vec2<f32>,
  edge: f32,
  width: f32,
  radius: f32,
  pointRadius: f32
) -> f32 {
  let safeCount = max(floor(290.0 * 2.0 * PI * radius), 1.0);
  var t = (atan2(uv.y, uv.x) / GRIS_PI) * 0.5 + 0.5;
  t = (floor(t * safeCount) + 0.5) / safeCount;
  t = (t * 2.0 - 1.0) * GRIS_PI;
  return grisPoint(
    uv - vec2<f32>(cos(t), sin(t)) * radius,
    edge,
    width,
    pointRadius
  );
}

fn grisDottedLine(
  uvIn: vec2<f32>,
  edge: f32,
  width: f32,
  pointRadius: f32,
  a: vec2<f32>,
  bIn: vec2<f32>
) -> f32 {
  let b = bIn - a;
  var uv = uvIn - a;
  let direction = normalize(b);
  let perpendicular = vec2<f32>(-direction.y, direction.x);
  uv = vec2<f32>(dot(uv, direction), dot(uv, perpendicular));

  return grisPoint(
    vec2<f32>((fract(uv.x * 290.0) - 0.5) / 290.0, uv.y),
    edge,
    width,
    pointRadius
  );
}

fn grisRings(
  uv: vec2<f32>,
  edge: f32,
  width: f32,
  radius: f32,
  spacing: f32,
  count: f32
) -> f32 {
  let distanceToCenter = length(uv);
  let outer = radius + spacing * (count - 1.0);
  let steppedRings = smoothstep(
    width,
    width + edge,
    abs((fract((distanceToCenter - spacing * 0.5) / spacing - fract(radius / spacing)) - 0.5) * spacing)
  );
  let endCaps = smoothstep(width, width + edge, abs(distanceToCenter - radius)) *
    smoothstep(width, width + edge, abs(distanceToCenter - outer));

  return 1.0 - min(
    max(
      max(step(distanceToCenter, radius), step(outer, distanceToCenter)),
      steppedRings
    ),
    endCaps
  );
}

fn grisRings2(
  uv: vec2<f32>,
  edge: f32,
  width: f32,
  radius: f32,
  spacing: f32
) -> f32 {
  let distanceToCenter = length(uv);
  return 1.0 - smoothstep(width, width + edge, abs(distanceToCenter - radius)) *
    smoothstep(width, width + edge, abs(distanceToCenter - (radius + spacing)));
}

fn grisRot(t: f32) -> mat2x2<f32> {
  let s = sin(t);
  let c = cos(t);
  return mat2x2<f32>(vec2<f32>(c, s), vec2<f32>(-s, c));
}

fn grisReadState() -> vec4<f32> {
  let dimensions = vec2<f32>(textureDimensions(feedbackTexture));
  let uv = vec2<f32>(0.5) / max(dimensions, vec2<f32>(1.0));
  return textureSample(feedbackTexture, feedbackSampler, uv);
}

fn primitiveFeedback(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  // Buffer A only needs one state texel. Return transparent state elsewhere.
  if (fragCoord.x >= 1.0 || fragCoord.y >= 1.0) {
    return vec4<f32>(0.0);
  }

  var state = grisReadState();
  if (g.info.y == 0.0) {
    state = vec4<f32>(-1.0);
  }

  let frameRate = max(g.info.x, 1.0);
  let deltaTime = 1.0 / frameRate;
  let turn = l.p1.x;
  let lift = max(l.p1.y, 0.0);

  state.x += (state.y - state.x) * deltaTime * 10.0;
  state.y += 2.0 * turn - lift * state.y;
  state = clamp(state, vec4<f32>(-1.0), vec4<f32>(1.0));
  return state;
}

fn grisImage(uv: vec2<f32>, time: f32, state: vec4<f32>, density: f32) -> f32 {
  let edge = 1.5 / max(g.viewport.x, 1.0);
  let linePoint = vec2<f32>(0.0, 0.19);
  var coverage = grisDottedLine(abs(uv), edge, 0.0001, 0.0, linePoint, linePoint.yx);

  let diagonalUv = (1.0 / sqrt(2.0)) * vec2<f32>(uv.x + uv.y, uv.x - uv.y);
  coverage += grisDottedLine(abs(diagonalUv), edge, 0.0002, 0.0, linePoint, linePoint.yx);

  coverage += grisDottedCircle(uv * grisRot(time * 0.4), edge, 0.0, 0.01375, 0.0001);
  coverage += grisDottedCircle(uv * grisRot(-time * 0.3), edge, 0.0, 0.03125, 0.0001);
  coverage += grisDottedCircle(uv * grisRot(time * 0.1), edge, 0.0, 0.09625, 0.0001);
  coverage += grisDottedCircle(grisRot(time * 0.1) * uv, edge, 0.0, 0.37, 0.0001);
  coverage *= 0.3;

  coverage += grisRings2(uv, edge, 0.0, 0.008125, 0.0025);
  coverage += grisRings2(uv, edge, 0.0, 0.02187, 0.05875);
  coverage += grisRings2(uv, edge, 0.0, 0.10125, 0.06125);
  coverage += grisRings2(uv, edge, 0.0, 0.439375, 0.03125);

  coverage += grisRings2(uv, edge, 0.0005, 0.075, 0.040625);
  coverage += grisCircle(uv, edge, 0.0005, 0.339375);

  coverage += grisRings2(uv, edge, 0.001, 0.026875, 0.163125);
  coverage += grisCircle(uv, edge, 0.001, 0.448125);

  let p1 = grisRot(time * GRIS_PI * 0.028) * uv - vec2<f32>(0.115625, 0.0);
  coverage += grisPoint(p1, edge, 0.0, 0.004375);
  coverage += grisCircle(p1, edge, 0.0, 0.004375 * 2.0);

  let p2 = grisRot(time * GRIS_PI * 0.067 + 0.5) * uv - vec2<f32>(0.1625, 0.0);
  coverage += grisPoint(p2, edge, 0.0, 0.0015625);
  coverage += grisRings2(p2, edge, 0.0, 0.004375, 0.001875);

  let controlPhase = state.x * GRIS_PI * 0.5;
  let p3 = uv - vec2<f32>(sin(controlPhase), cos(controlPhase)) * 0.19;
  coverage += grisPoint(p3, edge, 0.0, 0.005);
  coverage += grisRings(p3, edge, 0.0, 0.005 * 2.0, 0.002375, 4.0);
  coverage += 0.3 * grisDottedCircle(grisRot(time) * p3, edge, 0.0, 0.0195, 0.0001);

  let p4 = grisRot(time * GRIS_PI * 0.028 + GRIS_PI * 1.2) * uv - vec2<f32>(0.339375, 0.0);
  coverage += grisPoint(p4, edge, 0.0, 0.00875);
  coverage += grisRings2(p4, edge, 0.0, 0.011875, 0.001875);
  coverage += grisCircle(p4, edge, 0.0, 0.021875);
  coverage += grisPoint(grisRot(time * GRIS_PI * 0.143) * p4 - vec2<f32>(0.021875, 0.0), edge, 0.0, 0.003125);

  let p5 = grisRot(time * GRIS_PI * 0.00833 + GRIS_PI * 1.3) * uv - vec2<f32>(0.448125, 0.0);
  coverage += grisPoint(p5, edge, 0.0, 0.0028125);
  coverage += grisRings2(p5, edge, 0.0, 0.00875, 0.003125);
  coverage += 0.3 * grisDottedCircle(grisRot(time) * p5, edge, 0.0, 0.015, 0.0001);

  let p6 = grisRot(time * GRIS_PI * 0.011) * uv - vec2<f32>(0.439375 + 0.03125, 0.0);
  coverage += grisPoint(p6, edge, 0.0, 0.005);
  coverage += 0.3 * grisDottedCircle(grisRot(time) * p6, edge, 0.0, 0.0078125, 0.0001);
  coverage += grisCircle(p6, edge, 0.0, 0.0175);
  let sp6 = grisRot(time * GRIS_PI * 0.27) * p6 - vec2<f32>(0.0175, 0.0);
  coverage += grisPoint(sp6, edge, 0.0, 0.0009375);
  coverage += grisCircle(sp6, edge, 0.0, 0.004375);

  // Density changes intensity only; the original geometry has fixed radii.
  let densityGain = 0.9 + 0.1 * sqrt(clamp(density, 0.1, 2.25));
  return clamp(coverage * densityGain, 0.0, 1.0);
}

fn primitiveFeedbackPresent(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let speed = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.1);
  let time = g.viewport.w * speed;
  let uv = (fragCoord - resolution * 0.5) / resolution.x;
  let state = grisReadState();

  let coverage = grisImage(uv, time, state, density);
  let value = pow(0.8 * coverage, 0.4545);
  let tint = mix(vec3<f32>(1.0), g.primary.rgb, 0.08);
  let opacity = clamp(l.p0.z, 0.0, 1.0);
  return vec4<f32>(tint * value, opacity);
}
