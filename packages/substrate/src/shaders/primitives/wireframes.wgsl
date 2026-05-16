/* @substrate
{
  "name": "wireframes",
  "label": "WIREFRAMES",
  "order": 50,
  "modes": [
    "segment",
    "sprite"
  ],
  "params": [
    {
      "key": "cubeSize",
      "slot": 0,
      "default": 40,
      "type": "number"
    },
    {
      "key": "perspectiveDist",
      "slot": 1,
      "default": 500,
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
      12
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
      8
    ]
  }
}
*/

fn primitiveSegment(idx: u32, l: Layer) -> Segment {
  let n = u32(max(floor(8.0 * l.p0.y),0.0));let cube = idx / 12u;if cube >= n {return invalidSegment();}let e = idx % 12u;let verts = array<vec3<f32>,8>(vec3<f32>(-1,-1,-1),vec3<f32>(1,-1,-1),vec3<f32>(1,1,-1),vec3<f32>(-1,1,-1),vec3<f32>(-1,-1,1),vec3<f32>(1,-1,1),vec3<f32>(1,1,1),vec3<f32>(-1,1,1));let ea = array<u32,12>(0u,1u,2u,3u,4u,5u,6u,7u,0u,1u,2u,3u);let eb = array<u32,12>(1u,2u,3u,0u,5u,6u,7u,4u,4u,5u,6u,7u);
  let t = g.viewport.w * l.p0.x;let fi = f32(cube);let it = t + fi * 2.5;let origin = vec2<f32>(g.viewport.x * 0.2 + f32(cube % 3u) * g.viewport.x * 0.3 + sin(it * 0.7) * 80.0,g.viewport.y * 0.2 + floor(fi / 3.0) * g.viewport.y * 0.25 + cos(it * 0.9) * 60.0);let oz = sin(it) * 100.0 + 200.0;let sz = l.p1.x + sin(it * 1.5) * 15.0;let a = cubePoint(verts[ea[e]],sz,it * 0.8,it * 1.2,it * 0.5,l.p1.y,oz,origin);let b = cubePoint(verts[eb[e]],sz,it * 0.8,it * 1.2,it * 0.5,l.p1.y,oz,origin);let avg = (a.z + b.z) * 0.5;let base = select(g.accent.rgb,g.primary.rgb,(cube % 2u) == 0u);let hi = sin(t * 0.005 + fi + f32(ea[e] + eb[e])) * 0.5 + 0.5 > 0.8;return Segment(a.xy,b.xy,base,l.p0.z * avg * 0.6,1.5,0.0,g.secondary.rgb,select(0.0,l.p0.z * 0.4,hi),3.0);
}

fn primitiveSprite(idx: u32, l: Layer) -> SpriteData {let n = u32(max(floor(8.0 * l.p0.y),0.0));let cube = idx / 8u;let j = idx % 8u;if cube >= n {return invalidSprite();}let verts = array<vec3<f32>,8>(vec3<f32>(-1,-1,-1),vec3<f32>(1,-1,-1),vec3<f32>(1,1,-1),vec3<f32>(-1,1,-1),vec3<f32>(-1,-1,1),vec3<f32>(1,-1,1),vec3<f32>(1,1,1),vec3<f32>(-1,1,1));let t = g.viewport.w * l.p0.x;let fi = f32(cube);let it = t + fi * 2.5;let origin = vec2<f32>(g.viewport.x * 0.2 + f32(cube % 3u) * g.viewport.x * 0.3 + sin(it * 0.7) * 80.0,g.viewport.y * 0.2 + floor(fi / 3.0) * g.viewport.y * 0.25 + cos(it * 0.9) * 60.0);let oz = sin(it) * 100.0 + 200.0;let sz = l.p1.x + sin(it * 1.5) * 15.0;let v = cubePoint(verts[j],sz,it * 0.8,it * 1.2,it * 0.5,l.p1.y,oz,origin);let pulse = sin(t * 0.008 + fi + f32(j)) * 0.5 + 0.5;return SpriteData(v.xy,max(3.0 * v.z,0.5) + 1.0,2u,vec4<f32>(max(3.0 * v.z,0.5),0,0,0),vec4<f32>(g.accent.rgb,l.p0.z * v.z * pulse * 0.8),vec4<f32>(0));}
