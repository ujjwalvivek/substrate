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

## Recipes

A recipe is a named layer stack stored as plain JSON, so a site can ask for a wallpaper by name instead of defining layers itself.

```js
import { loop, recipeToScene } from "@ujjwalvivek/substrate";
import { getRecipe, recipeNames } from "@ujjwalvivek/substrate/recipes";

await loop(canvas, recipeToScene(getRecipe("root")), palette, { fps: 30 });
```

Format version 1 looks like this, with layers listed bottom to top:

```json
{
  "recipe": 1,
  "name": "root",
  "layers": [
    { "name": "vignette", "opacity": 1, "speed": 0, "density": 0,
      "params": { "innerRadius": 0.1, "outerRadius": 0.8 } }
  ]
}
```

Each layer names a GPU primitive. Opacity, speed and density become the layer's options and params are passed through, the same as a hand-built compose() call. Global speed, density and opacity still apply on top through the renderer options.

validateRecipe(recipe) returns { ok, errors }. It rejects an unknown recipe version, layers that are not an array, more than 8 layers, unknown primitive names, params a primitive does not declare, unknown keys, and numbers that are not finite. parseRecipe(text) does the same for pasted text, which is read with JSON.parse and never run as code. recipeToScene(recipe) validates first and throws with every message if the recipe is invalid.

The recipes entry ships root, the stack used on ujjwalvivek.com, and two candidates, nebula and signal. getRecipe(name) returns a fresh copy you can change. The playground's COPY RECIPE button copies the current stack as a version 1 recipe, with the global sliders baked into each layer.

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
