/* @substrate
{
  "name": "scanlines",
  "label": "SCANLINES",
  "order": 20,
  "modes": [
    "segment"
  ],
  "params": [
    {
      "key": "spacing",
      "slot": 0,
      "default": 4,
      "type": "number"
    },
    {
      "key": "maxAlpha",
      "slot": 1,
      "default": 0.08,
      "type": "number"
    },
    {
      "key": "color",
      "slot": 2,
      "default": "primary",
      "type": "color"
    }
  ],
  "draw": {
    "segment": [
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
    ]
  }
}
*/

fn primitiveSegment(idx: u32, l: Layer) -> Segment {
  let y = f32(idx) * max(l.p1.x,1.0);if y >= g.viewport.y {return invalidSegment();}let t = g.viewport.w * l.p0.x;let intensity = sin(t * 2.0 + y * 0.01) * 0.5 + 0.5;if intensity <= 0.3 {return invalidSegment();}let yy = y + sin(t + y * 0.02) * 2.0;return Segment(vec2<f32>(0.0,yy),vec2<f32>(g.viewport.x,yy),palette(i32(l.p1.z)),l.p1.y * intensity * l.p0.z,1.0,0.0,vec3<f32>(0),0.0,0.0);
}
