/* @substrate
{
  "name": "digital-rain",
  "label": "DIGITAL RAIN",
  "order": 290,
  "modes": ["full"],
  "blend": "source-over",
  "params": [
    { "key": "cellSize",     "slot": 0, "default": 16.0, "type": "number" },
    { "key": "trailLength",  "slot": 1, "default": 12.0, "type": "number" },
    { "key": "glyphDensity", "slot": 2, "default": 0.58, "type": "number" },
    { "key": "flicker",      "slot": 3, "default": 1.0,  "type": "number" }
  ]
}
*/

// Procedural textureless adaptation of the supplied matrix-rain shader.
//
// The source relies on:
//   iChannel0 = glyph/font atlas
//   iChannel1 = random character texture
//
// Substrate's isolate ABI does not provide those textures, so this version
// creates deterministic pseudo-glyphs procedurally. It preserves the important
// visual behavior: fixed columns, independent falling speeds, changing symbols,
// bright heads and fading trails.
//
// Theme-reactive:
//   background -> g.background
//   trails     -> g.primary / g.secondary
//   heads      -> g.accent
//
// DENSITY changes how many columns participate, without changing glyph scale.

fn drHash12(p: vec2<f32>) -> f32 {
  return fract(
    sin(
      dot(
        p,
        vec2<f32>(12.9898, 78.233)
      )
    ) * 43758.5453123
  );
}

fn drHash11(x: f32) -> f32 {
  return fract(sin(x * 127.1 + 311.7) * 43758.5453123);
}

fn drGlyph(localIn: vec2<f32>, glyphId: f32, density: f32) -> f32 {
  // Small inset like the source's font-atlas sampling.
  let local = localIn * 0.82 + vec2<f32>(0.09);

  if local.x <= 0.0 || local.x >= 1.0 || local.y <= 0.0 || local.y >= 1.0 {
    return 0.0;
  }

  let grid = vec2<f32>(5.0, 7.0);
  let gp = floor(local * grid);
  let cellUv = fract(local * grid);

  let bit = drHash12(
      gp + vec2<f32>(
          glyphId * 13.17,
          glyphId * 7.91
        )
    );

  // Randomized 5x7 pixels form the base glyph.
  var on = select(
      0.0,
      1.0,
      bit > (1.0 - density)
    );

  // Add a few coherent strokes so symbols read as glyphs rather than TV noise.
  let centerStroke = select(
      0.0,
      1.0,
      abs(gp.x - 2.0) < 0.5 && drHash11(glyphId + 1.0) > 0.55
    );

  let topStroke = select(
      0.0,
      1.0,
      gp.y < 0.5 && drHash11(glyphId + 2.0) > 0.58
    );

  let midStroke = select(
      0.0,
      1.0,
      abs(gp.y - 3.0) < 0.5 && drHash11(glyphId + 3.0) > 0.58
    );

  let bottomStroke = select(
      0.0,
      1.0,
      gp.y > 5.5 && drHash11(glyphId + 4.0) > 0.58
    );

  on = max(on, max(centerStroke, max(topStroke, max(midStroke, bottomStroke))));

  // Keep pixels compact and crisp.
  let px = 1.0 - smoothstep(
        0.34,
        0.48,
        max(
          abs(cellUv.x - 0.5),
          abs(cellUv.y - 0.5)
        )
      );

  return on * px;
}

fn primitiveFull(fragCoord: vec2<f32>, l: Layer) -> vec4<f32> {
  let viewport = max(g.viewport.xy, vec2<f32>(1.0));

  let speedGlobal = max(l.p0.x, 0.0);
  let densityGlobal = max(l.p0.y, 0.0);
  let opacity = clamp(l.p0.z, 0.0, 1.0);

  let cellSize = max(l.p1.x, 6.0);
  let trailLength = max(l.p1.y, 1.0);
  let glyphDensity = clamp(l.p1.z, 0.15, 0.92);
  let flicker = max(l.p1.w, 0.0);

  let time = g.viewport.w * speedGlobal;

  let cellCoord = fragCoord / cellSize;
  let cell = floor(cellCoord);
  let local = fract(cellCoord);

  let rows = max(ceil(viewport.y / cellSize), 1.0);

  let column = cell.x;
  let columnSeed = drHash11(column * 17.13 + 4.7);

  // Organic column population. Density never changes cell size.
  let densityVis = clamp(
      1.0 - exp(-densityGlobal * 0.95),
      0.0,
      1.0
    );

  let columnPresence = 1.0 - smoothstep(
        densityVis - 0.08,
        densityVis + 0.08,
        drHash11(column * 9.17 + 33.0)
      );

  let columnSpeed = mix(
      0.55,
      1.65,
      drHash11(column * 5.37 + 17.0)
    );

  // Head moves downward because WebGPU fragment y increases downward.
  let head = fract(
      columnSeed + time * columnSpeed * 0.20
    ) * rows;

  var behind = head - cell.y;
  if behind < 0.0 {
    behind   += rows;
  }

  let trailMask = 1.0 - smoothstep(
        trailLength,
        trailLength + 1.0,
        behind
      );

  let trail = exp(
      -behind / max(trailLength * 0.34, 0.25)
    ) * trailMask;

  let charTick = floor(
      time * (2.0 + flicker * 5.0) + cell.y * 0.37 + columnSeed * 23.0
    );

  let glyphId = floor(
      drHash12(
        vec2<f32>(
          column + charTick,
          cell.y + charTick * 0.17
        )
      ) * 96.0
    );

  let glyph = drGlyph(
      local,
      glyphId,
      glyphDensity
    );

  let shimmer = mix(
      0.72,
      1.15,
      drHash12(
        vec2<f32>(
          column,
          cell.y + floor(time * max(flicker, 0.1) * 4.0)
        )
      )
    );

  let headGlow = exp(-behind * 1.8);

  let trailColor = mix(
      g.primary.rgb,
      g.secondary.rgb,
      drHash11(column * 3.17 + 5.0) * 0.42
    );

  let glyphColor = mix(
      trailColor,
      g.accent.rgb,
      clamp(headGlow * 1.35, 0.0, 1.0)
    );

  let intensity = glyph * trail * shimmer * columnPresence;

  let color = mix(
      g.background.rgb,
      glyphColor,
      clamp(intensity, 0.0, 1.0)
    );

  return vec4<f32>(
    clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)),
    opacity
  );
}
