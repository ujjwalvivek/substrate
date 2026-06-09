/* @substrate
{
  "name": "coastal-landscape",
  "label": "COASTAL LANDSCAPE",
  "order": 490,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "skyRings",   "slot": 0, "default": 60.0, "type": "number" },
    { "key": "grassScale", "slot": 1, "default": 60.0, "type": "number" },
    { "key": "waveDensity", "slot": 2, "default": 1.0, "type": "number" },
    { "key": "treeSway",   "slot": 3, "default": 1.0, "type": "number" },
    { "key": "color",      "slot": 4, "default": "primary", "type": "color" },
    { "key": "themeStrength", "slot": 5, "default": 0.65, "type": "number" }
  ]
}
*/

// Coastal Landscape by bitless.
//
// Ported from the supplied Shadertoy shader. The original sky-ring,
// segmented-water, grass, and tree construction is retained while Shadertoy's
// iTime/iResolution inputs are mapped to Substrate's common ABI.
//
// Credits from the original:
// Patricio Gonzalez Vivo, Jen Lowe, Fabrice Neyret, Inigo Quilez, and the
// Shadertoy community. Hash without Sine by Dave Hoskins.

fn clSkyPalette(t: f32) -> vec3<f32> {
  return vec3<f32>(0.26, 0.76, 0.77) +
    vec3<f32>(1.0, 0.3, 1.0) * cos(
      6.28318 * (vec3<f32>(0.8, 0.4, 0.7) * t + vec3<f32>(0.0, 0.12, 0.54))
    );
}

fn clHue(v: f32) -> vec3<f32> {
  return vec3<f32>(0.6) + 0.76 * cos(
    6.3 * v + vec3<f32>(0.0, 23.0, 21.0)
  );
}

fn clHash12(pIn: vec2<f32>) -> f32 {
  var p3 = fract(vec3<f32>(pIn.x, pIn.y, pIn.x) * 0.1031);
  p3 += vec3<f32>(dot(p3, vec3<f32>(p3.y, p3.z, p3.x) + vec3<f32>(33.33)));
  return fract((p3.x + p3.y) * p3.z);
}

fn clHash22(p: vec2<f32>) -> vec2<f32> {
  var p3 = fract(
    vec3<f32>(p.x, p.y, p.x) * vec3<f32>(0.1031, 0.1030, 0.0973)
  );
  p3 += vec3<f32>(dot(p3, vec3<f32>(p3.y, p3.z, p3.x) + vec3<f32>(33.33)));
  return fract(
    (vec2<f32>(p3.x, p3.x) + vec2<f32>(p3.y, p3.z)) *
    vec2<f32>(p3.z, p3.y)
  );
}

fn clRotate(st: vec2<f32>, angle: f32) -> vec2<f32> {
  let s = sin(angle);
  let c = cos(angle);
  return vec2<f32>(c * st.x - s * st.y, s * st.x + c * st.y);
}

fn clSmoothBar(a: f32, b: f32, width: f32) -> f32 {
  let safeWidth = max(width, 0.000001);
  return smoothstep(a - safeWidth, a + safeWidth, b);
}

fn clNoise(p: vec2<f32>) -> f32 {
  let cell = floor(p);
  let local = fract(p);
  let blend = local * local * (vec2<f32>(3.0) - 2.0 * local);

  let n00 = dot(clHash22(cell), local);
  let n10 = dot(
    clHash22(cell + vec2<f32>(1.0, 0.0)),
    local - vec2<f32>(1.0, 0.0)
  );
  let n01 = dot(
    clHash22(cell + vec2<f32>(0.0, 1.0)),
    local - vec2<f32>(0.0, 1.0)
  );
  let n11 = dot(
    clHash22(cell + vec2<f32>(1.0, 1.0)),
    local - vec2<f32>(1.0, 1.0)
  );

  return mix(mix(n00, n10, blend.x), mix(n01, n11, blend.x), blend.y);
}

fn clThemeTint(base: vec3<f32>, theme: vec3<f32>, amount: f32) -> vec3<f32> {
  return mix(base, mix(base, theme, 0.45), clamp(amount, 0.0, 1.0));
}

fn clThemeGrade(base: vec3<f32>, theme: vec3<f32>, strength: f32) -> vec3<f32> {
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
  let density = max(l.p0.y, 0.9);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  // Density controls the visible band count over a useful range while the
  // noise and tree geometry use a gentler response to avoid block collapse.
  let bandScale = clamp(0.55 + 0.45 * density, 0.55, 1.6);
  let noiseScale = clamp(0.85 + 0.15 * density, 0.85, 1.2);
  let treeDetailScale = clamp(0.85 + 0.15 * density, 0.85, 1.3);
  let skyRings = max(l.p1.x, 1.0) * bandScale;
  let grassScale = max(l.p1.y, 1.0) * bandScale;
  let waveDensity = max(l.p1.z, 0.05) * bandScale;
  let treeSway = max(l.p1.w, 0.0);
  let themeColor = palette(i32(l.p2.x));
  let themeStrength = clamp(l.p2.y, 0.0, 1.0);
  let time = g.viewport.w * speed;

  // Match the original aspect-true coordinate system: x is measured in
  // vertical-resolution units and the visible y range is centered at zero.
  let uv = vec2<f32>(
    (fragCoord.x * 2.0 - resolution.x) / resolution.y,
    (resolution.y - fragCoord.y * 2.0) / resolution.y
  );
  let sunPosition = vec2<f32>(resolution.x / resolution.y * 0.42, -0.53);
  let treePosition = vec2<f32>(-resolution.x / resolution.y * 0.42, -0.2);
  let smoothness = 3.0 / resolution.y;

  var color = vec3<f32>(0.0, 0.1, 0.5);
  var sh = clRotate(
    sunPosition,
    clNoise(uv * noiseScale + vec2<f32>(time * 0.25)) * 0.3
  );
  let skyBack = clThemeTint(
    clSkyPalette(sin(length(uv + sh) - 0.1)) * 0.35,
    themeColor,
    0.10
  );
  let waterBack = clThemeTint(vec3<f32>(0.0, 0.1, 0.5), themeColor, 0.08);
  let horizonBlend = smoothstep(-0.46, -0.34, uv.y);
  // Continuous backplate: waves and displaced strips are always drawn over
  // a complete sky-to-water field, including the bottom of the canvas.
  color = mix(waterBack, skyBack, horizonBlend);
  var u = vec2<f32>(0.0);
  var id = vec2<f32>(0.0);
  var local = vec2<f32>(0.0);
  var t = vec2<f32>(0.0);
  var xCount = 0.0;
  var yCount = 0.0;
  var h = 0.0;
  var foregroundMask = 0.0;
  var segmentDistance = 0.0;
  var cellColor = vec4<f32>(0.0);

  // Sky: concentric, rotated segmented rings with animated cloud patches.
  if (uv.y > -0.4) {
    u = uv + sh;
    yCount = skyRings;
    id = vec2<f32>((length(u) + 0.01) * yCount, 0.0);
    xCount = max(floor(id.x) * 0.09, 1.0);
    h = (clHash12(vec2<f32>(floor(id.x))) * 0.5 + 0.25) * (time + 10.0) * 0.25;
    t = clRotate(u, h);

    id.y = atan2(t.y, t.x) * xCount;
    local = fract(id);
    id -= local;

    t = vec2<f32>(
      cos((id.y + 0.5) / xCount) * (id.x + 0.5) / yCount,
      sin((id.y + 0.5) / xCount) * (id.x + 0.5) / yCount
    );
    t = clRotate(t, -h) - sh;

    h = clNoise(t * vec2<f32>(0.5, 1.0) * noiseScale - vec2<f32>(time * 0.2, 0.0)) *
      step(-0.25, t.y);
    h = smoothstep(0.052, 0.055, h);

    local += clNoise(local * vec2<f32>(1.0, 4.0) * noiseScale + id) * vec2<f32>(0.7, 0.2);

    let skyBase = clSkyPalette(sin(length(u) - 0.1)) * 0.35;
    let skyClouds = mix(
      clSkyPalette(sin(length(u) - 0.1) + (clHash12(id) - 0.5) * 0.15),
      vec3<f32>(1.0),
      h
    );
    let ringCoverage = clSmoothBar(abs(local.x - 0.5), 0.4, smoothness * yCount) *
      clSmoothBar(abs(local.y - 0.5), 0.48, smoothness * xCount);
    let skyLayer = clThemeTint(mix(skyBase, skyClouds, ringCoverage), themeColor, 0.10);
    color = mix(color, skyLayer, horizonBlend);
  }

  // Water: horizontally segmented waves and a shifting sun track.
  if (uv.y < -0.35) {
    var cloudDensity = clNoise(-sh * vec2<f32>(0.5, 1.0) * noiseScale - vec2<f32>(time * 0.2, 0.0));
    cloudDensity = 1.0 - smoothstep(0.0, 0.15, cloudDensity) * 0.5;

    u = uv * vec2<f32>(1.0, 15.0 * waveDensity);
    id = floor(u);

    for (var wave: i32 = 1; wave >= 0; wave = wave - 1) {
      let waveOffset = f32(wave);
      if (id.y + waveOffset < -5.0) {
        local = fract(u) - vec2<f32>(0.5);
        local.y = (local.y + sin(uv.x * 12.0 - time * 3.0 + id.y + waveOffset) * 0.25 - waveOffset) * 4.0;
        h = clHash12(vec2<f32>(id.y + waveOffset, floor(local.y)));

        xCount = 6.0 + h * 4.0;
        yCount = 30.0;
        local.x = uv.x * xCount + sh.x * 9.0;
        local.x += sin(time * (0.5 + h * 2.0)) * 0.5;

        h = 0.8 * (1.0 - smoothstep(0.0, 5.0, abs(floor(local.x)))) * cloudDensity + 0.1;
        let waterBase = mix(
          clThemeTint(vec3<f32>(0.0, 0.1, 0.5), themeColor, 0.08),
          vec3<f32>(0.35, 0.35, 0.0),
          h
        );
        color = mix(color, waterBase, clSmoothBar(local.y, 0.0, smoothness * yCount));

        local += clNoise(local * vec2<f32>(3.0, 0.5)) * vec2<f32>(0.1, 0.6);
        let strokeMask = clSmoothBar(local.y, 0.0, smoothness * xCount) *
          clSmoothBar(abs(fract(local.x) - 0.5), 0.48, smoothness * xCount) *
          clSmoothBar(abs(fract(local.y) - 0.5), 0.3, smoothness * yCount);
        let strokeColor = mix(
          clHue(clHash12(floor(local)) * 0.1 + 0.56) * (1.2 + floor(local.y) * 0.17),
          vec3<f32>(1.0, 1.0, 0.0),
          h
        );
        color = mix(color, clThemeTint(strokeColor, themeColor, 0.08), strokeMask);
      }
    }
  }

  // Grass: a layered field of individually shaded, wind-bent blades.
  u = uv + vec2<f32>(clNoise(uv * 2.0 * noiseScale) * 0.1) +
    vec2<f32>(0.0, sin(uv.x + 3.0) * 0.4 + 0.8);
  let grassPhase = sin(time * 0.2) * 0.5 + 0.5;
  let grassColor = clThemeTint(
    mix(vec3<f32>(0.7, 0.6, 0.2), vec3<f32>(0.0, 1.0, 0.0), grassPhase),
    themeColor,
    0.08
  );
  color = mix(color, grassColor * 0.4, step(u.y, 0.0));

  xCount = grassScale;
  u *= vec2<f32>(xCount, xCount / 3.5);

  if (u.y < 1.2) {
    for (var bladeY: i32 = 0; bladeY > -3; bladeY = bladeY - 1) {
      for (var bladeX: i32 = -2; bladeX < 3; bladeX = bladeX + 1) {
        let bladeOffset = vec2<f32>(f32(bladeX), f32(bladeY));
        id = floor(u) + bladeOffset;
        local = (fract(u) + vec2<f32>(1.0 - f32(bladeX), -f32(bladeY))) / vec2<f32>(5.0, 3.0);
        h = (clHash12(id) - 0.5) * 0.25 + 0.5;

        local -= vec2<f32>(0.3, 0.5 - h * 0.4);
        local.x += sin(
          ((time * 1.7 + h * 2.0 - id.x * 0.05 - id.y * 0.05) * 1.1 + id.y * 0.5) * 2.0
        ) * (local.y + 0.5) * 0.5;

        let bladeShape = abs(local) - vec2<f32>(0.02, 0.5 - h * 0.5);
        segmentDistance = length(max(bladeShape, vec2<f32>(0.0))) +
          min(max(bladeShape.x, bladeShape.y), 0.0);
        segmentDistance -= clNoise(local * 7.0 * noiseScale + id) * 0.1;

        cellColor = vec4<f32>(
          grassColor * 0.25,
          clSmoothBar(segmentDistance, 0.1, smoothness * xCount * 0.09)
        );
        cellColor = mix(
          cellColor,
          vec4<f32>(
            grassColor * (1.2 + local.y * 2.0) * (1.8 - h * 2.5),
            1.0
          ),
          clSmoothBar(segmentDistance, 0.04, smoothness * xCount * 0.09)
        );

        let foreground = cellColor.a * step(id.y, -1.0);
        color = mix(color, cellColor.rgb, foreground);
        foregroundMask = max(foregroundMask, cellColor.a * step(id.y, -5.0));
      }
    }
  }

  // Tree: a bending trunk followed by four noisy foliage layers.
  let treeCycle = sin(time * 0.5) * treeSway;
  if (abs(uv.x + treePosition.x - 0.1 - treeCycle * 0.1) < 0.6) {
    u = uv + treePosition;
    u.x -= sin(u.y + 1.0) * 0.2 * (treeCycle + 0.75);
    u += vec2<f32>(clNoise(u * 4.5 * noiseScale - vec2<f32>(7.0)) * 0.25);

    xCount = max(10.0 * treeDetailScale, 1.0);
    yCount = max(60.0 * treeDetailScale, 1.0);
    t = u * vec2<f32>(1.0, yCount);
    h = clHash12(vec2<f32>(floor(t.y)));
    t.x += h * 0.01;
    t.x *= xCount;
    local = fract(t);

    let trunkMask = clSmoothBar(abs(t.x - 0.5), 0.5, smoothness * xCount) *
      step(abs(t.y + 20.0), 45.0);
    cellColor = mix(
      vec4<f32>(0.07),
      vec4<f32>(vec3<f32>(0.5, 0.3, 0.0) * (0.4 + h * 0.4), 1.0),
      clSmoothBar(abs(local.y - 0.5), 0.4, smoothness * yCount) *
      clSmoothBar(abs(local.x - 0.5), 0.45, smoothness * xCount)
    );
    cellColor.a = trunkMask;

    xCount = max(30.0 * treeDetailScale, 1.0);
    yCount = max(15.0 * treeDetailScale, 1.0);
    for (var foliage: i32 = 0; foliage < 4; foliage = foliage + 1) {
      let foliageLayer = f32(foliage);
      u = uv + treePosition + vec2<f32>(
        foliageLayer / xCount * 0.5 - (treeCycle + 0.75) * 0.15,
        -0.7
      );
      u += vec2<f32>(
        clNoise(u * vec2<f32>(2.0, 1.0) + vec2<f32>(-time + foliageLayer * 0.05))
      ) * vec2<f32>(-0.25, 0.1) *
        (1.0 - smoothstep(-1.0, 0.5, u.y + 0.7)) * 0.75;

      t = u * vec2<f32>(xCount, 1.0);
      h = clHash12(vec2<f32>(floor(t.x) + foliageLayer * 1.4));
      yCount = max((5.0 + h * 7.0) * treeDetailScale, 1.0);
      t.y *= yCount;

      sh = t;
      local = fract(t);
      h = clHash12(t - local);
      t = (t - local) / vec2<f32>(xCount, yCount) + vec2<f32>(0.0, 0.7);

      let crownTop = step(0.0, t.y) * step(length(t), 0.45);
      let crownBottom = step(t.y, 0.0) *
        step(-0.7 + sin((floor(u.x) + foliageLayer * 0.5) * 15.0) * 0.2, t.y);
      let crownMask = (crownTop + crownBottom) * step(abs(t.x), 0.5) *
        clSmoothBar(abs(local.x - 0.5), 0.35, smoothness * xCount * 0.5);

      local += clNoise(sh * vec2<f32>(1.0, 3.0) * noiseScale) * vec2<f32>(0.3);
      let foliageColor = clHue((h + grassPhase) * 0.2) - vec3<f32>(t.x);
      let foliageFill = mix(
        foliageColor * 0.15,
        foliageColor * 0.6 * (0.7 + foliageLayer * 0.2),
        clSmoothBar(abs(local.y - 0.5), 0.47, smoothness * yCount) *
        clSmoothBar(abs(local.x - 0.5), 0.2, smoothness * xCount)
      );
      cellColor = mix(cellColor, vec4<f32>(foliageFill, crownMask), crownMask);
    }

    color = mix(color, cellColor.rgb, cellColor.a * (1.0 - foregroundMask));
  }

  // Grade the completed composition so the sky, water, grass, trunk, and
  // foliage all respond to the active theme rather than only their accents.
  color = clThemeGrade(color, themeColor, themeStrength);

  return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), opacity);
}
