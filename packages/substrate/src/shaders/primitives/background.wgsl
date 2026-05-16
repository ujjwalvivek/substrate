/* @substrate
{
  "name": "background",
  "label": "BACKGROUND",
  "order": 0,
  "modes": [
    "full"
  ],
  "blend": "source-over",
  "params": [
    {
      "key": "cx",
      "slot": 0,
      "default": -1,
      "type": "number"
    },
    {
      "key": "cy",
      "slot": 1,
      "default": -1,
      "type": "number"
    },
    {
      "key": "radius",
      "slot": 2,
      "default": 1,
      "type": "number"
    }
  ]
}
*/

fn primitiveFull(p: vec2<f32>, l: Layer) -> vec4<f32> {
  let center = vec2<f32>(
    select(l.p1.x,g.viewport.x * 0.5,l.p1.x < 0.0),
    select(l.p1.y,g.viewport.y * 0.5,l.p1.y < 0.0)
  );
  let radius = max(g.viewport.x,g.viewport.y) * max(l.p1.z,0.0001);
  let d = clamp(length(p - center) / radius,0.0,1.0);
  let c0 = vec4<f32>(g.background.rgb,48.0 / 255.0);
  let c1 = vec4<f32>(g.primary.rgb,16.0 / 255.0);
  let c2 = vec4<f32>(g.background.rgb,5.0 / 255.0);
  if d <= 0.5 {return mix(c0,c1,d * 2.0);}
  return mix(c1,c2,(d - 0.5) * 2.0);
}
