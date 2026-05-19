# @ujjwalvivek/substrate

Composable procedural graphics for WebGPU/WGSL.

## GPU usage

```js
import {
  SubstrateGPU,
  compose,
  primitives,
} from "@ujjwalvivek/substrate";

const renderer = await new SubstrateGPU(canvas).init();
renderer.setScene(compose([
  { fn: primitives.background },
  { fn: primitives.vignette },
]));
renderer.start();
```

The package root exports the WebGPU runtime, composition helpers, discovered primitive functions, and shader descriptors. WGSL source is bundled into the runtime; consumers do not need to host a separate shader directory.

## CPU reference API

```js
import { compose, loop, primitives, stop } from "@ujjwalvivek/substrate/cpu";

const scene = compose([{ fn: primitives.background }]);
loop(canvas, scene, palette, { fps: 30 });
stop();
```

Additional modules are available at `@ujjwalvivek/substrate/colors`, `@ujjwalvivek/substrate/theme`, and `@ujjwalvivek/substrate/core`.

## Included playground

Also contains the compiled Svelte playground at `dist/playground/`. It includes the shader controls, CPU/GPU comparison view, frame capture, GIF export, and a recipe generator.
