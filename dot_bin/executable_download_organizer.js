#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

function formatFolderName(date) {
  return (
    new Intl.DateTimeFormat(undefined, { month: "2-digit" }).format(date) +
    "-" +
    new Intl.DateTimeFormat(undefined, { month: "long" }).format(date)
  );
}

/** Source folder to organize files to. */
const base = process.argv[2] || "";
if (!base) {
  console.log("Specify a directory to organize into!");
  process.exit(1);
}
if (!fs.existsSync(base)) {
  console.log(`Directory "${base}" doesn't exist.`);
  process.exit(1);
}

/** Optional secondary folder to pull files from. */
const src = process.argv[3] || base;
if (!fs.existsSync(src)) {
  console.log(`Source directory "${src}" doesn't exist.`);
  process.exit(1);
}

for (const file of fs.readdirSync(src)) {
  const filepath = path.join(src, file),
    stat = fs.statSync(filepath);
  // ignore any 4-digit-year directories (2000, 2023, etc)
  if (file.length == 4 && Number(file) && stat.isDirectory()) continue;
  // ignore specific file names
  if ([".directory"].includes(file) && stat.isFile()) continue;

  const { mtime } = stat,
    monthFolder = formatFolderName(mtime);
  let newpath = base;
  if (!fs.existsSync((newpath = path.join(newpath, String(mtime.getFullYear())))))
    fs.mkdirSync(newpath);
  if (!fs.existsSync((newpath = path.join(newpath, monthFolder)))) fs.mkdirSync(newpath);
  const p = newpath,
    extname = path.extname(file),
    basename = path.basename(file, extname);
  let ct = 1;
  // initial test of file name
  newpath = path.join(p, file);
  while (fs.existsSync(newpath))
    // keep renaming file with incremented count
    newpath = path.join(p, `${basename}-${ct++}${extname}`);

  fs.renameSync(filepath, newpath);
  console.log(`${filepath} => ${newpath}`);
}

console.log("Done.");
process.exit(0);
