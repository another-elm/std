const fs = require("fs");
const path = require("path");

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

async function main() {
  if (process.argv.length !== 3) {
    console.error("update-json: error! path to suite directory required");
    process.exit(1);
  }

  if (process.argv.includes("-h") || process.argv.includes("--help")) {
    console.log(
      `

?

    `.trim()
    );
    process.exit(0);
  }

  const sourceDir = process.argv[2];

  const allErrors = [];
  const allWarnings = [];

  for await (const f of getFiles(sourceDir)) {
    const filename = path.basename(f);
    if (filename === "output-old.json") {
      const old = JSON.parse(await fs.promises.readFile(f, "utf-8"));
      const hasPorts = Object.prototype.hasOwnProperty.call(old, "ports");
      if (
        Object.keys(old).length !== 0 &&
        (Object.keys(old).length !== 1 || !hasPorts)
      ) {
        allErrors.push(`Strange json in ${f}`);
        continue;
      }
      if (hasPorts && Object.keys(old.ports).length !== 1) {
        allErrors.push(`Two different ports in ${f}`);
        continue;
      }
      const ports = [];
      if (hasPorts) {
        for (const [portName, values] of Object.entries(old.ports)) {
          for (const value of values) {
            ports.push(['command', portName, value]);
          }
        }
      }
      const newer = {
        ports,
      };
      await fs.promises.writeFile(
        path.join(path.dirname(f), "output.json"),
        JSON.stringify(newer, null, '    '),
        "utf-8"
      );
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
