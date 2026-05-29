/* @substrate
{
  "name": "foam",
  "label": "FOAM",
  "order": 110,
  "modes": [
    "sprite"
  ],
  "params": [
    {
      "key": "spacing",
      "slot": 0,
      "default": 25,
      "type": "number"
    }
  ],
  "draw": {
    "sprite": [
      "*",
      [
        "+",
        [
          "floor",
          [
            "/",
            [
              "+",
              "width",
              "spacing"
            ],
            [
              "max",
              1,
              "spacing"
            ]
          ]
        ],
        1
      ],
      [
        "+",
        [
          "floor",
          [
            "/",
            [
              "+",
              "height",
              "spacing"
            ],
            [
              "max",
              1,
              "spacing"
            ]
          ]
        ],
        1
      ]
    ]
  }
}
*/

fn primitiveSprite(idx: u32, l: Layer) -> SpriteData {let sp = max(l.p1.x,1.0);let cols = u32(floor((g.viewport.x + sp) / sp)) + 1u;let rows = u32(floor((g.viewport.y + sp) / sp)) + 1u;let x = idx / rows;let y = idx % rows;if x >= cols {return invalidSprite();}let c = vec2<f32>(f32(x) * sp,f32(y) * sp);let v = c - g.viewport.xy * 0.5;let dist = length(v);let angle = atan2(v.y,v.x);let t = g.viewport.w * l.p0.x;let inter = (sin(dist * 0.02 - t * 3.0 + angle * 2.0) + cos(dist * 0.01 + t * 1.5 - angle)) * 0.5;if inter > 0.4 {let rad = (inter - 0.4) * 6.0;let col = select(g.secondary.rgb,g.accent.rgb,inter > 0.8);return SpriteData(c,rad + 1.0,2u,vec4<f32>(rad,0,0,0),vec4<f32>(col,l.p0.z),vec4<f32>(0));}return SpriteData(c,1.0,3u,vec4<f32>(0.5,0.5,0,0),vec4<f32>(g.primary.rgb,l.p0.z * 0.2),vec4<f32>(0));}
