#! /usr/bin/env node

const path = require('path');
const fs = require('fs');
const readline = require('readline');

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

class CallLocation {
  constructor(path, line) {
    this.path = path;
    this.line = line;
    Object.freeze(this);
  }
}

async function* withLineNumbers(rl) {
  let i = 1;
  for await (const line of rl) {
    yield { line, number: i }
    i += 1;
  }
}

async function processElmFile(file, kernelCalls) {
  const lines = withLineNumbers(readline.createInterface({
    input: fs.createReadStream(file)
  }));

  const kernelImports = new Map();

  const errors = [];
  const warnings = [];

  for await (const {number, line} of lines) {
    const importMatch = line.match(/^import\s+(Elm\.Kernel\.\w+)/u);
    if (importMatch !== null) {
      kernelImports.set(importMatch[1], false);
    } else {
      const kernelCallMatch = line.match(/(Elm\.Kernel\.\w+).\w+/u);
      if (kernelCallMatch !== null) {
        const kernelCall = kernelCallMatch[0];
        const kernelModule = kernelCallMatch[1];
        if (kernelImports.has(kernelModule)) {
          kernelImports.set(kernelModule, true);
        } else {
          errors.push(`Kernel call ${kernelCall} at ${file}:${number} missing import`);
        }
        (() => {
          if (!kernelCalls.has(kernelCall)) {
            const a = [];
            kernelCalls.set(kernelCall, a);
            return a;
          }
          return kernelCalls.get(kernelCall);
        })().push(new CallLocation(file, number));
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

async function processJsFile(file, kernelDefinitions) {
  const lines = withLineNumbers(readline.createInterface({
    input: fs.createReadStream(file)
  }));

  const moduleName = path.basename(file, '.js');

  const imports = new Map();

  const errors = [];
  const warnings = [];

  for await (const {number, line} of lines) {

    const importMatch = line.match(/import\s+(?:(?:\w|\.)+\.)?(\w+)\s+(?:as (\w+)\s+)?exposing\s+\((\w+(?:,\s+\w+)*)\)/);
    if (importMatch !== null) {
      // use alias if it is there, otherwise use last part of import.
      let moduleAlias = importMatch[2] !== undefined ? importMatch[2] : importMatch[1];
      for (const defName of importMatch[3].split(',').map(s => s.trim())) {
        imports.set(`__${moduleAlias}_${defName}`, false);
      }
      continue;
    }

    let defMatch = line.match(/^(?:var|const|let)\s*(_(\w+?)_(\w+))\s*=/u);
    if (defMatch === null) {
      defMatch = line.match(/^function\s*(_(\w+?)_(\w+))\s*\(/u);
    }
    if (defMatch !== null) {
      if (defMatch[2] !== moduleName) {
        errors.push(`Kernel definition ${defMatch[1]} at ${file}:${number} should match _${moduleName}_*`);
      }
      let defName = defMatch[3];
      if (defName.endsWith('__DEBUG')) {
        defName = defName.substr(0, defName.length - '__DEBUG'.length);
      } else if (defName.endsWith('__PROD')) {
        defName = defName.substr(0, defName.length - '__PROD'.length);
      }
      // todo(Harry): check __DEBUG and __PROD match.

      kernelDefinitions.add(`Elm.Kernel.${moduleName}.${defName}`);
      continue;
    }

    let index = 0;
    while (true) {
      const kernelCallMatch = line.substr(index).match(/__\w+_\w+/u);
      if (kernelCallMatch === null) {
        break;
      } else {
        const kernelCall = kernelCallMatch[0];
        if (imports.has(kernelCall)) {
          imports.set(kernelCall, true);
        } else {
          errors.push(`Kernel call ${kernelCall} at ${file}:${number} missing import`);
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

  return  {errors, warnings};
}

(async () => {
  // keys: kernel definition full elm path
  const kernelDefinitions = new Set();
  // keys: kernel call, values: array of CallLocations
  const kernelCalls = new Map();

  const allErrors = [];
  const allWarnings = [];

  for await (const f of getFiles(process.argv[2])) {
    const extname = path.extname(f);
    if (extname === '.elm') {
      const { errors, warnings } = await processElmFile(f, kernelCalls);
      allErrors.push(...errors);
      allWarnings.push(...warnings);
    } else if (extname === '.js') {
      const { errors, warnings } = await processJsFile(f, kernelDefinitions);
      allErrors.push(...errors);
      allWarnings.push(...warnings);
    }
  }
  for (const [call, locations] of kernelCalls.entries()) {
    if (!kernelDefinitions.has(call)) {
      for (const location of locations) {
        allErrors.push(`Kernel call ${call} at ${location.path}:${location.line} missing definition`);
      }
    }
  }
  console.error(`${allWarnings.length} warnings`);
  console.error(allWarnings.join('\n'));
  console.error('');
  console.error(`${allErrors.length} errors`)
  console.error(allErrors.join('\n'));
  process.exitCode = allErrors.length === 0 ? 0 : 1;
})()
