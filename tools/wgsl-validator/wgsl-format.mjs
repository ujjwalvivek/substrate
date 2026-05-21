#!/usr/bin/env node

import { format } from "@wasm-fmt/wgslfmt";

const args = process.argv.slice(2);

if (args.length !== 1 || args[0] !== "--stdin") {
    process.stderr.write(
        "Usage: node tools/wgsl-validator/wgsl-format.mjs --stdin\n",
    );
    process.exitCode = 2;
} else {
    try {
        process.stdin.setEncoding("utf8");
        let source = "";
        for await (const chunk of process.stdin) {
            source += chunk;
        }

        const formatted = format(source, {
            indent_symbol: "  ",
            trailing_commas: "ignore",
        });

        process.stdout.write(
            formatted.length > 0 && !formatted.endsWith("\n")
                ? formatted + "\n"
                : formatted,
        );
    } catch (error) {
        process.stderr.write(
            (error instanceof Error ? error.message : String(error)) + "\n",
        );
        process.exitCode = 1;
    }
}
