/* @substrate
{
  "name": "city-skyline",
  "label": "CITY SKYLINE",
  "order": 510,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "buildingCount", "slot": 0, "default": 20.0, "type": "number" },
    { "key": "windowDensity",  "slot": 1, "default": 0.8,  "type": "number" },
    { "key": "horizon",        "slot": 2, "default": -0.3, "type": "number" },
    { "key": "waterDepth",     "slot": 3, "default": 1.0,  "type": "number" },
    { "key": "color",          "slot": 4, "default": "primary", "type": "color" }
  ]
}
*/

// City Skyline by Noztol, adapted to Substrate's full-frame WGSL ABI.

fn csHash(value: f32) -> f32 {
  return fract(sin(value) * 43758.5453123);
}

fn csThemeTint(base: vec3<f32>, theme: vec3<f32>, amount: f32) -> vec3<f32> {
  return mix(base, mix(base, theme, 0.45), clamp(amount, 0.0, 1.0));
}

fn csThemeGrade(base: vec3<f32>, theme: vec3<f32>, strength: f32) -> vec3<f32> {
  let source = max(base, vec3<f32>(0.0));
  let luminance = clamp(dot(source, vec3<f32>(0.2126, 0.7152, 0.0722)), 0.0, 1.2);
  let shadow = mix(g.background.rgb, theme, 0.35);
  let mid = mix(theme, g.secondary.rgb, 0.45);
  let highlight = mix(g.accent.rgb, vec3<f32>(1.0), 0.25);
  var graded = mix(shadow, mid, smoothstep(0.0, 0.55, luminance));
  graded = mix(graded, highlight, smoothstep(0.45, 1.2, luminance));
  return mix(source, graded, clamp(strength, 0.0, 1.0));
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let speed = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.05);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let densityScale = clamp(0.55 + 0.45 * density, 0.55, 1.6);
  let buildingCount = max(l.p1.x, 1.0) * densityScale;
  let windowDensity = clamp(l.p1.y, 0.0, 1.0);
  let horizon = clamp(l.p1.z, -0.9, 0.1);
  let waterDepth = max(l.p1.w, 0.05);
  let themeColor = palette(i32(l.p2.x));
  // Keep the skyline and its lights fixed. Only the reflected water layer
  // uses this deliberately reduced animation time.
  let waterTime = g.viewport.w * speed * 0.22;

  // Preserve the source's bottom-left coordinate system.
  let sourceCoord = vec2<f32>(fragCoord.x, resolution.y - fragCoord.y);
  let uv = sourceCoord / resolution;
  var p = uv * 2.0 - vec2<f32>(1.0);
  p.x *= resolution.x / resolution.y;

  let isWater = p.y < horizon;
  var reflected = p;
  if (isWater) {
    reflected.y = horizon - (p.y - horizon);
    reflected.x += sin(p.y * 60.0 * densityScale + waterTime * 2.0) * 0.005 * waterDepth;
    reflected.y += cos(p.x * 30.0 * densityScale - waterTime * 1.5) * 0.003 * waterDepth;
  }

  let night = csThemeTint(vec3<f32>(0.05, 0.07, 0.12), themeColor, 0.16);
  var color = mix(night, g.background.rgb * 0.55, clamp(reflected.y + 0.3, 0.0, 1.0));

  // City silhouette and reflected window grid.
  let block = floor(reflected.x * buildingCount);
  let height = horizon + csHash(block * 123.0) * 0.4 + 0.02;
  if (reflected.y > horizon && reflected.y < height) {
    color = mix(g.background.rgb * 0.65, vec3<f32>(0.01, 0.01, 0.015), 0.55);

    let windowGrid = reflected * vec2<f32>(150.0, 200.0);
    let windowId = floor(windowGrid);
    let litThreshold = 1.0 - 0.2 * windowDensity;
    if (csHash(windowId.x * 12.3 + windowId.y * 45.6) > litThreshold) {
      let windowUv = fract(windowGrid);
      let windowMask = step(0.5, windowUv.x) * step(0.5, windowUv.y);
      let windowColor = mix(
        csThemeTint(vec3<f32>(1.0, 0.8, 0.5), themeColor, 0.35),
        csThemeTint(vec3<f32>(0.7, 0.9, 1.0), g.accent.rgb, 0.35),
        csHash(windowId.y)
      );
      color += windowColor * windowMask * 0.8;
    }
  }

  if (isWater) {
    let darkMask = 1.0 - smoothstep(-1.0, horizon, p.y);
    let waterShade = mix(
      csThemeTint(vec3<f32>(0.5, 0.6, 0.8), themeColor, 0.18),
      mix(g.background.rgb, vec3<f32>(0.05, 0.1, 0.15), 0.5),
      darkMask
    );
    color *= waterShade;
  }

  color *= 1.0 - 0.4 * length(uv - vec2<f32>(0.5));
  color = csThemeGrade(color, themeColor, 0.45);
  return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), opacity);
}
