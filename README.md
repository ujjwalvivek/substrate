# Substrate

Substrate is a composable procedural graphics engine. The GPU runtime renders WGSL primitives through WebGPU; the CPU runtime provides a Canvas2D reference implementation for comparison and fallback rendering.

## Commands

```bash
npm install
npm run dev             # builds the package, then serves the playground on :4321
npm run build           # builds the package, playground, and stages the playground
npm run validate        # validates all primitive WGSL files
npm run pack:check      # shows exactly what the npm package would contain
```

## Package API

The GPU engine is the package root:

```js
import {
  SubstrateGPU,
  compose,
  primitives,
  shaderDescriptors,
} from "@ujjwalvivek/substrate";
```

The Canvas2D reference engine and supporting modules use explicit subpaths:

```js
import * as CPU from "@ujjwalvivek/substrate/cpu";
import { getThemeColors } from "@ujjwalvivek/substrate/colors";
```

## Adding a shader

Add a `*.wgsl` file under `packages/substrate/src/shaders/primitives/`. Each file needs a `/* @substrate { ... } */` metadata block and one or more supported primitive functions.

The renderer discovers the files at package-build time. See the [shader contract](packages/substrate/src/shaders/primitives/README.md).
