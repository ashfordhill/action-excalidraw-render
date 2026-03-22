const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const format = (process.env.INPUT_FORMAT || 'svg').toLowerCase();
const githubToken = process.env.INPUT_GITHUB_TOKEN;
const commitMessage = process.env.INPUT_COMMIT_MESSAGE || 'chore: render excalidraw files [skip ci]';
const committerName = process.env.INPUT_COMMITTER_NAME || 'github-actions[bot]';
const committerEmail = process.env.INPUT_COMMITTER_EMAIL || 'github-actions[bot]@users.noreply.github.com';
const workspace = process.env.GITHUB_WORKSPACE || process.cwd();
const githubRepository = process.env.GITHUB_REPOSITORY;

const EXCLUDED_DIRS = new Set(['.git', 'node_modules', '.zenflow']);

function findExcalidrawFiles(dir) {
  const results = [];
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return results;
  }
  for (const entry of entries) {
    if (EXCLUDED_DIRS.has(entry.name)) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findExcalidrawFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.excalidraw')) {
      results.push(fullPath);
    }
  }
  return results;
}

async function convertToSvg(excalidrawPath) {
  const excalidrawToSvg = require('excalidraw-to-svg');
  const data = JSON.parse(fs.readFileSync(excalidrawPath, 'utf8'));
  const svgElement = await excalidrawToSvg(data);
  return svgElement.outerHTML;
}

async function convertToPng(svgContent) {
  const { Resvg } = require('@resvg/resvg-js');
  const resvg = new Resvg(svgContent, {
    fitTo: { mode: 'original' },
  });
  const pngData = resvg.render();
  return pngData.asPng();
}

function exec(cmd, opts = {}) {
  return execSync(cmd, { cwd: workspace, stdio: 'pipe', ...opts }).toString().trim();
}

async function main() {
  if (!['svg', 'png', 'both'].includes(format)) {
    console.error(`Invalid format "${format}". Must be one of: svg, png, both`);
    process.exit(1);
  }

  const files = findExcalidrawFiles(workspace);
  console.log(`Found ${files.length} .excalidraw file(s)`);

  if (files.length === 0) {
    console.log('Nothing to do.');
    return;
  }

  const convertSvg = format === 'svg' || format === 'both';
  const convertPng = format === 'png' || format === 'both';
  const changedFiles = [];

  for (const file of files) {
    const basePath = file.slice(0, -'.excalidraw'.length);
    console.log(`Processing: ${path.relative(workspace, file)}`);

    let svgContent = null;

    if (convertSvg || convertPng) {
      try {
        svgContent = await convertToSvg(file);
      } catch (err) {
        console.error(`  ERROR converting to SVG: ${err.message}`);
        continue;
      }
    }

    if (convertSvg) {
      const svgPath = basePath + '.svg';
      fs.writeFileSync(svgPath, svgContent, 'utf8');
      changedFiles.push(svgPath);
      console.log(`  -> ${path.relative(workspace, svgPath)}`);
    }

    if (convertPng) {
      try {
        const pngBuffer = await convertToPng(svgContent);
        const pngPath = basePath + '.png';
        fs.writeFileSync(pngPath, pngBuffer);
        changedFiles.push(pngPath);
        console.log(`  -> ${path.relative(workspace, pngPath)}`);
      } catch (err) {
        console.error(`  ERROR converting to PNG: ${err.message}`);
      }
    }
  }

  if (changedFiles.length === 0) {
    console.log('No files were generated.');
    return;
  }

  exec(`git config user.email "${committerEmail}"`);
  exec(`git config user.name "${committerName}"`);

  for (const file of changedFiles) {
    exec(`git add "${file}"`);
  }

  try {
    exec('git diff --staged --exit-code');
    console.log('No changes to commit (files already up to date).');
  } catch {
    exec(`git commit -m "${commitMessage}"`);

    const remoteUrl = `https://x-access-token:${githubToken}@github.com/${githubRepository}.git`;
    exec(`git remote set-url origin "${remoteUrl}"`);
    exec('git push');
    console.log(`Committed and pushed ${changedFiles.length} rendered file(s).`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
