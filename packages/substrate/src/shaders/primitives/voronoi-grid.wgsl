/* @substrate
{
  "name": "voronoi-grid",
  "label": "VORONOI GRID",
  "order": 460,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "cellScale",  "slot": 0, "default": 8.0,  "type": "number" },
    { "key": "gridSpacing", "slot": 1, "default": 0.1,  "type": "number" },
    { "key": "lineWidth",   "slot": 2, "default": 2.0,  "type": "number" },
    { "key": "contrast",    "slot": 3, "default": 1.0,  "type": "number" },
    { "key": "color",       "slot": 4, "default": "primary", "type": "color" }
  ]
}
*/

// Animated Voronoi cells with a thin normalized grid overlay.
// The original Shadertoy inputs are mapped as follows:
//   iTime       -> g.viewport.w * speed
//   iResolution -> g.viewport.xy
//   color       -> the declared theme palette parameter

fn vgRand2(p: vec2<f32>) -> vec2<f32> {
  return fract(vec2<f32>(
    sin(p.x * 591.32 + p.y * 154.077),
    cos(p.x * 391.32 + p.y * 49.077)
  ));
}

fn vgVoronoi(x: vec2<f32>, time: f32) -> f32 {
  let cell = floor(x);
  let local = fract(x);
  var minDistance = 1.0;

  for (var j: i32 = -1; j <= 1; j = j + 1) {
    for (var i: i32 = -1; i <= 1; i = i + 1) {
      let offset = vec2<f32>(f32(i), f32(j));
      let random = 0.5 + 0.5 * sin(
        vec2<f32>(time * 3.0) + 12.0 * vgRand2(cell + offset)
      );
      let relative = offset - local + random;
      minDistance = min(minDistance, length(relative));
    }
  }

  return minDistance;
}

fn vgGridMask(uv: vec2<f32>, spacing: f32, lineWidth: f32) -> vec2<f32> {
  let cellPosition = vec2<f32>(
    modp(uv.x, spacing),
    modp(uv.y, spacing)
  );
  let width = clamp(lineWidth, 0.25, 16.0) / max(g.viewport.y, 1.0);
  return step(cellPosition, vec2<f32>(width));
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let speed = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.05);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let cellScale = max(l.p1.x, 0.1);
  let gridSpacing = clamp(l.p1.y, 0.01, 0.5);
  let lineWidth = max(l.p1.z, 0.0);
  let contrast = max(l.p1.w, 0.0);
  let themeColor = palette(i32(l.p2.x));

  var uv = fragCoord / resolution;
  uv.x *= resolution.x / resolution.y;

  // Density changes the number of cells without changing their proportions.
  let scaledUv = uv * cellScale * pow(density, 0.5);
  let time = g.viewport.w * speed;
  let value = pow(max(vgVoronoi(scaledUv, time) * 1.25, 0.0), 7.0) * 2.0;
  let contrasted = clamp((value - 0.5) * contrast + 0.5, 0.0, 1.0);
  let grid = vgGridMask(uv, gridSpacing, lineWidth);
  let intensity = contrasted * (grid.x + grid.y);

  return vec4<f32>(
    clamp(themeColor * intensity, vec3<f32>(0.0), vec3<f32>(1.0)),
    opacity
  );
}
