// Recipe format v1: { recipe: 1, name, layers: [{ name, opacity, speed, density, params }] }, layers bottom to top.
// A recipe is plain data. It is checked against the bundled primitive descriptors and never evaluated as code.
import { compose, primitives, shaderDescriptors } from "./renderer.js";

export const RECIPE_VERSION = 1;
export const MAX_RECIPE_LAYERS = 8;

const RECIPE_KEYS = new Set(["recipe", "name", "layers"]);
const LAYER_KEYS = new Set(["name", "opacity", "speed", "density", "params"]);
const LAYER_NUMBERS = ["opacity", "speed", "density"];
const COLOR_NAMES = new Set(["primary", "secondary", "accent", "background"]);

const descriptors = new Map(
    shaderDescriptors.map((descriptor) => [
        descriptor.name,
        new Map(descriptor.params.map((spec) => [spec.key, spec])),
    ]),
);

const isPlainObject = (value) =>
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype;

function checkParam(where, spec, value, errors) {
    if (spec.type === "color") {
        if (typeof value === "string" && COLOR_NAMES.has(value)) return;
        if (Number.isInteger(value) && value >= 0 && value <= 3) return;
        errors.push(
            `${where} must be one of primary, secondary, accent, background (or 0 to 3).`,
        );
        return;
    }
    if (spec.type === "bool") {
        if (typeof value === "boolean") return;
        if (typeof value === "number" && Number.isFinite(value)) return;
        errors.push(`${where} must be true, false or a finite number.`);
        return;
    }
    if (typeof value !== "number" || !Number.isFinite(value))
        errors.push(`${where} must be a finite number.`);
}

function checkLayer(layer, index, errors) {
    const at = `layers[${index}]`;
    if (!isPlainObject(layer)) {
        errors.push(`${at} must be an object.`);
        return;
    }
    for (const key of Object.keys(layer))
        if (!LAYER_KEYS.has(key)) errors.push(`${at} has an unknown key "${key}".`);
    if (typeof layer.name !== "string" || !layer.name) {
        errors.push(`${at}.name must be a primitive name.`);
        return;
    }
    const specs = descriptors.get(layer.name);
    if (!specs) {
        errors.push(`${at}.name "${layer.name}" is not a known primitive.`);
        return;
    }
    const where = `${at} (${layer.name})`;
    for (const key of LAYER_NUMBERS) {
        if (!(key in layer)) continue;
        const value = layer[key];
        if (typeof value !== "number" || !Number.isFinite(value))
            errors.push(`${where}.${key} must be a finite number.`);
    }
    if (!("params" in layer)) return;
    if (!isPlainObject(layer.params)) {
        errors.push(`${where}.params must be an object.`);
        return;
    }
    for (const [key, value] of Object.entries(layer.params)) {
        const spec = specs.get(key);
        if (!spec) {
            const known = [...specs.keys()];
            errors.push(
                `${where}.params.${key} is not a parameter of ${layer.name}` +
                    (known.length
                        ? ` (it takes ${known.join(", ")}).`
                        : " (it takes none)."),
            );
            continue;
        }
        checkParam(`${where}.params.${key}`, spec, value, errors);
    }
}

// Returns { ok: true, errors: [] } or { ok: false, errors: [message, ...] }.
export function validateRecipe(recipe) {
    const errors = [];
    if (!isPlainObject(recipe))
        return { ok: false, errors: ["A recipe must be a JSON object."] };
    if (recipe.recipe !== RECIPE_VERSION)
        errors.push(
            `Unknown recipe version ${JSON.stringify(recipe.recipe)}; this build reads version ${RECIPE_VERSION}.`,
        );
    for (const key of Object.keys(recipe))
        if (!RECIPE_KEYS.has(key)) errors.push(`Unknown key "${key}".`);
    if (typeof recipe.name !== "string" || !recipe.name)
        errors.push("name must be a non-empty string.");
    if (!Array.isArray(recipe.layers)) {
        errors.push("layers must be an array.");
    } else if (recipe.layers.length > MAX_RECIPE_LAYERS) {
        errors.push(
            `A recipe has at most ${MAX_RECIPE_LAYERS} layers; this one has ${recipe.layers.length}.`,
        );
    } else {
        recipe.layers.forEach((layer, index) => checkLayer(layer, index, errors));
    }
    return { ok: errors.length === 0, errors };
}

// Parses pasted text as JSON (never as code) and validates it.
export function parseRecipe(text) {
    let recipe;
    try {
        recipe = JSON.parse(String(text));
    } catch (error) {
        return { ok: false, errors: [`Not valid JSON: ${error.message}`] };
    }
    const result = validateRecipe(recipe);
    return result.ok ? { ...result, recipe } : result;
}

// Turns a valid recipe into a GPU scene, the same way root's toScene does: opacity, speed and density become layer
// options and params are spread in. Throws with every validation message if the recipe is invalid.
export function recipeToScene(recipe) {
    const { ok, errors } = validateRecipe(recipe);
    if (!ok) throw new Error(`Invalid substrate recipe:\n${errors.join("\n")}`);
    return compose(
        recipe.layers.map(({ name, opacity, speed, density, params }) => {
            const options = {};
            if (opacity !== undefined) options.opacity = opacity;
            if (speed !== undefined) options.speed = speed;
            if (density !== undefined) options.density = density;
            return {
                fn: primitives[name],
                options: { ...options, ...(params || {}) },
            };
        }),
    );
}
