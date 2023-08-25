const fs = require('fs');
const process = require('process');
const YAML = require('yaml');

const yamlFile = process.argv.at(-1);
const yamlContent = fs.readFileSync(yamlFile, 'utf8');
const yamlObject = YAML.parse(yamlContent);

function stringifyYaml(value) {
    if (typeof value === 'string') {
        return YAML.stringify(value.trim()).trim();
    } else if (typeof value === 'number') {
        return value.toString();
    } else if (typeof value === 'boolean') {
        return value ? 'yes' : 'no';
    } else if (value === null) {
        return 'null';
    } else if (Array.isArray(value)) {
        const content = value.map((el) => stringifyYaml(el)).join(',');
        return `[${content}]`;
    } else {
        const content = Object.keys(value).map((key) => `${key}: ${stringifyYaml(value[key])}`).join(',');
        return `{${content}}`;
    }
}

const minifiedYamlContent = stringifyYaml(yamlObject);
if (minifiedYamlContent.length < yamlContent.length) {
    fs.writeFileSync(yamlFile, minifiedYamlContent, 'utf8');
}
