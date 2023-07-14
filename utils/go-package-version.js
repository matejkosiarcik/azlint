const fs = require('fs');
const path = require('path');
const process = require('process');
const YAML = require('yaml');

const packageName = process.argv.at(-1);
const gitman = YAML.parse(fs.readFileSync(path.join(__dirname, '..', 'linters', 'gitman.yml'), 'utf8'));
const package = gitman['sources_locked'].find((el) => el.name === packageName);
if (!package) {
    console.error(`Cannot find repo: ${packageName}`);
    process.exit(1);
}
console.log(package.rev);
