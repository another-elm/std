#! /usr/bin/env node

const fs = require("fs");
const readline = require("readline");

const HELP = `

Usage: generate-globals FILE ...

Parse the imports of a kernel file and write suitable eslint global comments to
stdout. See <https://eslint.org/docs/user-guide/configuring#specifying-globals>.

Options:
-h, --help     display this help and exit

`.trim();

async function processFile(file) {
  const lines = readline.createInterface({
    input: fs.createReadStream(file),
  });

  const globals = [];

  for await (const line of lines) {
    const importMatch = line.match(
      /import\s+((?:[.\w]+\.)?(\w+))\s+(?:as (\w+)\s+)?exposing\s+\((\w+(?:,\s+\w+)*)\)/
    );

    if (importMatch !== null) {
      // Use alias if it is there, otherwise use last part of import.
      const moduleAlias = importMatch[3] === undefined ? importMatch[2] : importMatch[3];
      const vars = importMatch[4].split(",").map((defName) => `__${moduleAlias}_${defName.trim()}`);

      globals.push(`/* global ${vars.join(", ")} */`);
    }
  }

  return globals.join("\n");
}

async function main() {
  if (process.argv.length !== 3) {
    console.error("check-kernel-imports: error! path to file required");
    process.exit(1);
  }

  if (process.argv.includes("-h") || process.argv.includes("--help")) {
    console.log(HELP);
    process.exit(0);
  }

  const globals = await processFile(process.argv[2]);
  console.log("/* global F2, F3, F4 */");
  console.log("/* global A2, A3, A4 */");
  console.log(globals);
}

main();
