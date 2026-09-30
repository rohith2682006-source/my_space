const fs = require('fs');
const cp = require('child_process');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');
const pDepsFile = path.join(projectRoot, '.flutter-plugins-dependencies');

if (!fs.existsSync(pDepsFile)) {
  console.error('.flutter-plugins-dependencies not found!');
  process.exit(1);
}

const pDeps = JSON.parse(fs.readFileSync(pDepsFile, 'utf8'));
const symDir = path.join(projectRoot, 'windows', 'flutter', 'ephemeral', '.plugin_symlinks');
fs.mkdirSync(symDir, { recursive: true });

for (const p of pDeps.plugins.windows || []) {
  const dest = path.join(symDir, p.name);
  if (!fs.existsSync(dest)) {
    const src = p.path.replace(/[\\/]+$/, '');
    console.log(`Creating junction: ${p.name} -> ${src}`);
    try {
      cp.execSync(`cmd.exe /c mklink /J "${dest}" "${src}"`, { stdio: 'inherit' });
    } catch (err) {
      console.error(`Failed to link ${p.name}:`, err.message);
    }
  } else {
    console.log(`Plugin junction already exists: ${p.name}`);
  }
}

console.log('All Windows plugin junctions configured successfully.');
