// Shared Substrate WebGPU shader ABI.
// Primitive files under ./isolate are compiled against this source.

const PI: f32 = 3.14159265358979323846;
const TAU: f32 = 6.28318530717958647692;
const VERTEX_STRIDE: u32 = 4194304u;
const NODE_CURVE_STEPS: u32 = 24u;

struct Globals {
  // css width, css height, dpr, time seconds
  viewport: vec4<f32>,
  // fps, frame, layerCount, nodeLayerIndex (-1 if none)
  info: vec4<f32>,
  primary: vec4<f32>,
  secondary: vec4<f32>,
  accent: vec4<f32>,
  background: vec4<f32>,
};

struct Layer {
  // enabled + reserved
  info: vec4<f32>,
  // speed, density, opacity, reserved
  p0: vec4<f32>,
  // primitive-defined parameter slots 0..11
  p1: vec4<f32>,
  p2: vec4<f32>,
  p3: vec4<f32>,
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
@group(0) @binding(1) var<storage, read> layers: Layers;
@group(0) @binding(2) var<storage, read> nodes: Nodes;

fn palette(i: i32) -> vec3<f32> {
  switch i {
    case 0: { return g.primary.rgb; }
    case 1: { return g.secondary.rgb; }
    case 2: { return g.accent.rgb; }
    default: { return g.background.rgb; }
  }
}

fn modp(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }
fn toClip(p: vec2<f32>) -> vec4<f32> { return vec4<f32>(p.x / g.viewport.x * 2.0 - 1.0,1.0 - p.y / g.viewport.y * 2.0,0.0,1.0); }
fn layerIndex(vertexIndex: u32) -> u32 { return vertexIndex / VERTEX_STRIDE; }
fn localVertex(vertexIndex: u32) -> u32 { return vertexIndex % VERTEX_STRIDE; }

struct Segment {
  a: vec2<f32>,
  b: vec2<f32>,
  color: vec3<f32>,
  alpha: f32,
  width: f32,
  glow: f32,
  hiColor: vec3<f32>,
  hiAlpha: f32,
  hiWidth: f32,
};

fn invalidSegment() -> Segment {
  return Segment(vec2<f32>(0),vec2<f32>(0),vec3<f32>(0),0.0,1.0,0.0,vec3<f32>(0),0.0,0.0);
}

fn cubePoint(v0: vec3<f32>, sz: f32, rx: f32, ry: f32, rz: f32, persp: f32, oz: f32, origin: vec2<f32>) -> vec3<f32> {
  var v = v0 * sz;
  let cX = cos(rx);let sX = sin(rx);let cY = cos(ry);let sY = sin(ry);let cZ = cos(rz);let sZ = sin(rz);
  let ny = v.y * cX - v.z * sX;var nz = v.y * sX + v.z * cX;v.y = ny;v.z = nz;
  let nx = v.x * cY + v.z * sY;nz = -v.x * sY + v.z * cY;v.x = nx;v.z = nz;
  let fx = v.x * cZ - v.y * sZ;let fy = v.x * sZ + v.y * cZ;
  let sc = persp / (persp + v.z + oz);
  return vec3<f32>(origin + vec2<f32>(fx,fy) * sc,sc);
}

struct SpriteData {
  center: vec2<f32>,
  extent: f32,
  mode: u32,
  params: vec4<f32>,
  c0: vec4<f32>,
  c1: vec4<f32>,
};

fn invalidSprite() -> SpriteData {
  return SpriteData(vec2<f32>(-10000),1.0,2u,vec4<f32>(0),vec4<f32>(0),vec4<f32>(0));
}
