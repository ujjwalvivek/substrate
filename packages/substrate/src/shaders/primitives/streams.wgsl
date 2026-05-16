/* @substrate
{
  "name": "streams",
  "label": "STREAMS",
  "order": 80,
  "modes": [
    "sprite"
  ],
  "params": [
    {
      "key": "trailLength",
      "slot": 0,
      "default": 6,
      "type": "number"
    }
  ],
  "draw": {
    "sprite": [
      "*",
      [
        "max",
        0,
        [
          "floor",
          [
            "*",
            25,
            "density"
          ]
        ]
      ],
      [
        "+",
        1,
        [
          "max",
          1,
          [
            "floor",
            "trailLength"
          ]
        ]
      ]
    ]
  }
}
*/

fn primitiveSprite(idx: u32, l: Layer) -> SpriteData {let n = u32(max(floor(25.0 * l.p0.y),0.0));let trail = u32(max(l.p1.x,1.0));let per = 1u + trail;let i = idx / per;let tr = idx % per;if i >= n {return invalidSprite();}let fi = f32(i);let t = g.viewport.w * l.p0.x;let phase = modp(t * 0.04 + fi * 0.3,1.0);let pt = i % 4u;var s = vec2<f32>(0);var prev = vec2<f32>(0);if pt == 0u {s = vec2<f32>(phase * g.viewport.x,g.viewport.y * 0.4 + sin(phase * PI * 3.0 + fi) * 80.0);prev = vec2<f32>(s.x - 12.0,g.viewport.y * 0.4 + sin((phase - 0.02) * PI * 3.0 + fi) * 80.0);} else if pt == 1u {s = vec2<f32>(g.viewport.x * 0.3 + cos(phase * TAU + fi) * 60.0,phase * g.viewport.y);prev = s - vec2<f32>(12.0);} else if pt == 2u {let a = phase * PI * 6.0 + fi;let r = 100.0 + phase * 150.0;let pa = (phase - 0.02) * PI * 6.0 + fi;let pr = 100.0 + (phase - 0.02) * 150.0;s = g.viewport.xy * 0.5 + vec2<f32>(cos(a),sin(a)) * r;prev = g.viewport.xy * 0.5 + vec2<f32>(cos(pa),sin(pa)) * pr;} else {s = vec2<f32>(phase * g.viewport.x,g.viewport.y * 0.6 + sin(phase * PI * 4.0) * 100.0);prev = vec2<f32>(s.x - 15.0,s.y);}let energy = sin(t * 0.012 + fi * 0.7) * 0.5 + 0.5;let size = 2.0 + sin(t * 0.008 + fi) * 2.0;if tr == 0u {let col = select(g.accent.rgb,g.primary.rgb,(i % 2u) == 0u);return SpriteData(s,max(size,0.5) + 1.0,2u,vec4<f32>(max(size,0.5),0,0,0),vec4<f32>(col,l.p0.z * energy * 0.9),vec4<f32>(0));}let q = f32(tr) / f32(trail);let c = mix(s,prev,q);let rad = max(size * (1.0 - q * 0.5),0.5);return SpriteData(c,rad + 1.0,2u,vec4<f32>(rad,0,0,0),vec4<f32>(g.secondary.rgb,l.p0.z * (1.0 - q) * energy * 0.6),vec4<f32>(0));}
