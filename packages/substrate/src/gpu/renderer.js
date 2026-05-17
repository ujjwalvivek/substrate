import commonWGSL from "../shaders/common.wgsl?raw";
import nodesWGSL from "../shaders/nodes.compute.wgsl?raw";

const rawShaderModules = import.meta.glob(
    "../shaders/primitives/*.wgsl",
    {
        eager: true,
        query: "?raw",
        import: "default",
    },
);

const DEFAULTS = { speed: 1, density: 1, opacity: 0.8 };
const DEFAULT_PALETTE = {
    primary: "#00ffff",
    secondary: "#ff00ff",
    accent: "#ffff00",
    background: "#0a0a0f",
};
const VERTEX_STRIDE = 4194304;
const MAX_LAYERS = 16;
const MAX_NODES = 128;
const MAX_DRAW_ITEMS = Math.floor((VERTEX_STRIDE - 1) / 6);

const FULL_ENTRY = `
struct FullOut {
  @builtin(position) position: vec4<f32>,
  @interpolate(flat) @location(0) li: u32,
};

@vertex fn vs_full(@builtin(vertex_index) vi:u32)->FullOut {
  let li=layerIndex(vi);
  let lv=localVertex(vi);
  let p=array<vec2<f32>,3>(vec2<f32>(-1.0,-1.0),vec2<f32>(3.0,-1.0),vec2<f32>(-1.0,3.0));
  var o:FullOut;
  o.position=vec4<f32>(p[lv],0.0,1.0);
  o.li=li;
  return o;
}

@fragment fn fs_full(in:FullOut)->@location(0) vec4<f32> {
  let p=in.position.xy/g.viewport.z;
  return primitiveFull(p,layers.data[in.li]);
}
`;

const SEGMENT_ENTRY = `
struct SegOut {
  @builtin(position) position:vec4<f32>,
  @location(0) color:vec4<f32>,
  @location(1) @interpolate(linear) signedDist:f32,
  @location(2) params:vec4<f32>,
  @location(3) hiColor:vec3<f32>,
};

@vertex fn vs_segment(@builtin(vertex_index) vi:u32)->SegOut {
  let li=layerIndex(vi);
  let lv=localVertex(vi);
  let segIdx=lv/6u;
  let corner=lv%6u;
  let s=primitiveSegment(segIdx,layers.data[li]);
  var a=s.a;
  var b=s.b;
  var dir=b-a;
  let len=length(dir);
  if(len<1e-5||s.alpha<=0.0){
    a=vec2<f32>(-10000.0);
    b=a;
    dir=vec2<f32>(1,0);
  }else{
    dir=dir/len;
  }
  let n=vec2<f32>(-dir.y,dir.x);
  let extent=max(max(s.width,s.hiWidth)*0.5+s.glow,0.75);
  let side=array<f32,6>(-1.0,-1.0,1.0,-1.0,1.0,1.0);
  let end=array<f32,6>(0.0,1.0,1.0,0.0,1.0,0.0);
  let pos=mix(a,b,end[corner])+n*side[corner]*extent;
  var o:SegOut;
  o.position=toClip(pos);
  o.color=vec4<f32>(s.color,s.alpha);
  o.signedDist=side[corner]*extent;
  o.params=vec4<f32>(s.width,s.glow,s.hiWidth,s.hiAlpha);
  o.hiColor=s.hiColor;
  return o;
}

@fragment fn fs_segment(in:SegOut)->@location(0) vec4<f32> {
  let d=abs(in.signedDist);
  let half=max(in.params.x*0.5,0.01);
  let core=1.0-smoothstep(max(0.0,half-0.75),half+0.75,d);
  let glow=select(0.0,(1.0-smoothstep(half,half+in.params.y,d))*0.28,in.params.y>0.0);
  let a0=clamp((core+glow)*in.color.a,0.0,1.0);
  let hiHalf=max(in.params.z*0.5,0.0);
  let hiCov=select(0.0,1.0-smoothstep(max(0.0,hiHalf-0.75),hiHalf+0.75,d),in.params.w>0.0);
  let a1=hiCov*in.params.w;
  let a=a1+a0*(1.0-a1);
  let premul=in.hiColor*a1+in.color.rgb*a0*(1.0-a1);
  let rgb=select(vec3<f32>(0),premul/max(a,1e-6),a>0.0);
  return vec4<f32>(rgb,a);
}
`;

const SPRITE_ENTRY = `
struct SpriteOut {
  @builtin(position) position:vec4<f32>,
  @location(0) local:vec2<f32>,
  @location(1) params:vec4<f32>,
  @location(2) c0:vec4<f32>,
  @location(3) c1:vec4<f32>,
  @interpolate(flat) @location(4) mode:u32,
};

@vertex fn vs_sprite(@builtin(vertex_index) vi:u32)->SpriteOut {
  let li=layerIndex(vi);
  let lv=localVertex(vi);
  let sprite=lv/6u;
  let corner=lv%6u;
  let s=primitiveSprite(sprite,layers.data[li]);
  let xy=array<vec2<f32>,6>(vec2<f32>(-1,-1),vec2<f32>(1,-1),vec2<f32>(1,1),vec2<f32>(-1,-1),vec2<f32>(1,1),vec2<f32>(-1,1));
  let q=xy[corner];
  var o:SpriteOut;
  o.position=toClip(s.center+q*s.extent);
  o.local=q*s.extent;
  o.params=s.params;
  o.c0=s.c0;
  o.c1=s.c1;
  o.mode=s.mode;
  return o;
}

@fragment fn fs_sprite(in:SpriteOut)->@location(0) vec4<f32> {
  let d=length(in.local);
  if(in.mode==0u){
    let core=1.0-smoothstep(max(in.params.x-0.75,0.0),in.params.x+0.75,d);
    let grad=clamp(1.0-d/max(in.params.y,1e-5),0.0,1.0);
    let a0=grad*in.c0.a;
    let a1=core*in.c1.a;
    let a=a1+a0*(1.0-a1);
    return vec4<f32>(in.c0.rgb,a);
  }
  if(in.mode==1u){
    let r=in.params.x;
    let inside=1.0-smoothstep(max(r-0.75,0.0),r+0.75,d);
    let tint=clamp(d/max(r,1e-5),0.0,1.0);
    let fillColor=mix(vec3<f32>(1.0),in.c0.rgb,tint);
    let shadow=(1.0-smoothstep(r,r+in.params.z*2.0,d))*in.c0.a*0.32;
    let fillA=inside*in.c0.a;
    let a=fillA+shadow*(1.0-fillA);
    let premul=fillColor*fillA+in.c0.rgb*shadow*(1.0-fillA);
    return vec4<f32>(select(vec3<f32>(0),premul/max(a,1e-6),a>0.0),a);
  }
  if(in.mode==3u){
    let inside=select(0.0,1.0,abs(in.local.x)<=in.params.x&&abs(in.local.y)<=in.params.y);
    return vec4<f32>(in.c0.rgb,inside*in.c0.a);
  }
  let a=(1.0-smoothstep(max(in.params.x-0.75,0.0),in.params.x+0.75,d))*in.c0.a;
  return vec4<f32>(in.c0.rgb,a);
}
`;

const FEEDBACK_ENTRY = `
@group(1) @binding(0) var feedbackSampler: sampler;
@group(1) @binding(1) var feedbackTexture: texture_2d<f32>;

struct FeedbackOut {
  @builtin(position) position: vec4<f32>,
  @interpolate(flat) @location(0) li: u32,
};

@vertex fn vs_feedback(@builtin(vertex_index) vi:u32)->FeedbackOut {
  let li=layerIndex(vi);
  let lv=localVertex(vi);
  let p=array<vec2<f32>,3>(
    vec2<f32>(-1.0,-1.0),
    vec2<f32>(3.0,-1.0),
    vec2<f32>(-1.0,3.0)
  );
  var o:FeedbackOut;
  o.position=vec4<f32>(p[lv],0.0,1.0);
  o.li=li;
  return o;
}

@fragment fn fs_feedback(in:FeedbackOut)->@location(0) vec4<f32> {
  let p=in.position.xy/g.viewport.z;
  return primitiveFeedback(p,layers.data[in.li]);
}

@fragment fn fs_feedback_present(in:FeedbackOut)->@location(0) vec4<f32> {
  let dims=vec2<f32>(textureDimensions(feedbackTexture));
  let uv=in.position.xy/max(dims,vec2<f32>(1.0));
  let c=textureSample(feedbackTexture,feedbackSampler,uv);
  return vec4<f32>(c.rgb,clamp(layers.data[in.li].p0.z,0.0,1.0));
}
`;

function parseShader(path, source) {
    const match = source.match(/\/\*\s*@substrate\s*([\s\S]*?)\*\//);
    if (!match)
        throw new Error(
            `Shader ${path} is missing a /* @substrate { ... } */ metadata block.`,
        );
    const meta = JSON.parse(match[1]);
    if (!meta.name || !Array.isArray(meta.modes) || !meta.modes.length)
        throw new Error(`Shader ${path} has invalid Substrate metadata.`);
    return {
        ...meta,
        label: meta.label || meta.name.toUpperCase(),
        order: Number(meta.order ?? 999),
        params: Array.isArray(meta.params) ? meta.params : [],
        draw: meta.draw || {},
        feedback: meta.feedback || {},
        blend: meta.blend || "source-over",
        source,
        path,
    };
}

const shaderList = Object.entries(rawShaderModules)
    .map(([path, source]) => parseShader(path, source))
    .sort((a, b) => a.order - b.order || a.name.localeCompare(b.name));

const shaderMap = new Map(shaderList.map((shader) => [shader.name, shader]));

function makePrimitive(name) {
    const shader = shaderMap.get(name);
    const fn = (options = {}) => ({ fn, options });
    Object.defineProperties(fn, {
        primitiveName: { value: name },
        shader: { value: shader },
    });
    return fn;
}

export const primitives = Object.fromEntries(
    shaderList.map((shader) => [shader.name, makePrimitive(shader.name)]),
);
export const shaderDescriptors = shaderList.map(({ source, ...meta }) => ({
    ...meta,
}));
export const shaderNames = shaderList.map((shader) => shader.name);

function normalizeLayer(layer) {
    if (layer?.fn?.primitiveName && shaderMap.has(layer.fn.primitiveName)) {
        return {
            name: layer.fn.primitiveName,
            options: { ...(layer.options || {}) },
        };
    }
    if (layer?.name && shaderMap.has(layer.name)) {
        return { name: layer.name, options: { ...(layer.options || {}) } };
    }
    throw new Error(
        "Invalid Substrate layer. Expected a discovered primitive.",
    );
}

export function compose(layers) {
    return { __substrateGpuScene: true, layers: layers.map(normalizeLayer) };
}

export function sceneFromConfig(config) {
    return compose(
        config.map(({ name, options = {} }) => ({
            fn: primitives[name],
            options,
        })),
    );
}

function hex4(hex) {
    const s = String(hex || "#000000")
        .replace("#", "")
        .slice(0, 6)
        .padEnd(6, "0");
    return [
        parseInt(s.slice(0, 2), 16) / 255,
        parseInt(s.slice(2, 4), 16) / 255,
        parseInt(s.slice(4, 6), 16) / 255,
        1,
    ];
}

function colorIndex(value, fallback = 0) {
    if (typeof value === "number") return value;
    return (
        { primary: 0, secondary: 1, accent: 2, background: 3 }[value] ??
        fallback
    );
}

function descriptorDefaults(descriptor) {
    const result = {};
    for (const spec of descriptor.params) result[spec.key] = spec.default;
    return result;
}

export function effectiveLayerOptions(
    name,
    localOptions = {},
    globalOptions = {},
) {
    const descriptor = shaderMap.get(name);
    if (!descriptor) throw new Error(`Unknown shader primitive: ${name}`);
    const local = { ...descriptorDefaults(descriptor), ...localOptions };
    const globalSpeed = Number(globalOptions.speed ?? DEFAULTS.speed);
    const globalDensity = Number(globalOptions.density ?? DEFAULTS.density);
    const globalOpacity = Number(globalOptions.opacity ?? DEFAULTS.opacity);
    const localSpeed = Number(localOptions.speed ?? DEFAULTS.speed);
    const localDensity = Number(localOptions.density ?? DEFAULTS.density);
    const localOpacity = Number(localOptions.opacity ?? DEFAULTS.opacity);
    return {
        ...local,
        speed: localSpeed * globalSpeed,
        density: localDensity * globalDensity,
        opacity: Math.max(
            0,
            Math.min(1, localOpacity * (globalOpacity / DEFAULTS.opacity)),
        ),
    };
}

function paramNumber(spec, value) {
    if (spec.type === "bool") return value === false || value === 0 ? 0 : 1;
    if (spec.type === "color")
        return colorIndex(value, colorIndex(spec.default, 0));
    const n = Number(value);
    return Number.isFinite(n) ? n : Number(spec.default ?? 0);
}

function encodeLayer(layer, globalOptions) {
    const descriptor = shaderMap.get(layer.name);
    const options = effectiveLayerOptions(
        layer.name,
        layer.options,
        globalOptions,
    );
    const f = new Float32Array(20);
    f.set([1, 0, 0, 0], 0);
    f.set([options.speed, options.density, options.opacity, 0], 4);
    for (const spec of descriptor.params) {
        const slot = Number(spec.slot);
        if (slot < 0 || slot > 11) continue;
        f[8 + slot] = paramNumber(spec, options[spec.key]);
    }
    return f;
}

function evalExpr(expr, ctx) {
    if (typeof expr === "number") return expr;
    if (typeof expr === "string") return Number(ctx[expr] ?? 0);
    if (!Array.isArray(expr) || !expr.length) return 0;
    const [op, ...raw] = expr;
    const a = () => raw.map((value) => evalExpr(value, ctx));
    switch (op) {
        case "+":
            return a().reduce((sum, n) => sum + n, 0);
        case "-": {
            const v = a();
            return v.length === 1
                ? -v[0]
                : v.slice(1).reduce((n, x) => n - x, v[0] ?? 0);
        }
        case "*":
            return a().reduce((product, n) => product * n, 1);
        case "/": {
            const v = a();
            return v
                .slice(1)
                .reduce(
                    (n, x) =>
                        (n / Math.max(Math.abs(x), 1e-9)) * Math.sign(x || 1),
                    v[0] ?? 0,
                );
        }
        case "floor":
            return Math.floor(evalExpr(raw[0], ctx));
        case "ceil":
            return Math.ceil(evalExpr(raw[0], ctx));
        case "min":
            return Math.min(...a());
        case "max":
            return Math.max(...a());
        case "clamp":
            return Math.max(
                evalExpr(raw[1], ctx),
                Math.min(evalExpr(raw[2], ctx), evalExpr(raw[0], ctx)),
            );
        case "pow2":
            return 2 ** evalExpr(raw[0], ctx);
        default:
            throw new Error(`Unknown shader draw expression operator: ${op}`);
    }
}

function drawCount(layer, mode, globalOptions, width, height) {
    const descriptor = shaderMap.get(layer.name);
    const expr = descriptor.draw?.[mode];
    if (expr == null) return 0;
    const options = effectiveLayerOptions(
        layer.name,
        layer.options,
        globalOptions,
    );
    const ctx = { width, height, ...options };
    const count = Math.max(0, Math.floor(evalExpr(expr, ctx)));
    return Math.min(count, MAX_DRAW_ITEMS);
}

function nodeInfo(scene, globalOptions) {
    const index = scene.layers.findIndex(
        (layer) => shaderMap.get(layer.name)?.state === "nodes",
    );
    if (index < 0) return { index: -1, count: 0 };
    const options = effectiveLayerOptions(
        scene.layers[index].name,
        scene.layers[index].options,
        globalOptions,
    );
    return {
        index,
        count: Math.min(
            MAX_NODES,
            Math.max(0, Math.floor(50 + options.density * 30)),
        ),
    };
}

async function checkedModule(device, code, label) {
    const module = device.createShaderModule({ code, label });
    if (module.getCompilationInfo) {
        const info = await module.getCompilationInfo();
        const errors = info.messages.filter(
            (message) => message.type === "error",
        );
        if (errors.length)
            throw new Error(
                errors
                    .map(
                        (error) =>
                            `${label} ${error.lineNum}:${error.linePos}\n${error.message}`,
                    )
                    .join("\n\n"),
            );
    }
    return module;
}

const sourceOver = {
    color: {
        srcFactor: "src-alpha",
        dstFactor: "one-minus-src-alpha",
        operation: "add",
    },
    alpha: {
        srcFactor: "one",
        dstFactor: "one-minus-src-alpha",
        operation: "add",
    },
};
const screenBlend = {
    color: { srcFactor: "one", dstFactor: "one-minus-src", operation: "add" },
    alpha: {
        srcFactor: "one",
        dstFactor: "one-minus-src-alpha",
        operation: "add",
    },
};

function entrySource(descriptor) {
    let source = `${commonWGSL}\n${descriptor.source}\n`;
    if (descriptor.modes.includes("full")) source += FULL_ENTRY;
    if (descriptor.modes.includes("segment")) source += SEGMENT_ENTRY;
    if (descriptor.modes.includes("sprite")) source += SPRITE_ENTRY;
    if (descriptor.modes.includes("feedback")) source += FEEDBACK_ENTRY;
    return source;
}

export class SubstrateGPU {
    constructor(canvas) {
        this.canvas = canvas;
        this.device = null;
        this.context = null;
        this.scene = compose([{ fn: primitives.background }]);
        this.palette = { ...DEFAULT_PALETTE };
        this.options = {};
        this.frame = 0;
        this.raf = 0;
        this.last = 0;
        this.stopped = true;
        this.nodeCount = -1;
        this.nodeLayer = -1;
        this.resizeObserver = null;
        this.pipelines = new Map();
        this.feedbackResources = new Map();
    }

    async init() {
        if (!navigator.gpu)
            throw new Error("WebGPU is not available in this browser.");
        const adapter = await navigator.gpu.requestAdapter();
        if (!adapter) throw new Error("No WebGPU adapter is available.");
        this.device = await adapter.requestDevice();
        this.context = this.canvas.getContext("webgpu");
        this.format = navigator.gpu.getPreferredCanvasFormat();
        this.context.configure({
            device: this.device,
            format: this.format,
            alphaMode: "premultiplied",
        });

        this.uniformBuffer = this.device.createBuffer({
            size: 96,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        });
        this.layerBuffer = this.device.createBuffer({
            size: MAX_LAYERS * 80,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });
        this.nodeBuffer = this.device.createBuffer({
            size: MAX_NODES * 32,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });

        this.renderBGL = this.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" },
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" },
                },
            ],
        });
        this.renderPL = this.device.createPipelineLayout({
            bindGroupLayouts: [this.renderBGL],
        });
        this.renderBG = this.device.createBindGroup({
            layout: this.renderBGL,
            entries: [
                { binding: 0, resource: { buffer: this.uniformBuffer } },
                { binding: 1, resource: { buffer: this.layerBuffer } },
                { binding: 2, resource: { buffer: this.nodeBuffer } },
            ],
        });

        this.feedbackBGL = this.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: { type: "filtering" },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float" },
                },
            ],
        });
        this.feedbackPL = this.device.createPipelineLayout({
            bindGroupLayouts: [this.renderBGL, this.feedbackBGL],
        });
        this.feedbackSampler = this.device.createSampler({
            addressModeU: "repeat",
            addressModeV: "repeat",
            magFilter: "linear",
            minFilter: "linear",
        });

        const target = (blend) => [
            { format: this.format, blend, writeMask: GPUColorWrite.ALL },
        ];
        for (const descriptor of shaderList) {
            const module = await checkedModule(
                this.device,
                entrySource(descriptor),
                `Substrate / ${descriptor.name}.wgsl`,
            );
            const pipelines = {};
            if (descriptor.modes.includes("full")) {
                pipelines.full = this.device.createRenderPipeline({
                    layout: this.renderPL,
                    vertex: { module, entryPoint: "vs_full" },
                    fragment: {
                        module,
                        entryPoint: "fs_full",
                        targets: target(
                            descriptor.blend === "screen"
                                ? screenBlend
                                : sourceOver,
                        ),
                    },
                    primitive: { topology: "triangle-list" },
                });
            }
            if (descriptor.modes.includes("segment")) {
                pipelines.segment = this.device.createRenderPipeline({
                    layout: this.renderPL,
                    vertex: { module, entryPoint: "vs_segment" },
                    fragment: {
                        module,
                        entryPoint: "fs_segment",
                        targets: target(sourceOver),
                    },
                    primitive: { topology: "triangle-list" },
                });
            }
            if (descriptor.modes.includes("sprite")) {
                pipelines.sprite = this.device.createRenderPipeline({
                    layout: this.renderPL,
                    vertex: { module, entryPoint: "vs_sprite" },
                    fragment: {
                        module,
                        entryPoint: "fs_sprite",
                        targets: target(sourceOver),
                    },
                    primitive: { topology: "triangle-list" },
                });
            }
            if (descriptor.modes.includes("feedback")) {
                const feedbackFormat =
                    descriptor.feedback?.format || "rgba16float";
                pipelines.feedback = this.device.createRenderPipeline({
                    layout: this.feedbackPL,
                    vertex: { module, entryPoint: "vs_feedback" },
                    fragment: {
                        module,
                        entryPoint: "fs_feedback",
                        targets: [{ format: feedbackFormat }],
                    },
                    primitive: { topology: "triangle-list" },
                });
                pipelines.feedbackPresent = this.device.createRenderPipeline({
                    layout: this.feedbackPL,
                    vertex: { module, entryPoint: "vs_feedback" },
                    fragment: {
                        module,
                        entryPoint: "fs_feedback_present",
                        targets: target(
                            descriptor.blend === "screen"
                                ? screenBlend
                                : sourceOver,
                        ),
                    },
                    primitive: { topology: "triangle-list" },
                });
            }
            this.pipelines.set(descriptor.name, pipelines);
        }

        const computeModule = await checkedModule(
            this.device,
            nodesWGSL,
            "Substrate / nodes.compute.wgsl",
        );
        this.computeBGL = this.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" },
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" },
                },
            ],
        });
        this.computePipeline = this.device.createComputePipeline({
            layout: this.device.createPipelineLayout({
                bindGroupLayouts: [this.computeBGL],
            }),
            compute: { module: computeModule, entryPoint: "cs_nodes" },
        });
        this.computeBG = this.device.createBindGroup({
            layout: this.computeBGL,
            entries: [
                { binding: 0, resource: { buffer: this.uniformBuffer } },
                { binding: 1, resource: { buffer: this.layerBuffer } },
                { binding: 2, resource: { buffer: this.nodeBuffer } },
            ],
        });

        this.#setupResize();
        return this;
    }

    setScene(scene) {
        this.#destroyFeedbackResources();
        this.scene = scene?.__substrateGpuScene ? scene : compose(scene);
        this.#syncNodes(true);
        if ((this.options.fps ?? 30) === 0 && this.device && this.cssWidth)
            this.render(0);
    }

    setPalette(palette) {
        this.palette = { ...DEFAULT_PALETTE, ...palette };
        if ((this.options.fps ?? 30) === 0 && this.device && this.cssWidth)
            this.render(0);
    }

    setOptions(options) {
        this.options = options || {};
        this.#syncNodes(false);
        if ((this.options.fps ?? 30) === 0 && this.device && this.cssWidth)
            this.render(0);
    }

    #setupResize() {
        const resize = () => {
            const parent = this.canvas.parentElement || document.body;
            const width =
                parent === document.body ? innerWidth : parent.clientWidth;
            const height =
                parent === document.body ? innerHeight : parent.clientHeight;
            const dpr = devicePixelRatio || 1;
            const pixelWidth = Math.max(1, Math.round(width * dpr));
            const pixelHeight = Math.max(1, Math.round(height * dpr));
            const resized =
                this.canvas.width !== pixelWidth ||
                this.canvas.height !== pixelHeight;
            this.canvas.style.width = width + "px";
            this.canvas.style.height = height + "px";
            this.canvas.width = pixelWidth;
            this.canvas.height = pixelHeight;
            this.cssWidth = width;
            this.cssHeight = height;
            this.dpr = dpr;
            if (resized) this.#destroyFeedbackResources();
            if ((this.options.fps ?? 30) === 0 && this.device) this.render(0);
        };
        resize();
        this.resizeObserver = new ResizeObserver(resize);
        this.resizeObserver.observe(this.canvas.parentElement || document.body);
    }

    #destroyFeedbackResources() {
        for (const resource of this.feedbackResources.values()) {
            resource.textures[0]?.destroy();
            resource.textures[1]?.destroy();
        }
        this.feedbackResources.clear();
    }

    #feedbackResource(index, descriptor) {
        const key = `${index}:${descriptor.name}`;
        const width = Math.max(1, this.canvas.width);
        const height = Math.max(1, this.canvas.height);
        const format = descriptor.feedback?.format || "rgba16float";

        let resource = this.feedbackResources.get(key);
        if (
            resource &&
            resource.width === width &&
            resource.height === height &&
            resource.format === format
        ) {
            return resource;
        }

        if (resource) {
            resource.textures[0]?.destroy();
            resource.textures[1]?.destroy();
        }

        const createTexture = () =>
            this.device.createTexture({
                size: { width, height, depthOrArrayLayers: 1 },
                format,
                usage:
                    GPUTextureUsage.RENDER_ATTACHMENT |
                    GPUTextureUsage.TEXTURE_BINDING,
            });

        const textures = [createTexture(), createTexture()];
        const views = [textures[0].createView(), textures[1].createView()];
        const bindGroups = views.map((view) =>
            this.device.createBindGroup({
                layout: this.feedbackBGL,
                entries: [
                    { binding: 0, resource: this.feedbackSampler },
                    { binding: 1, resource: view },
                ],
            }),
        );

        resource = {
            width,
            height,
            format,
            textures,
            views,
            bindGroups,
            readIndex: 0,
        };

        this.feedbackResources.set(key, resource);
        return resource;
    }

    #syncNodes(force) {
        if (!this.device || !this.cssWidth) return;
        const info = nodeInfo(this.scene, this.options);
        if (info.index < 0) {
            this.nodeLayer = -1;
            this.nodeCount = 0;
            return;
        }
        if (force || info.count !== this.nodeCount) {
            const data = new Float32Array(MAX_NODES * 8);
            for (let i = 0; i < info.count; i++) {
                const offset = i * 8;
                data[offset] = Math.random() * this.cssWidth;
                data[offset + 1] = Math.random() * this.cssHeight;
                data[offset + 2] = (Math.random() - 0.5) * 0.3;
                data[offset + 3] = (Math.random() - 0.5) * 0.3;
                data[offset + 4] = Math.random();
                data[offset + 5] = Math.random() * Math.PI * 2;
            }
            this.device.queue.writeBuffer(this.nodeBuffer, 0, data);
            this.nodeCount = info.count;
        }
        this.nodeLayer = info.index;
    }

    #upload(time) {
        const globals = new Float32Array(24);
        globals.set([this.cssWidth, this.cssHeight, this.dpr, time], 0);
        globals.set(
            [
                this.options.fps ?? 30,
                this.frame,
                Math.min(this.scene.layers.length, MAX_LAYERS),
                this.nodeLayer,
            ],
            4,
        );
        globals.set(hex4(this.palette.primary), 8);
        globals.set(hex4(this.palette.secondary), 12);
        globals.set(hex4(this.palette.accent), 16);
        globals.set(hex4(this.palette.background), 20);
        this.device.queue.writeBuffer(this.uniformBuffer, 0, globals);

        const packed = new Float32Array(MAX_LAYERS * 20);
        this.scene.layers.slice(0, MAX_LAYERS).forEach((layer, index) => {
            packed.set(encodeLayer(layer, this.options), index * 20);
        });
        this.device.queue.writeBuffer(this.layerBuffer, 0, packed);
    }

    render(time = performance.now() / 1000) {
        if (!this.device) return;
        this.#syncNodes(false);
        this.#upload(time);
        const encoder = this.device.createCommandEncoder();

        if (this.nodeLayer >= 0 && this.nodeCount > 0) {
            const compute = encoder.beginComputePass();
            compute.setPipeline(this.computePipeline);
            compute.setBindGroup(0, this.computeBG);
            compute.dispatchWorkgroups(Math.ceil(this.nodeCount / 64));
            compute.end();
        }

        // Update every persistent feedback layer before compositing the scene.
        this.scene.layers.slice(0, MAX_LAYERS).forEach((layer, index) => {
            const descriptor = shaderMap.get(layer.name);
            const pipelines = this.pipelines.get(layer.name);
            if (!descriptor || !pipelines?.feedback) return;

            const resource = this.#feedbackResource(index, descriptor);
            const readIndex = resource.readIndex;
            const writeIndex = 1 - readIndex;
            const firstVertex = index * VERTEX_STRIDE;

            const feedbackPass = encoder.beginRenderPass({
                colorAttachments: [
                    {
                        view: resource.views[writeIndex],
                        clearValue: { r: 0, g: 0, b: 0, a: 1 },
                        // The shader reads the previous texture, so this target can be cleared.
                        loadOp: "clear",
                        storeOp: "store",
                    },
                ],
            });

            feedbackPass.setPipeline(pipelines.feedback);
            feedbackPass.setBindGroup(0, this.renderBG);
            feedbackPass.setBindGroup(1, resource.bindGroups[readIndex]);
            feedbackPass.draw(3, 1, firstVertex);
            feedbackPass.end();

            // The frame we just wrote becomes the texture presented this frame
            // and the previous-frame input on the next frame.
            resource.readIndex = writeIndex;
        });

        const pass = encoder.beginRenderPass({
            colorAttachments: [
                {
                    view: this.context.getCurrentTexture().createView(),
                    clearValue: { r: 0, g: 0, b: 0, a: 0 },
                    loadOp: "clear",
                    storeOp: "store",
                },
            ],
        });
        pass.setBindGroup(0, this.renderBG);

        this.scene.layers.slice(0, MAX_LAYERS).forEach((layer, index) => {
            const descriptor = shaderMap.get(layer.name);
            const pipelines = this.pipelines.get(layer.name);
            if (!descriptor || !pipelines) return;
            const firstVertex = index * VERTEX_STRIDE;

            if (pipelines.full) {
                pass.setPipeline(pipelines.full);
                pass.draw(3, 1, firstVertex);
            }
            if (pipelines.feedbackPresent) {
                const resource = this.#feedbackResource(index, descriptor);
                pass.setPipeline(pipelines.feedbackPresent);
                pass.setBindGroup(1, resource.bindGroups[resource.readIndex]);
                pass.draw(3, 1, firstVertex);
            }
            if (pipelines.segment) {
                const count = drawCount(
                    layer,
                    "segment",
                    this.options,
                    this.cssWidth,
                    this.cssHeight,
                );
                if (count > 0) {
                    pass.setPipeline(pipelines.segment);
                    pass.draw(count * 6, 1, firstVertex);
                }
            }
            if (pipelines.sprite) {
                const count = drawCount(
                    layer,
                    "sprite",
                    this.options,
                    this.cssWidth,
                    this.cssHeight,
                );
                if (count > 0) {
                    pass.setPipeline(pipelines.sprite);
                    pass.draw(count * 6, 1, firstVertex);
                }
            }
        });

        pass.end();
        this.device.queue.submit([encoder.finish()]);
        this.frame++;
    }

    start() {
        this.stop();
        this.stopped = false;
        this.last = 0;
        const tick = (timestamp) => {
            if (this.stopped) return;
            this.raf = requestAnimationFrame(tick);
            const fps = this.options.fps ?? 30;
            if (fps === 0) return;
            const interval = 1000 / fps;
            if (timestamp - this.last < interval) return;
            this.last = timestamp;
            this.render(timestamp / 1000);
        };
        if ((this.options.fps ?? 30) === 0) this.render(0);
        else this.raf = requestAnimationFrame(tick);
    }

    stop() {
        this.stopped = true;
        if (this.raf) cancelAnimationFrame(this.raf);
        this.raf = 0;
    }

    destroy() {
        this.stop();
        this.resizeObserver?.disconnect();
        this.#destroyFeedbackResources();
    }
}

let activeRenderer = null;

export async function loop(
    canvas,
    scene,
    palette = DEFAULT_PALETTE,
    globalOptions = {},
) {
    stop();
    activeRenderer = new SubstrateGPU(canvas);
    await activeRenderer.init();
    activeRenderer.setScene(scene);
    activeRenderer.setPalette(palette);
    activeRenderer.setOptions(globalOptions);
    activeRenderer.start();
    return activeRenderer;
}

export function stop() {
    activeRenderer?.destroy();
    activeRenderer = null;
}

export async function renderStatic(
    canvas,
    scene,
    palette = DEFAULT_PALETTE,
    globalOptions = {},
) {
    const renderer = new SubstrateGPU(canvas);
    await renderer.init();
    renderer.setScene(scene);
    renderer.setPalette(palette);
    renderer.setOptions({ ...globalOptions, fps: 0 });
    renderer.render(0);
    return renderer;
}
