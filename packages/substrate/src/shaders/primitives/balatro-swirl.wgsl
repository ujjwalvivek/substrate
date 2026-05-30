/* @substrate
{
  "name": "balatro-swirl",
  "label": "BALATRO SWIRL",
  "order": 260,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "vortexSpeed", "slot": 0, "default": 0.8,   "type": "number" },
    { "key": "swirlScale",  "slot": 1, "default": 30.0,  "type": "number" },
    { "key": "pixelFilter", "slot": 2, "default": 700.0, "type": "number" },
    { "key": "flash",       "slot": 3, "default": 0.0,   "type": "number" }
  ]
}
*/

// -----------------------------------------------------------------------------
// BALATRO SWIRL
//
// Updated Substrate port based on the more faithful LocalThunk / wgrav / xandr
// version supplied by the user.
//
// Preserves:
// - the ~3 second vortex reveal
// - the original vortex-angle evolution
// - five-iteration smoke field
// - simplified smoke classification
// - mid-flash behavior
// - source gamma workflow
//
// Theme mapping:
// - RED   role -> g.primary
// - BLUE  role -> g.secondary
// - BLACK role -> g.background with a slight accent contribution
//
// Global controls:
//   l.p0.x = SPEED
//   l.p0.y = DENSITY
//   l.p0.z = OPACITY
//
// Shader params:
//   l.p1.x = vortexSpeed
//   l.p1.y = swirlScale
//   l.p1.z = pixelFilter
//   l.p1.w = flash
//
// DENSITY affects effective pixel/detail resolution only. It does not zoom the
// vortex or change its physical scale.
// -----------------------------------------------------------------------------

fn bswLinearize(c: vec3<f32>) -> vec3<f32> {
  return pow(
    clamp(c, vec3<f32>(0.0), vec3<f32>(1.0)),
    vec3<f32>(2.2)
  );
}

fn bswGammaEncode(c: vec3<f32>) -> vec3<f32> {
  return pow(
    max(c, vec3<f32>(0.0)),
    vec3<f32>(1.0 / 2.2)
  );
}

fn bswEffect(
  screenSize: vec2<f32>,
  screenCoords: vec2<f32>,
  l: Layer
) -> vec3<f32> {
  let resLen = max(length(screenSize), 1.0);

  let globalSpeed = max(l.p0.x, 0.0);
  let density = max(l.p0.y, 0.05);

  let vortexSpeed = max(l.p1.x, 0.0);
  let swirlScale = max(l.p1.y, 0.01);
  let basePixelFilter = max(l.p1.z, 32.0);
  let flash = max(l.p1.w, 0.0);

  // Higher density means finer effective resolution, not a larger image.
  let pixelFilter = basePixelFilter * sqrt(density);

  let pixelSize = resLen / max(pixelFilter, 1.0);

  // Source:
  // (floor(fragCord / pixel_size) * pixel_size - .5*iResolution.xy)
  // / length(iResolution.xy)
  var uv = (floor(screenCoords / pixelSize) * pixelSize - 0.5 * screenSize) / resLen;

  let uvLen = length(uv);

  // Keep the reveal timing separate from VORT_SPEED exactly like the source:
  // VORT_SPEED affects vortex motion, while the smoke introduction is based on
  // elapsed shader time.
  let elapsedTime = g.viewport.w * globalSpeed;

  let vortexTime = elapsedTime * vortexSpeed;

  let clampedSpeed = min(6.0, vortexTime);

  // Faithful LocalThunk vortex-angle evolution.
  let newPixelAngle = atan2(uv.y, uv.x) + (2.2 + 0.4 * clampedSpeed) * uvLen - 1.0 - vortexTime * 0.05 - clampedSpeed * vortexTime * 0.02;

  let mid = normalize(screenSize) * 0.5;

  var sv = vec2<f32>(
      uvLen * cos(newPixelAngle) + mid.x,
      uvLen * sin(newPixelAngle) + mid.y
    ) - mid;

  // Original default: 30.
  sv     *= swirlScale;

  let smokeTime = elapsedTime * 6.0 * vortexSpeed + 1033.0;

  var uv2 = vec2<f32>(sv.x + sv.y);

  // This remains the dominant cost, and matches the optimized source.
  for (var i: i32 = 0; i < 5; i = i + 1) {
    uv2     +=
      vec2<f32>(
        sin(max(sv.x, sv.y))
      ) + sv;

    sv     +=
      0.5 * vec2<f32>(
        cos(
          5.1123314 + 0.353 * uv2.y + smokeTime * 0.131121
        ),
        sin(
          uv2.x - 0.113 * smokeTime
        )
      );

    let fold = cos(sv.x + sv.y) - sin(sv.x * 0.711 - sv.y);

    sv     -= vec2<f32>(fold);
  }

  // Faithful simplified smoke result from the supplied optimized version.
  var smokeRes = min(
      2.0,
      max(
        -2.0,
        1.5 + length(sv) * 0.12 - 0.17 * min(
            10.0,
            elapsedTime * 1.2 - 4.0
          )
      )
    );

  let smokeAdj = (smokeRes - 0.2) * 0.6 + 0.2;

  smokeRes = mix(
      smokeAdj,
      smokeRes,
      step(0.2, smokeRes)
    );

  let c1p = max(
      0.0,
      1.0 - 2.0 * abs(1.0 - smokeRes)
    );

  let c2p = max(
      0.0,
      1.0 - 2.0 * smokeRes
    );

  let cb = 1.0 - min(
      1.0,
      c1p + c2p
    );

  // The game shader works in linear space and gamma-encodes at the end.
  let primaryLinear = bswLinearize(g.primary.rgb);

  let secondaryLinear = bswLinearize(g.secondary.rgb);

  let darkSrgb = clamp(
      0.60 * mix(
        g.background.rgb,
        g.accent.rgb,
        0.08
      ),
      vec3<f32>(0.0),
      vec3<f32>(1.0)
    );

  let darkLinear = bswLinearize(darkSrgb);

  var resultLinear = primaryLinear * c1p + secondaryLinear * c2p + darkLinear * cb;

  let maxCp = max(c1p, c2p);

  let modFlash = max(
      flash * 0.8,
      maxCp * 5.0 - 4.4
    ) + flash * maxCp;

  // Source: ret_col*(1.-mod_flash) + mod_flash;
  resultLinear = resultLinear * (1.0 - modFlash) + vec3<f32>(modFlash);

  return
    clamp(
      bswGammaEncode(resultLinear),
      vec3<f32>(0.0),
      vec3<f32>(1.0)
    );
}

fn primitiveFull(
  p: vec2<f32>,
  l: Layer
) -> vec4<f32> {
  let viewport = max(
      g.viewport.xy,
      vec2<f32>(1.0)
    );

  let color = bswEffect(
      viewport,
      p,
      l
    );

  return vec4<f32>(
    color,
    clamp(l.p0.z, 0.0, 1.0)
  );
}
