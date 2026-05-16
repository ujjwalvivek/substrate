/* @substrate
{
  "name": "nodes",
  "label": "NODES",
  "order": 40,
  "modes": [
    "segment",
    "sprite"
  ],
  "state": "nodes",
  "params": [
    {
      "key": "maxDist",
      "slot": 0,
      "default": 0.15,
      "type": "number"
    },
    {
      "key": "nodeSize",
      "slot": 1,
      "default": 2,
      "type": "number"
    },
    {
      "key": "curveAmount",
      "slot": 2,
      "default": 30,
      "type": "number"
    }
  ],
  "draw": {
    "segment": [
      "*",
      [
        "*",
        [
          "clamp",
          [
            "floor",
            [
              "+",
              50,
              [
                "*",
                30,
                "density"
              ]
            ]
          ],
          0,
          128
        ],
        [
          "clamp",
          [
            "floor",
            [
              "+",
              50,
              [
                "*",
                30,
                "density"
              ]
            ]
          ],
          0,
          128
        ]
      ],
      24
    ],
    "sprite": [
      "clamp",
      [
        "floor",
        [
          "+",
          50,
          [
            "*",
            30,
            "density"
          ]
        ]
      ],
      0,
      128
    ]
  }
}
*/

fn primitiveSegment(idx: u32, l: Layer) -> Segment {let n = u32(clamp(floor(50.0 + l.p0.y * 30.0),0.0,128.0));if n == 0u {return invalidSegment();}let curve = idx % NODE_CURVE_STEPS;let pair = idx / NODE_CURVE_STEPS;let ai = pair / n;let bi = pair % n;if ai >= n || bi >= n || ai == bi {return invalidSegment();}let a = nodes.data[ai];let b = nodes.data[bi];let d = length(b.pos - a.pos);let maxD = min(g.viewport.x,g.viewport.y) * l.p1.x;if d > maxD {return invalidSegment();}let t = g.viewport.w * l.p0.x;let strength = (1.0 - d / maxD) * (sin(t * 5.0 + d * 0.02) * 0.5 + 0.5);if strength < 0.3 {return invalidSegment();}let energy = (a.energy + b.energy) * 0.5;let col = select(select(g.secondary.rgb,g.primary.rgb,energy > 0.4),g.accent.rgb,energy > 0.7);let m = (a.pos + b.pos) * 0.5 + vec2<f32>(sin(t * 8.0 + d * 0.03),cos(t * 6.0 + d * 0.03)) * l.p1.z;let q0 = f32(curve) / f32(NODE_CURVE_STEPS);let q1 = f32(curve + 1u) / f32(NODE_CURVE_STEPS);let om0 = 1.0 - q0;let om1 = 1.0 - q1;let p0 = om0 * om0 * a.pos + 2.0 * om0 * q0 * m + q0 * q0 * b.pos;let p1 = om1 * om1 * a.pos + 2.0 * om1 * q1 * m + q1 * q1 * b.pos;return Segment(p0,p1,col,strength * 0.6 * energy * l.p0.z,0.5 + strength * 2.0,8.0,vec3<f32>(0),0.0,0.0);}

fn primitiveSprite(idx: u32, l: Layer) -> SpriteData {let n = u32(clamp(floor(50.0 + l.p0.y * 30.0),0.0,128.0));if idx >= n {return invalidSprite();}let nd = nodes.data[idx];let sz = l.p1.y + nd.energy * 4.0;let col = select(g.primary.rgb,g.accent.rgb,nd.energy > 0.6);let alpha = (0.8 + nd.energy * 0.2) * l.p0.z;return SpriteData(nd.pos,sz + 24.0,1u,vec4<f32>(sz,sz * 2.0,12.0,0),vec4<f32>(col,alpha),vec4<f32>(0));}
