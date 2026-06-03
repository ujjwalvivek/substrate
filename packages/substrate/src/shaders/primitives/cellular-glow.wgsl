/* @substrate
{
  "name": "cellular-glow",
  "label": "CELLULAR GLOW",
  "order": 380,
  "modes": ["full"],
  "blend": "source-over",
  "params": []
}
*/

// Port of a small animated grid-cell shader. Each cell gets a deterministic
// brightness, a slowly shifting RGB color, and shadows cast by brighter cells.

fn cgRand(co: vec2<f32>) -> f32 {
  return fract(sin(dot(co, vec2<f32>(12.9898, 78.233))) * 43758.5453);
}

fn cgCellBright(id: vec2<f32>, time: f32) -> f32 {
  return sin((time + 2.0) * cgRand(id) * 2.0) * 0.5 + 0.5;
}

fn cgThemeColor(phase: f32) -> vec3<f32> {
  let primarySecondary = mix(
    g.primary.rgb,
    g.secondary.rgb,
    0.5 + 0.5 * sin(phase)
  );
  return mix(primarySecondary, g.accent.rgb, 0.25 + 0.25 * sin(phase * 0.7 + 1.0));
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let maximum = max(resolution.x, resolution.y);
  let time = g.viewport.w * max(l.p0.x, 0.0) * 0.5;
  let density = sqrt(clamp(l.p0.y, 0.1, 4.0));
  var uv = fragCoord / maximum;
  uv *= 30.0 * density;

  let id = floor(uv);
  let cellUv = fract(uv) - vec2<f32>(0.5);
  let brightness = cgCellBright(id, time);
  let cellPhase = time + dot(id, vec2<f32>(0.17, 0.11));
  let colorShift = cgThemeColor(cellPhase);
  var color = mix(
    g.background.rgb,
    colorShift,
    0.28 + brightness * 0.52
  );
  color += 0.08 * cos(time + id.xyx * 0.1 + vec3<f32>(4.0, 2.0, 1.0));

  var shadow = 0.0;
  shadow += smoothstep(
    0.0,
    0.7,
    cellUv.x * min(0.0, cgCellBright(vec2<f32>(id.x - 1.0, id.y), time) - brightness)
  );
  shadow += smoothstep(
    0.0,
    0.7,
    -cellUv.y * min(0.0, cgCellBright(vec2<f32>(id.x, id.y + 1.0), time) - brightness)
  );

  color -= shadow * 0.4;
  color *= 1.0 - brightness * 0.2;

  return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), clamp(l.p0.z, 0.0, 1.0));
}
