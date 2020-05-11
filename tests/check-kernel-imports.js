#! /usr/bin/env node

const path = require("path");
const fs = require("fs");
const readline = require("readline");

async function* getFiles(dir) {
  const dirents = await fs.promises.readdir(dir, { withFileTypes: true });
  for (const dirent of dirents) {
    const res = path.resolve(dir, dirent.name);
    if (dirent.isDirectory()) {
      yield* getFiles(res);
    } else {
      yield res;
    }
  }
}

async function* asyncFlatMap(source, mapper) {
  for await (const item of source) {
    for await (const nestedItem of mapper(item)) {
      yield nestedItem;
    }
  }
}

class CallLocation {
  constructor(path, line) {
    this.path = path;
    this.line = line;
    Object.freeze(this);
  }
}

function addCall(map, call, location) {
  let callArray = (() => {
    if (!map.has(call)) {
      const a = [];
      map.set(call, a);
      return a;
    }
    return map.get(call);
  })();

  callArray.push(location);
}

async function* withLineNumbers(rl) {
  let i = 1;
  for await (const line of rl) {
    yield { line, number: i };
    i += 1;
  }
}

async function processElmFile(file, elmDefinitions, kernelCalls) {
  const lines = withLineNumbers(
    readline.createInterface({
      input: fs.createReadStream(file),
    })
  );

  let moduleName = null;
  const kernelImports = new Map();

  const errors = [];
  const warnings = [];

  function addDef(defName) {
    if (moduleName === null) {
      errors.push(
        `Elm definition before module line (or missing module line) at ${file}:${number}.`
      );
    }
    elmDefinitions.add(`${moduleName}.${defName}`);
  }

  for await (const { number, line } of lines) {
    const moduleNameMatch = line.match(/module\s*(\S+)\s.*exposing/u);
    // Ignore all but the first module line, some comments include example elm
    // files which cause multiple matches here. In these cases it is the first
    // module line that is the valid one. (We hope!)
    if (moduleNameMatch !== null && moduleName == null) {
      moduleName = moduleNameMatch[1];
    }

    const importMatch = line.match(/^import\s+(Elm\.Kernel\.\w+)/u);
    if (importMatch !== null) {
      kernelImports.set(importMatch[1], false);
    } else {
      const elmVarMatch = line.match(/^(\S*).*?=/u);
      if (elmVarMatch !== null) {
        addDef(elmVarMatch[1]);
      }

      const elmTypeMatch = line.match(/type\s+(?:alias\s+)?(\S+)/u);
      if (elmTypeMatch !== null) {
        addDef(elmTypeMatch[1]);
      }

      const elmCustomTypeMatch = line.match(/  (?:  )?[=|] (\w*)/u);
      if (elmCustomTypeMatch !== null) {
        addDef(elmCustomTypeMatch[1]);
      }

      const kernelCallMatch = line.match(/(Elm\.Kernel\.\w+).\w+/u);
      if (kernelCallMatch !== null) {
        const kernelCall = kernelCallMatch[0];
        const kernelModule = kernelCallMatch[1];
        if (kernelImports.has(kernelModule)) {
          kernelImports.set(kernelModule, true);
        } else {
          errors.push(`Kernel call ${kernelCall} at ${file}:${number} missing import`);
        }
        addCall(kernelCalls, kernelCall, new CallLocation(file, number));
      }
    }
  }

  for (const [kernelModule, used] of kernelImports.entries()) {
    if (!used) {
      warnings.push(`Kernel import of ${kernelModule} is unused in ${file}`);
    }
  }

  return { errors, warnings };
}

async function processJsFile(file, importedDefs, kernelDefinitions) {
  const lines = withLineNumbers(
    readline.createInterface({
      input: fs.createReadStream(file),
    })
  );

  const moduleName = path.basename(file, ".js");

  const imports = new Map();

  const errors = [];
  const warnings = [];

  for await (const { number, line } of lines) {
    const importMatch = line.match(
      /import\s+((?:(?:\w|\.)+\.)?(\w+))\s+(?:as (\w+)\s+)?exposing\s+\((\w+(?:,\s+\w+)*)\)/
    );
    if (importMatch !== null) {
      // use alias if it is there, otherwise use last part of import.
      const moduleAlias = importMatch[3] !== undefined ? importMatch[3] : importMatch[2];
      const importedModulePath = importMatch[1];
      for (const defName of importMatch[4].split(",").map((s) => s.trim())) {
        imports.set(`__${moduleAlias}_${defName}`, false);

        const callFullPath = `${importedModulePath}.${defName}`;
        addCall(importedDefs, callFullPath, new CallLocation(file, number));
      }
      continue;
    }

    let defMatch = line.match(/^(?:var|const|let)\s*(_(\w+?)_(\w+))\s*=/u);
    if (defMatch === null) {
      defMatch = line.match(/^function\s*(_(\w+?)_(\w+))\s*\(/u);
    }
    if (defMatch !== null) {
      if (defMatch[2] !== moduleName) {
        errors.push(
          `Kernel definition ${defMatch[1]} at ${file}:${number} should match _${moduleName}_*`
        );
      }
      let defName = defMatch[3];
      if (defName.endsWith("__DEBUG")) {
        defName = defName.substr(0, defName.length - "__DEBUG".length);
      } else if (defName.endsWith("__PROD")) {
        defName = defName.substr(0, defName.length - "__PROD".length);
      }
      // todo(Harry): check __DEBUG and __PROD match.

      kernelDefinitions.add(`Elm.Kernel.${moduleName}.${defName}`);
    }

    let index = 0;
    while (true) {
      const kernelCallMatch = line.substr(index).match(/_?_(\w+?)_\w+/u);
      if (kernelCallMatch === null) {
        break;
      } else {
        const calledModuleName = kernelCallMatch[1];
        const kernelCall = kernelCallMatch[0];
        if (
          calledModuleName[0] === calledModuleName[0].toUpperCase() &&
          !(calledModuleName[0] >= "0" && calledModuleName[0] <= "9")
        ) {
          if (kernelCall.startsWith("__")) {
            // External kernel call
            if (imports.has(kernelCall)) {
              imports.set(kernelCall, true);
            } else {
              errors.push(`Kernel call ${kernelCall} at ${file}:${number} missing import`);
            }
          } else {
            if (calledModuleName !== moduleName) {
              errors.push(
                `Non-local kernel call ${kernelCall} at ${file}:${number} must start with a double underscore`
              );
            }
          }
        }
        index += kernelCallMatch.index + kernelCallMatch[0].length;
      }
    }
  }

  for (const [kernelModule, used] of imports.entries()) {
    if (!used) {
      warnings.push(`Import of ${kernelModule} is unused in ${file}`);
    }
  }

  return { errors, warnings };
}

async function main() {
  if (process.argv.length < 3) {
    console.error("check-kernel-imports: error! at least one path to source directories required");
    process.exit(1);
  }

  if (process.argv.includes("-h") || process.argv.includes("--help")) {
    console.log(
      `

Usage: check-kernel-imports SOURCE_DIRECTORIES ...

check-kernel-imports checks that
  1. Use of kernel definitions match imports in elm files.
  2. Use of kernel definition in elm files match a definition in a javascipt
      file.
  3. Use of elm definition in javascript files matches definition in an elm
      file.
  4. Use of an external definition matches an import in a javascript file.
Note that 3. is a best effort attempt. There are some missed cases and some
false postives. Warnings will be issued for unused imports in javascript files.

Options:
      -h, --help     display this help and exit

    `.trim()
    );
    process.exit(0);
  }

  const sourceDirs = process.argv.slice(2);

  // keys: kernel definition full elm path
  const kernelDefinitions = new Set();
  // keys: elm definition full elm path
  const elmDefinitions = new Set();
  // keys: kernel call, values: array of CallLocations
  const kernelCalls = new Map();
  // keys: full elm path of call, values: array of CallLocations
  const elmCallsFromKernel = new Map();

  // Add some definitions from elm/json
  elmDefinitions.add("Elm.Kernel.Json.run");
  elmDefinitions.add("Elm.Kernel.Json.wrap");
  elmDefinitions.add("Elm.Kernel.Json.unwrap");
  elmDefinitions.add("Elm.Kernel.Json.errorToString");

  const allErrors = [];
  const allWarnings = [];

  for await (const f of asyncFlatMap(sourceDirs, getFiles)) {
    const extname = path.extname(f);
    if (extname === ".elm") {
      const { errors, warnings } = await processElmFile(f, elmDefinitions, kernelCalls);
      allErrors.push(...errors);
      allWarnings.push(...warnings);
    } else if (extname === ".js") {
      const { errors, warnings } = await processJsFile(f, elmCallsFromKernel, kernelDefinitions);
      allErrors.push(...errors);
      allWarnings.push(...warnings);
    }
  }
  for (const [call, locations] of kernelCalls.entries()) {
    if (!kernelDefinitions.has(call)) {
      for (const location of locations) {
        allErrors.push(
          `Kernel call ${call} at ${location.path}:${location.line} missing definition`
        );
      }
    }
  }
  for (const [call, locations] of elmCallsFromKernel.entries()) {
    if (!elmDefinitions.has(call) && !kernelDefinitions.has(call)) {
      for (const location of locations) {
        allErrors.push(`Import of ${call} at ${location.path}:${location.line} missing definition`);
      }
    }
  }
  console.error(`${allWarnings.length} warnings`);
  console.error(allWarnings.join("\n"));
  console.error("");
  console.error(`${allErrors.length} errors`);
  console.error(allErrors.join("\n"));
  process.exitCode = allErrors.length === 0 ? 0 : 1;
}

main();
