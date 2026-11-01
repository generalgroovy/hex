import { cp, lstat, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const tacticsRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const distRoot = path.resolve(tacticsRoot, "dist");
const clientRoot = path.resolve(distRoot, "client");
const serverRoot = path.resolve(distRoot, "server");
const outputRoot = path.resolve(distRoot, "pages-release");
const marker = path.join(distRoot, ".hex-pages-release-marker");
const legacyMarker = path.join(outputRoot, ".hex-pages-stage");
const markerText = "Generated H.E.X. Pages staging output. Safe to replace.";

if (!clientRoot.startsWith(`${distRoot}${path.sep}`) ||
    !serverRoot.startsWith(`${distRoot}${path.sep}`) ||
    !outputRoot.startsWith(`${distRoot}${path.sep}`)) {
  throw new Error("Refusing to stage outside the generated dist directory.");
}

async function markerMatches(file) {
  try {
    return (await readFile(file, "utf8")).trim() === markerText;
  } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }
}

if (await markerMatches(marker) || await markerMatches(legacyMarker)) {
  try {
    const outputInfo = await lstat(outputRoot);
    if (outputInfo.isSymbolicLink()) {
      throw new Error("Refusing to replace a linked Pages output directory.");
    }
    await rm(outputRoot, { recursive: true, force: true });
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
} else {
  try {
    const existingFiles = await readdir(outputRoot);
    if (existingFiles.length > 0) {
      throw new Error("Refusing to replace an unrecognized Pages output directory.");
    }
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
}

await mkdir(outputRoot, { recursive: true });
await cp(clientRoot, outputRoot, { recursive: true });
await writeFile(marker, `${markerText}\n`);
await writeFile(
  path.join(outputRoot, "_worker.js"),
  'export { default } from "../server/index.js";\n',
);

console.log(`Staged ${outputRoot}`);
