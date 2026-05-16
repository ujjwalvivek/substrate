/* @substrate
{
  "name": "vignette",
  "label": "VIGNETTE",
  "order": 100,
  "modes": [
    "full"
  ],
  "params": [
    {
      "key": "innerRadius",
      "slot": 0,
      "default": 0.3,
      "type": "number"
    },
    {
      "key": "outerRadius",
      "slot": 1,
      "default": 0.9,
      "type": "number"
    }
  ]
}
*/

fn primitiveFull(p: vec2<f32>, l: Layer) -> vec4<f32> {
  let r = max(g.viewport.x,g.viewport.y);let d = length(p - g.viewport.xy * 0.5);let q = clamp((d - r * l.p1.x) / max(r * (l.p1.y - l.p1.x),1e-5),0.0,1.0);
  return vec4<f32>(g.background.rgb,q * l.p0.z * 0.7);
}
