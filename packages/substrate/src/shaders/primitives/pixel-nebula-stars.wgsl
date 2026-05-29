/* @substrate
{
  "name": "pixel-nebula-stars",
  "label": "PIXEL NEBULA STARS",
  "order": 330,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "starSize",       "slot": 0, "default": 4.0,  "type": "number" },
    { "key": "starSpeed",      "slot": 1, "default": 50.0, "type": "number" },
    { "key": "nebulaStrength", "slot": 2, "default": 0.20, "type": "number" },
    { "key": "twinkle",        "slot": 3, "default": 1.0,  "type": "number" }
  ]
}
*/

// Pixel star/nebula shader.
//
// Density changes star probability only. It never changes star size or zoom.

fn pnsRand(p: vec2<f32>) -> f32 {
  return fract(sin(dot(p, vec2<f32>(12.9898, 78.233))) * 43758.5453123);
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let resolution = max(g.viewport.xy, vec2<f32>(1.0));

  let globalSpeed = max(l.p0.x, 0.0);
  let density = clamp(l.p0.y, 0.0, 1.0);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let starSize = max(l.p1.x, 1.0);
  let starSpeed = max(l.p1.y, 0.0);
  let nebulaStrength = max(l.p1.z, 0.0);
  let twinkle = max(l.p1.w, 0.0);

  let filteredRes = vec2<f32>(
    fragCoord.x - fract(fragCoord.x / starSize) * starSize,
    fragCoord.y - fract(fragCoord.y / starSize) * starSize
  );

  let st = filteredRes / resolution * 10.0;
  let ipos = floor(st);
  let fpos = fract(st);

  let time = g.viewport.w * globalSpeed * (starSpeed / 100.0);

// Density should affect how rare stars are, not whether whole cells survive.
  let densityExp = mix(180.0, 18.0, density);

// Per-star randomness, not per-cell culling.
  let starBase = pow(
  max(pnsRand(fpos + ipos * 0.137), 0.0),
  densityExp
);

  let sparkleSeed = pnsRand(filteredRes + vec2<f32>(17.0, 3.0));
  let twinkleWave = 0.5 + 0.5 * sin(time * (0.35 + 1.65 * sparkleSeed) * 6.2831853);

  let isStar = starBase * mix(1.0, twinkleWave, twinkle);

// Nebula can stay soft and cell-based.
  let nebulaNoise = pnsRand(ipos * 0.071 + vec2<f32>(5.1, 9.2)) * nebulaStrength;

  let nebulaA = (sin(nebulaNoise) + 1.0) / 8.0;
  let nebulaB = (cos(nebulaNoise) + 1.0) / 8.0;

  let base = g.background.rgb;
  let nebulaColor = g.primary.rgb * nebulaA + g.secondary.rgb * nebulaB;

  let starColor = mix(g.accent.rgb, vec3<f32>(1.0), 0.32);

  let color = base + nebulaColor + starColor * isStar * 1.8;

  return vec4<f32>(
    clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)),
    opacity
  );
}
