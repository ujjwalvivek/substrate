/* @substrate
{
  "name": "branches",
  "label": "BRANCHES",
  "order": 60,
  "modes": [
    "segment",
    "sprite"
  ],
  "params": [
    {
      "key": "maxDepth",
      "slot": 0,
      "default": 9,
      "type": "number"
    },
    {
      "key": "baseLength",
      "slot": 1,
      "default": 70,
      "type": "number"
    }
  ],
  "draw": {
    "segment": [
      "*",
      [
        "max",
        0,
        [
          "floor",
          [
            "*",
            8,
            "density"
          ]
        ]
      ],
      [
        "-",
        [
          "pow2",
          [
            "+",
            [
              "min",
              9,
              [
                "max",
                0,
                [
                  "floor",
                  "maxDepth"
                ]
              ]
            ],
            1
          ]
        ],
        1
      ]
    ],
    "sprite": [
      "*",
      [
        "max",
        0,
        [
          "floor",
          [
            "*",
            8,
            "density"
          ]
        ]
      ],
      [
        "-",
        [
          "pow2",
          [
            "+",
            [
              "min",
              9,
              [
                "max",
                0,
                [
                  "floor",
                  "maxDepth"
                ]
              ]
            ],
            1
          ]
        ],
        1
      ]
    ]
  }
}
*/


struct BranchInfo {
  a: vec2<f32>,
  b: vec2<f32>,
  depth: u32,
  energy: f32,
  len: f32,
  tp: f32,
  root: u32,
  valid: u32,
};

fn branchInfo(idx: u32, l: Layer) -> BranchInfo {
  let roots = u32(max(floor(8.0 * l.p0.y),0.0));
  let maxDepth = min(u32(max(l.p1.x,0.0)),9u);
  let perRoot = (1u << (maxDepth + 1u)) - 1u;
  if roots == 0u || perRoot == 0u {return BranchInfo(vec2<f32>(0),vec2<f32>(0),0u,0.0,0.0,0.0,0u,0u);}
  let root = idx / perRoot;
  if root >= roots {return BranchInfo(vec2<f32>(0),vec2<f32>(0),0u,0.0,0.0,0.0,root,0u);}
  let local = idx % perRoot;
  var depth = 0u;
  for (var d = 0u; d <= 9u; d = d + 1u) {
    if local >= ((1u << d) - 1u) {depth = d;}
    if d >= maxDepth {break;}
  }
  let base = (1u << depth) - 1u;
  let path = local - base;
  let t = g.viewport.w * l.p0.x;
  let fr = f32(root);
  let rootX = fr * g.viewport.x / f32(roots + 1u) + g.viewport.x / f32(roots + 1u);
  let rootY = g.viewport.y + sin(t * l.p0.x + fr) * 30.0;
  let tp = t + fr * 2.3;
  var x = rootX;
  var y = rootY;
  var paramAngle = PI / 2.0 + sin(tp) * 0.2;
  var paramLength = l.p1.y + sin(tp * 0.8) * 25.0;
  var energy = 1.0;
  var a = vec2<f32>(x,y);
  var b = a;
  var finalLen = 0.0;
  var valid = 1u;

  for (var d = 0u; d <= 9u; d = d + 1u) {
    if d > depth {break;}
    if paramLength < 8.0 {valid = 0u;break;}
    let gp = sin(tp + f32(d) * 0.3) * 0.2 + 1.0;
    let len = paramLength * gp;
    let ang = paramAngle + sin(tp + f32(d) + x * 0.01) * 0.1;
    a = vec2<f32>(x,y);
    b = a + vec2<f32>(cos(ang),-sin(ang)) * len;
    finalLen = len;
    if d == depth {break;}
    if len <= 15.0 {valid = 0u;break;}
    let shift = depth - 1u - d;
    let bit = (path >> shift) & 1u;
    paramAngle = paramAngle + (f32(bit) - 0.5) * 0.7 + sin(tp + f32(d)) * 0.2;
    x = b.x;
    y = b.y;
    paramLength = paramLength * 0.75;
    energy = energy * 0.85;
  }
  return BranchInfo(a,b,depth,energy,finalLen,tp,root,valid);
}

fn primitiveSegment(idx: u32, l: Layer) -> Segment {
  let q = branchInfo(idx,l);
  if q.valid == 0u {return invalidSegment();}
  let col = select(select(g.accent.rgb,g.secondary.rgb,q.depth < 5u),g.primary.rgb,q.depth < 2u);
  let width = max(1.0,6.0 - f32(q.depth));
  return Segment(q.a,q.b,col,l.p0.z * q.energy * 0.8,width,0.0,vec3<f32>(0),0.0,0.0);
}

fn primitiveSprite(idx: u32, l: Layer) -> SpriteData {
  let q = branchInfo(idx,l);
  if q.valid == 0u || (q.depth % 2u) != 0u || q.len <= 12.0 {return invalidSprite();}
  let na = sin(q.tp * 2.0 + f32(q.depth) + f32(q.root)) * 0.5 + 0.5;
  let radius = max(3.0 + na * 2.0,0.0);
  let center = mix(q.a,q.b,0.7);
  return SpriteData(center,radius + 1.0,2u,vec4<f32>(radius,0,0,0),vec4<f32>(g.accent.rgb,l.p0.z * q.energy * na),vec4<f32>(0));
}
