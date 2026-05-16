/* @substrate
{
  "name": "mandala",
  "label": "MANDALA",
  "order": 70,
  "modes": [
    "segment",
    "sprite"
  ],
  "params": [
    {
      "key": "layers",
      "slot": 0,
      "default": 6,
      "type": "number"
    },
    {
      "key": "basePetals",
      "slot": 1,
      "default": 5,
      "type": "number"
    },
    {
      "key": "baseRadius",
      "slot": 2,
      "default": 50,
      "type": "number"
    },
    {
      "key": "cx",
      "slot": 4,
      "default": -1,
      "type": "number"
    },
    {
      "key": "cy",
      "slot": 5,
      "default": -1,
      "type": "number"
    }
  ],
  "draw": {
    "segment": [
      "*",
      21,
      [
        "+",
        [
          "*",
          [
            "clamp",
            [
              "floor",
              [
                "*",
                "layers",
                "density"
              ]
            ],
            0,
            16
          ],
          "basePetals"
        ],
        [
          "*",
          [
            "clamp",
            [
              "floor",
              [
                "*",
                "layers",
                "density"
              ]
            ],
            0,
            16
          ],
          [
            "-",
            [
              "clamp",
              [
                "floor",
                [
                  "*",
                  "layers",
                  "density"
                ]
              ],
              0,
              16
            ],
            1
          ]
        ]
      ]
    ],
    "sprite": [
      "*",
      3,
      [
        "+",
        [
          "*",
          [
            "min",
            4,
            [
              "clamp",
              [
                "floor",
                [
                  "*",
                  "layers",
                  "density"
                ]
              ],
              0,
              16
            ]
          ],
          "basePetals"
        ],
        [
          "*",
          [
            "min",
            4,
            [
              "clamp",
              [
                "floor",
                [
                  "*",
                  "layers",
                  "density"
                ]
              ],
              0,
              16
            ]
          ],
          [
            "-",
            [
              "min",
              4,
              [
                "clamp",
                [
                  "floor",
                  [
                    "*",
                    "layers",
                    "density"
                  ]
                ],
                0,
                16
              ]
            ],
            1
          ]
        ]
      ]
    ]
  }
}
*/

fn mandalaCenter(l: Layer) -> vec2<f32> {return vec2<f32>(select(l.p2.x,g.viewport.x * 0.5,l.p2.x < 0.0),select(l.p2.y,g.viewport.y * 0.5,l.p2.y < 0.0));}
fn mandalaPoint(center: vec2<f32>, pa: f32, pp: f32, petals: u32, inner: f32, outer: f32, pt: u32) -> vec2<f32> {let fpt = f32(pt);let pta = pa + (fpt / 20.0) * (PI / f32(petals)) - PI / (f32(petals) * 2.0);let pointRadius = inner + (outer - inner) * (0.5 + 0.5 * sin(fpt * PI / 10.0));let wr = pointRadius * (1.0 + sin(pp * 3.0 + fpt * 0.3) * 0.2);return center + vec2<f32>(cos(pta),sin(pta)) * wr;}

fn primitiveSegment(idx0: u32, l: Layer) -> Segment {
  let n = min(u32(max(floor(l.p1.x * l.p0.y),0.0)),16u);var idx = idx0;var layer = 0u;var petal = 0u;var pt = 0u;var found = false;for (var ly = 0u; ly < 16u; ly = ly + 1u) {if ly >= n {break;}let petals = u32(max(l.p1.y + f32(ly) * 2.0,1.0));let count = petals * 21u;if idx < count {layer = ly;petal = idx / 21u;pt = idx % 21u;found = true;break;}idx = idx - count;}if !found {return invalidSegment();}
  let t = g.viewport.w * l.p0.x;let fl = f32(layer);let lp = t + fl * 0.8;let lr = l.p1.z + fl * 30.0 + sin(lp * 0.7) * 20.0;let lrot = lp * select(-1.0,1.0,(layer % 2u) == 0u) * 0.3;let petals = u32(max(l.p1.y + fl * 2.0,1.0));let pa = (f32(petal) / f32(petals)) * TAU + lrot;let pp = lp + f32(petal) * 0.2;let ps = 0.7 + sin(pp * 1.5) * 0.5;let pr = lr * ps;let inner = pr * 0.3;let outer = pr * 0.8;let aPt = select(pt,20u,pt == 20u);let bPt = select(pt + 1u,0u,pt == 20u);let a = mandalaPoint(mandalaCenter(l),pa,pp,petals,inner,outer,aPt);let b = mandalaPoint(mandalaCenter(l),pa,pp,petals,inner,outer,bPt);let col = palette(i32(floor(modp(pp + fl,3.0))));let alpha = l.p0.z * (0.6 + sin(pp * 2.0) * 0.4);let width = max(0.05,1.0 + sin(pp * 4.0));return Segment(a,b,col,alpha,width,0.0,vec3<f32>(0),0.0,0.0);
}

fn primitiveSprite(idx0: u32, l: Layer) -> SpriteData {let n = min(u32(max(floor(l.p1.x * l.p0.y),0.0)),4u);var idx = idx0;var layer = 0u;var petal = 0u;var sat = 0u;var found = false;for (var ly = 0u; ly < 4u; ly = ly + 1u) {if ly >= n {break;}let petals = u32(max(l.p1.y + f32(ly) * 2.0,1.0));let count = petals * 3u;if idx < count {layer = ly;petal = idx / 3u;sat = idx % 3u;found = true;break;}idx = idx - count;}if !found {return invalidSprite();}let t = g.viewport.w * l.p0.x;let fl = f32(layer);let lp = t + fl * 0.8;let lr = l.p1.z + fl * 30.0 + sin(lp * 0.7) * 20.0;let lrot = lp * select(-1.0,1.0,(layer % 2u) == 0u) * 0.3;let petals = u32(max(l.p1.y + fl * 2.0,1.0));let pa = (f32(petal) / f32(petals)) * TAU + lrot;let pp = lp + f32(petal) * 0.2;let ps = 0.7 + sin(pp * 1.5) * 0.5;let pr = lr * ps;let sa = pa + (f32(sat) - 1.0) * 0.2;let sr = pr * (0.4 + f32(sat) * 0.1);let rad = max(2.0 + sin(pp * 5.0 + f32(sat)) * 2.0,0.0);let col = select(g.secondary.rgb,g.accent.rgb,(sat % 2u) == 0u);return SpriteData(mandalaCenter(l) + vec2<f32>(cos(sa),sin(sa)) * sr,rad + 1.0,2u,vec4<f32>(rad,0,0,0),vec4<f32>(col,l.p0.z * 0.6),vec4<f32>(0));}
