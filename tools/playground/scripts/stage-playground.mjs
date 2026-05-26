import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(fileURLToPath(new URL("../../..", import.meta.url)));
const source = path.join(root, "tools", "playground", "dist");
const target = path.join(root, "packages", "substrate", "dist", "playground");

if (!fs.existsSync(source)) {
  throw new Error(`Playground build not found: ${source}`);
}

fs.rmSync(target, { force: true, recursive: true });
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.cpSync(source, target, { recursive: true });
console.log(`staged playground at ${path.relative(root, target)}`);
