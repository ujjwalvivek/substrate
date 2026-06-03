/* @substrate
{
  "name": "laser-grid",
  "label": "LASER GRID",
  "order": 10,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "spacing",   "slot": 0, "default": 100,  "type": "number" },
    { "key": "lineWidth", "slot": 1, "default": 0.02, "type": "number" },
    { "key": "warpAmount", "slot": 2, "default": 5, "type": "number" },
    { "key": "color",     "slot": 4, "default": "secondary", "type": "color" }
  ]
}
*/

// Animated laser grid adapted from a Shadertoy-style full-screen fragment.
// The old segment grid was replaced so the grid can retain its glow and
// intersection treatment at any canvas size.

fn gridThemeColor(l: Layer) -> vec3<f32> {
  return palette(i32(l.p2.x));
}

fn gridCycleColor(base: vec3<f32>, phase: f32, offset: f32, strength: f32) -> vec3<f32> {
  let wave = 0.5 + 0.5 * cos(phase + offset + vec3<f32>(0.0, 2.0, 4.0));
  return clamp(base * (0.72 + wave * strength) + vec3<f32>(0.10) * wave, vec3<f32>(0.0), vec3<f32>(1.0));
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));
  let time = g.viewport.w * max(l.p0.x, 0.0);
  let density = sqrt(clamp(l.p0.y, 0.1, 4.0));

  var uv = fragCoord / resolution;
  uv.x *= resolution.x / resolution.y;

  // Keep the legacy spacing option meaningful: 100 maps to the source's
  // 0.04 normalized cell size, while larger values make a coarser grid.
  let gridSize = clamp(max(l.p1.x, 1.0) / (2500.0 * density), 0.006, 0.16);
  let movement = 0.02 * clamp(max(l.p1.z, 0.0) / 5.0, 0.0, 4.0);
  let offset = vec2<f32>(
    sin(time * 0.30) * movement,
    cos(time * 0.25) * movement
  );

  let gridPos = (uv + offset) / gridSize;
  let cell = fract(gridPos);
  let edgeDistance = min(cell, vec2<f32>(1.0) - cell);
  let lineDistance = min(edgeDistance.x, edgeDistance.y);
  let lineWidth = clamp(l.p1.y, 0.002, 0.08);

  let gridCore = 1.0 - smoothstep(0.0, lineWidth * 0.32, lineDistance);
  let gridInner = 1.0 - smoothstep(lineWidth * 0.32, lineWidth * 0.9, lineDistance);
  let gridOuter = 1.0 - smoothstep(lineWidth * 0.9, lineWidth * 2.2, lineDistance);
  let intersectionDistance = max(edgeDistance.x, edgeDistance.y);
  let intersectionCore = 1.0 - smoothstep(0.0, lineWidth * 0.55, intersectionDistance);
  let intersectionGlow = 1.0 - smoothstep(lineWidth * 0.55, lineWidth * 2.0, intersectionDistance);

  let phase = time * 0.15;
  let themeColor = gridThemeColor(l);
  let coreColor = gridCycleColor(themeColor, phase, 0.0, 0.28);
  let innerColor = gridCycleColor(themeColor, phase + 0.5, 1.0, 0.38);
  let outerColor = gridCycleColor(themeColor, phase + 1.0, 2.0, 0.22);
  let bgColor = mix(g.background.rgb, mix(g.primary.rgb, g.secondary.rgb, 0.5), 0.08);

  var finalColor = bgColor;
  finalColor = mix(finalColor, outerColor, gridOuter * 0.3);
  finalColor = mix(finalColor, innerColor, gridInner * 0.6);
  finalColor = mix(finalColor, coreColor, gridCore * 0.9);
  finalColor = mix(finalColor, outerColor, intersectionGlow * 0.4);
  finalColor = mix(finalColor, coreColor, intersectionCore);

  let linePulse = 0.5 + 0.5 * sin(time * 2.0);
  finalColor *= 0.9 + 0.1 * linePulse;

  return vec4<f32>(clamp(finalColor, vec3<f32>(0.0), vec3<f32>(1.0)), clamp(l.p0.z, 0.0, 1.0));
}
