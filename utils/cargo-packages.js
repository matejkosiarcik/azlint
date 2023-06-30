const TOML = require('@iarna/toml')
const fs = require('fs');
const path = require('path');

const cargoToml = fs.readFileSync(path.join(__dirname, '..', 'linters', 'Cargo.toml'), 'utf8');
const cargoObj = TOML.parse(cargoToml);
const cargoDeps = cargoObj['dev-dependencies'];

for (const package in cargoDeps) {
    console.log(package, cargoDeps[package]);
}
