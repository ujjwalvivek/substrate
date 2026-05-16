/* @substrate
{
  "name": "particles",
  "label": "PARTICLES",
  "order": 30,
  "modes": [
    "sprite"
  ],
  "params": [
    {
      "key": "minRadius",
      "slot": 0,
      "default": 80,
      "type": "number"
    },
    {
      "key": "maxRadius",
      "slot": 1,
      "default": -1,
      "type": "number"
    }
  ],
  "draw": {
    "sprite": [
      "max",
      0,
      [
        "floor",
        [
          "*",
          80,
          "density"
        ]
      ]
    ]
  }
}
*/

fn primitiveSprite(idx: u32, l: Layer) -> SpriteData {let n = u32(max(floor(80.0 * l.p0.y),0.0));if idx >= n {return invalidSprite();}let fi = f32(idx);let phase = g.viewport.w * l.p0.x * 3.0 + fi * 0.1;let angle = modp(fi * 2.39998,TAU) + phase * 0.05;let maxRadius = select(l.p1.y,min(g.viewport.x,g.viewport.y) * 0.45,l.p1.y < 0.0);let radius = l.p1.x + (fi / f32(max(n,1u))) * (maxRadius - l.p1.x) + sin(phase * 2.0) * 30.0;let c = g.viewport.xy * 0.5 + vec2<f32>(cos(angle),sin(angle)) * radius;let intensity = sin(phase * 7.0) * 0.5 + 0.5;let size = 1.5 + sin(phase * 11.0) * 2.5;let glow = max(size * 3.0,1.0);let col = palette(i32(floor(modp(phase * 3.0,3.0))));return SpriteData(c,glow + 1.0,0u,vec4<f32>(max(size,0.5),glow,0,0),vec4<f32>(col,intensity * l.p0.z * 0.7),vec4<f32>(col,intensity * l.p0.z));}
