/* @substrate
{
  "name": "tiling-cubes",
  "label": "TILING CUBES",
  "order": 500,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "tileScale",  "slot": 0, "default": 10.0, "type": "number" },
    { "key": "tileWidth",  "slot": 1, "default": 2.0,  "type": "number" },
    { "key": "tileHeight", "slot": 2, "default": 2.3,  "type": "number" },
    { "key": "lineWidth",  "slot": 3, "default": 15.0, "type": "number" },
    { "key": "color",      "slot": 4, "default": "primary", "type": "color" }
  ]
}
*/

// Variant of https://shadertoy.com/view/McS3DW.
// The projected cube tiles retain the original rotating, offset arrangement.

fn tcRotate(point: vec2<f32>, angle: f32) -> vec2<f32> {
  let s = sin(angle);
  let c = cos(angle);
  return vec2<f32>(c * point.x - s * point.y, s * point.x + c * point.y);
}

fn tcSegmentDistance(pointIn: vec2<f32>, aIn: vec2<f32>, bIn: vec2<f32>) -> f32 {
  var point = pointIn - aIn;
  let b = bIn - aIn;
  let projection = clamp(dot(point, b) / max(dot(b, b), 0.00001), 0.0, 1.0);
  return length(point - b * projection);
}

fn tcProject(pointIn: vec3<f32>, angle: f32) -> vec2<f32> {
  var point = pointIn;
  var xy = tcRotate(vec2<f32>(point.x, point.y), -angle);
  point.x = xy.x;
  point.y = xy.y;
  var xz = tcRotate(vec2<f32>(point.x, point.z), 0.785);
  point.x = xz.x;
  point.z = xz.y;
  var yz = tcRotate(vec2<f32>(point.y, point.z), -0.625);
  point.y = yz.x;
  point.z = yz.y;
  return point.xy;
}

fn tcEdge(
  point: vec2<f32>,
  a: vec3<f32>,
  b: vec3<f32>,
  angle: f32,
  lineWidth: f32,
  cubeScale: f32
) -> f32 {
  let projectedA = tcProject(a * cubeScale, angle);
  let projectedB = tcProject(b * cubeScale, angle);
  let distanceToEdge = tcSegmentDistance(point, projectedA, projectedB);
  return 1.0 - smoothstep(0.0, lineWidth, distanceToEdge);
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let speed = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.05);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let tileScale = max(l.p1.x, 0.1);
  let tileSize = vec2<f32>(max(l.p1.y, 0.1), max(l.p1.z, 0.1));
  let lineWidth = clamp(l.p1.w, 0.25, 40.0) / resolution.y;
  let cubeColor = palette(i32(l.p2.x));
  let time = g.viewport.w * speed;

  // WebGPU fragment coordinates grow downward; Shadertoy coordinates grow
  // upward, so use the source orientation for the cube tiling.
  let sourceCoord = vec2<f32>(fragCoord.x, resolution.y - fragCoord.y);
  let densityScale = clamp(0.55 + 0.45 * density, 0.55, 1.6);
  var uv = tileScale * densityScale * sourceCoord / resolution.y;
  let tileOrigin = floor(uv / tileSize) * tileSize;
  uv = vec2<f32>(modp(uv.x, tileSize.x), modp(uv.y, tileSize.y));

  // The source cube is wider than the spacing between its lattice points.
  // Scale it to leave a deliberate gap so neighboring wireframes remain
  // readable instead of merging into one continuous mesh.
  let cubeScale = min(tileSize.x / 2.45, tileSize.y / 2.35) * 0.86;

  var coverage = 0.0;
  for (var k: i32 = 0; k < 4; k = k + 1) {
    var offset = vec2<f32>(f32(k % 2), f32(k / 2)) * tileSize;
    let cell = tileOrigin + offset;
    // A continuous angular phase avoids the hard reset introduced by the
    // source's wrapped time expression, so every cube turns cleanly.
    let angle = time * 0.22 + (cell.x + cell.y) * 0.12;

    for (var edge: i32 = 0; edge < 4; edge = edge + 1) {
      let a = f32(edge) * 1.57;
      var pointA = vec3<f32>(cos(a), sin(a), 0.7);
      let pointB = vec3<f32>(-pointA.y, pointA.x, 0.7);

      coverage += tcEdge(uv - offset, pointA, pointB, angle, lineWidth, cubeScale);
      coverage += tcEdge(uv - offset, pointA, pointA * vec3<f32>(1.0, 1.0, -1.0), angle, lineWidth, cubeScale);

      pointA.z = -pointA.z;
      var flippedB = pointB;
      flippedB.z = -flippedB.z;
      coverage += tcEdge(uv - offset, pointA, flippedB, angle, lineWidth, cubeScale);
    }
  }

  let value = clamp(coverage, 0.0, 1.0);
  return vec4<f32>(cubeColor * value, opacity * value);
}
