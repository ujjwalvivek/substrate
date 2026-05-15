struct Globals {
  viewport: vec4<f32>,
  info: vec4<f32>,
  primary: vec4<f32>,
  secondary: vec4<f32>,
  accent: vec4<f32>,
  background: vec4<f32>,
};
struct Layer {
  info: vec4<f32>,
  p0: vec4<f32>,
  p1: vec4<f32>,
  p2: vec4<f32>,
  p3: vec4<f32>
};
struct Layers {
  data: array<Layer>
};
struct Node {
  pos: vec2<f32>,
  vel: vec2<f32>,
  energy: f32,
  phase: f32,
  pad: vec2<f32>
};
struct Nodes {
  data: array<Node>
};

@group(0) @binding(0) var<uniform> g: Globals;
@group(0) @binding(1) var<storage,read> layers: Layers;
@group(0) @binding(2) var<storage,read_write> nodes: Nodes;

@compute @workgroup_size(64)
fn cs_nodes(@builtin(global_invocation_id) id: vec3<u32>) {
  let li = i32(g.info.w);
  if li < 0 {return;}
  let l = layers.data[u32(li)];
  let n = u32(clamp(floor(50.0 + l.p0.y * 30.0),0.0,128.0));
  if id.x >= n {return;}
  var nd = nodes.data[id.x];
  let t = g.viewport.w * l.p0.x;
  nd.vel.x = nd.vel.x + sin(t * 2.0 + nd.phase) * 0.5 * 0.02;
  nd.vel.y = nd.vel.y + cos(t * 1.7 + nd.phase) * 0.5 * 0.02;
  nd.vel = nd.vel * 0.98;
  nd.pos = nd.pos + nd.vel;
  if nd.pos.x < 0.0 {nd.pos.x = g.viewport.x;}
  if nd.pos.x > g.viewport.x {nd.pos.x = 0.0;}
  if nd.pos.y < 0.0 {nd.pos.y = g.viewport.y;}
  if nd.pos.y > g.viewport.y {nd.pos.y = 0.0;}
  nd.energy = (sin(t * 3.0 + nd.pos.x * 0.01) + cos(t * 2.5 + nd.pos.y * 0.01)) * 0.5 + 0.5;
  nodes.data[id.x] = nd;
}
