# Isolated WGSL primitives

Every `*.wgsl` file in this folder is discovered automatically by Vite through `import.meta.glob()` in `src/gpu/renderer.js`. After adding a file and rebuilding the package, its `label` appears in the playground's **ISOLATE** menu without editing the UI or a registry list.

Each shader starts with a metadata block:

```wgsl
/* @substrate
{
  "name": "example",
  "label": "EXAMPLE",
  "order": 200,
  "modes": ["full"],
  "params": []
}
*/

fn primitiveFull(p: vec2<f32>, l: Layer) -> vec4<f32> {
  return vec4<f32>(g.primary.rgb, l.p0.z);
}
```

Supported modes are `full`, `segment`, `sprite`, and `feedback`. A shader can use more than one mode. The corresponding function names are fixed:

- `full` → `primitiveFull(p, l) -> vec4<f32>`
- `segment` → `primitiveSegment(index, l) -> Segment`
- `sprite` → `primitiveSprite(index, l) -> SpriteData`
- `feedback` → `primitiveFeedback(p, l) -> vec4<f32>` and `primitiveFeedbackPresent(p, l) -> vec4<f32>`

Feedback shaders update a persistent RGBA texture before compositing. The
`primitiveFeedbackPresent` function receives the same texture through the
shared `feedbackSampler` and `feedbackTexture` bindings.

For segment/sprite shaders, add a `draw` expression in metadata. Draw expressions are JSON arrays evaluated by the renderer and can use `width`, `height`, `speed`, `density`, `opacity`, and declared parameter names. Operators currently supported: `+`, `-`, `*`, `/`, `floor`, `ceil`, `min`, `max`, `clamp`, and `pow2`.

Parameter metadata maps public primitive options to the twelve generic GPU parameter slots:

```json
{
    "params": [
        { "key": "spacing", "slot": 0, "default": 100, "type": "number" },
        { "key": "enabled", "slot": 1, "default": 1, "type": "bool" },
        { "key": "color", "slot": 2, "default": "primary", "type": "color" }
    ]
}
```

The shader reads slots 0–3 from `l.p1`, 4–7 from `l.p2`, and 8–11 from `l.p3`.

This is intentionally file-driven so the package build owns shader discovery and the runtime does not depend on a CDN-relative source directory.
