/* @substrate
{
  "name": "grid",
  "label": "GRID",
  "order": 10,
  "modes": [
    "segment"
  ],
  "params": [
    {
      "key": "spacing",
      "slot": 0,
      "default": 100,
      "type": "number"
    },
    {
      "key": "warpAmount",
      "slot": 1,
      "default": 5,
      "type": "number"
    },
    {
      "key": "horizontal",
      "slot": 2,
      "default": 1,
      "type": "bool"
    },
    {
      "key": "vertical",
      "slot": 3,
      "default": 1,
      "type": "bool"
    },
    {
      "key": "color",
      "slot": 4,
      "default": "secondary",
      "type": "color"
    }
  ],
  "draw": {
    "segment": [
      "+",
      [
        "*",
        "horizontal",
        [
          "*",
          [
            "max",
            0,
            [
              "-",
              [
                "ceil",
                [
                  "/",
                  "height",
                  [
                    "max",
                    1,
                    "spacing"
                  ]
                ]
              ],
              1
            ]
          ],
          [
            "floor",
            [
              "/",
              "width",
              20
            ]
          ]
        ]
      ],
      [
        "*",
        "vertical",
        [
          "*",
          [
            "max",
            0,
            [
              "-",
              [
                "ceil",
                [
                  "/",
                  "width",
                  [
                    "max",
                    1,
                    "spacing"
                  ]
                ]
              ],
              1
            ]
          ],
          [
            "floor",
            [
              "/",
              "height",
              20
            ]
          ]
        ]
      ]
    ]
  }
}
*/

fn primitiveSegment(idx: u32, l: Layer) -> Segment {
  let sp = max(l.p1.x,1.0);let wa = l.p1.y;let t = g.viewport.w * l.p0.x;let xSeg = u32(floor(g.viewport.x / 20.0));let ySeg = u32(floor(g.viewport.y / 20.0));let hRows = u32(max(ceil(g.viewport.y / sp) - 1.0,0.0));let vCols = u32(max(ceil(g.viewport.x / sp) - 1.0,0.0));let hCount = select(0u,hRows * xSeg,l.p1.z > 0.5);let vCount = select(0u,vCols * ySeg,l.p1.w > 0.5);
  if idx < hCount && xSeg > 0u {let row = idx / xSeg;let s = idx % xSeg;let by = f32(row + 1u) * sp;let oy = by + sin(t + by * 0.01) * wa;let x0 = f32(s) * 20.0;let x1 = f32(s + 1u) * 20.0;let y0 = oy + sin(t * 1.1 + x0 * 0.02) * wa * 0.5;let y1 = oy + sin(t * 1.1 + x1 * 0.02) * wa * 0.5;return Segment(vec2<f32>(x0,y0),vec2<f32>(x1,y1),palette(i32(l.p2.x)),l.p0.z * 0.12,0.5,0.0,vec3<f32>(0),0.0,0.0);}
  let j = idx - hCount;if j < vCount && ySeg > 0u {let col = j / ySeg;let s = j % ySeg;let bx = f32(col + 1u) * sp;let ox = bx + cos(t + bx * 0.01) * wa;let y0 = f32(s) * 20.0;let y1 = f32(s + 1u) * 20.0;let x0 = ox + cos(t * 1.1 + y0 * 0.02) * wa * 0.5;let x1 = ox + cos(t * 1.1 + y1 * 0.02) * wa * 0.5;return Segment(vec2<f32>(x0,y0),vec2<f32>(x1,y1),palette(i32(l.p2.x)),l.p0.z * 0.12,0.5,0.0,vec3<f32>(0),0.0,0.0);}return invalidSegment();
}
