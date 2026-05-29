/* @substrate
{
  "name": "voronoi-perlin",
  "label": "VORONOI PERLIN",
  "order": 340,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "voronoiScale", "slot": 0, "default": 35.0, "type": "number" },
    { "key": "perlinScale",  "slot": 1, "default": 7.0,  "type": "number" },
    { "key": "noiseSpeed",   "slot": 2, "default": 0.3,  "type": "number" },
    { "key": "contrast",     "slot": 3, "default": 1.0,  "type": "number" }
  ]
}
*/

fn vpHash22(p: vec2<f32>) -> vec2<f32> {
  var p3 = fract(vec3<f32>(p.x, p.y, p.x) * vec3<f32>(443.897, 441.423, 437.195));
  let d = dot(p3, vec3<f32>(p3.y, p3.z, p3.x) + vec3<f32>(19.19));
  p3   += vec3<f32>(d);

  return fract(
    (vec2<f32>(p3.x, p3.x) + vec2<f32>(p3.y, p3.z)) * vec2<f32>(p3.z, p3.y)
  );
}

fn vpHash33(pIn: vec3<f32>) -> vec3<f32> {
  var p3 = fract(pIn * vec3<f32>(443.897, 441.423, 437.195));
  let d = dot(p3, vec3<f32>(p3.y, p3.x, p3.z) + vec3<f32>(19.19));
  p3   += vec3<f32>(d);

  return fract(
    (vec3<f32>(p3.x, p3.x, p3.y) + vec3<f32>(p3.y, p3.x, p3.x)) * vec3<f32>(p3.z, p3.y, p3.x)
  );
}

fn vpFade3(t: vec3<f32>) -> vec3<f32> {
  return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

fn vpGradient3D(p: vec3<f32>) -> vec3<f32> {
  return normalize(-vec3<f32>(1.0) + 2.0 * vpHash33(p));
}

fn vpPerlin3D(p: vec3<f32>) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let u = vpFade3(f);

  let v000 = dot(vpGradient3D(i + vec3<f32>(0.0,0.0,0.0)), f - vec3<f32>(0.0,0.0,0.0));
  let v100 = dot(vpGradient3D(i + vec3<f32>(1.0,0.0,0.0)), f - vec3<f32>(1.0,0.0,0.0));
  let v010 = dot(vpGradient3D(i + vec3<f32>(0.0,1.0,0.0)), f - vec3<f32>(0.0,1.0,0.0));
  let v110 = dot(vpGradient3D(i + vec3<f32>(1.0,1.0,0.0)), f - vec3<f32>(1.0,1.0,0.0));
  let v001 = dot(vpGradient3D(i + vec3<f32>(0.0,0.0,1.0)), f - vec3<f32>(0.0,0.0,1.0));
  let v101 = dot(vpGradient3D(i + vec3<f32>(1.0,0.0,1.0)), f - vec3<f32>(1.0,0.0,1.0));
  let v011 = dot(vpGradient3D(i + vec3<f32>(0.0,1.0,1.0)), f - vec3<f32>(0.0,1.0,1.0));
  let v111 = dot(vpGradient3D(i + vec3<f32>(1.0,1.0,1.0)), f - vec3<f32>(1.0,1.0,1.0));

  return mix(
    mix(mix(v000,v100,u.x), mix(v010,v110,u.x), u.y),
    mix(mix(v001,v101,u.x), mix(v011,v111,u.x), u.y),
    u.z
  );
}

fn vpVoronoiPoint(p: vec2<f32>) -> vec2<f32> {
  let i = floor(p);
  let f = fract(p);

  var minDist = 5.0;
  var closestPoint = vec2<f32>(0.0);

  for (var j: i32 = -1; j <= 1; j = j + 1) {
    for (var k: i32 = -1; k <= 1; k = k + 1) {
      let relativeCell = vec2<f32>(f32(j), f32(k));
      let point = vpHash22(i + relativeCell);
      let dist = distance(f, relativeCell + point);

      if dist < minDist {
        minDist = dist;
        closestPoint = i + relativeCell + point;
      }
    }
  }

  return closestPoint;
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));

  let globalSpeed = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.05);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let baseVorScale = max(l.p1.x, 1.0);
  let perlinScale = max(l.p1.y, 0.1);
  let noiseSpeed = max(l.p1.z, 0.0);
  let contrast = max(l.p1.w, 0.0);

  let uv = fragCoord / resolution;

  var p = uv - vec2<f32>(0.5);
  p.x   *= resolution.x / resolution.y;

  // Here density semantically means more/fewer Voronoi cells.
  // Use a gentle exponent so the control does not feel like camera zoom.
  let vorScale = baseVorScale * pow(density, 0.35);

  let voroPoint = vpVoronoiPoint(p * vorScale) / vorScale;

  var val = vpPerlin3D(
    vec3<f32>(
      voroPoint * perlinScale,
      g.viewport.w * globalSpeed * noiseSpeed
    )
  );

  val = val * 0.5 + 0.5;
  val = clamp((val - 0.5) * contrast + 0.5, 0.0, 1.0);

  let low = mix(g.background.rgb, g.primary.rgb, 0.18);
  let mid = g.primary.rgb;
  let high = mix(g.secondary.rgb, g.accent.rgb, 0.55);

  var color = mix(low, mid, smoothstep(0.0, 0.55, val));
  color = mix(color, high, smoothstep(0.45, 1.0, val));

  return vec4<f32>(
    clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)),
    opacity
  );
}
