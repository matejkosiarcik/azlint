import fsSync from 'fs';
import path from 'path';
import { listDirectory, matchFiles } from './utils';

export const configFiles = {
    // https://black.readthedocs.io/en/stable/usage_and_configuration/the_basics.html#configuration-via-a-file
    black: ['black', '.black'],
    // Also:
    // - pyproject.toml with "[tool.black]"

    // No source
    checkmake: 'checkmake.ini',

    // https://github.com/replicatedhq/dockerfilelint#configuring
    dockerfilelint: '.dockerfilelintrc',

    // https://flake8.pycqa.org/en/latest/user/configuration.html
    flake8: '.flake8',
    // Also:
    // - setup.cfg with "[flake8]"
    // - tox.ini with "[flake8]"

    // https://github.com/hadolint/hadolint#configure
    hadolint: ['hadolint.yaml', '.hadolint.yaml'],

    // https://htmlhint.com/docs/user-guide/configuration
    htmlhint: '.htmlhintrc',

    // No source
    htmllint: '.htmllintrc',

    // https://pycqa.github.io/isort/docs/configuration/config_files.html
    isort: '.isort.cfg',
    // Also:
    // - pyproject.toml with "[tool.isort]"
    // - setup.cfg with "[isort]"
    // - tox.ini with "[isort]"

    // https://github.com/kucherenko/jscpd/tree/master/packages/jscpd#config-file
    jscpd: '.jscpd.json',

    // https://github.com/prantlf/jsonlint#configuration
    jsonlint: ['.jsonlintrc', '.jsonlintrc.{cjs,js,json,yaml,yml}', 'jsonlint.config.{cjs,js}'],

    // No source
    'markdown-link-check': '.markdown-link-check.json',

    // https://github.com/igorshubovych/markdownlint-cli#configuration
    markdownlint: ['.markdownlintrc', '.markdownlint.{json,jsonc,yaml,yml}'],

    // https://github.com/markdownlint/markdownlint/blob/main/docs/configuration.md#mdl-configuration
    mdl: '.mdlrc',

    // https://prettier.io/docs/en/configuration.html
    prettier: ['.prettierrc', '.prettierrc.{js,cjs,mjs,json,json5,toml,yaml,yml}', 'prettier.config.{cjs,js,mjs}'],

    // https://github.com/amperser/proselint#checks
    proselint: '.proselintrc',

    // https://pycodestyle.pycqa.org/en/latest/intro.html#configuration
    pycodestyle: ['pycodestyle', '.pycodestyle'],
    // Also:
    // - setup.cfg with "[pycodestyle]"
    // - tox.ini with "[pycodestyle]"

    // https://pylint.pycqa.org/en/latest/user_guide/usage/run.html#command-line-options
    pylint: ['pylintrc', '.pylintrc'],
    // Also:
    // - pyproject.toml with "[tool.pylint."
    // - setup.cfg with "[pylint."
    // - tox.ini with "[pylint."

    // https://github.com/secretlint/secretlint#configuration
    secretlint: '.secretlintrc.{js,json,yml}',

    // https://github.com/birjj/svglint#config
    svglint: '.svglintrc.js',

    // https://textlint.github.io/docs/configuring.html#configuration-files
    textlint: ['.textlintrc', '.textlintrc.{js,json,yaml,yml}'],

    // https://yamllint.readthedocs.io/en/stable/configuration.html
    yamllint: ['.yamllint', '.yamllint.{yaml,yml}'],
};

export const pythonGeneralConfigFiles = {
    // https://black.readthedocs.io/en/stable/usage_and_configuration/the_basics.html#configuration-via-a-file
    black: [
        {
            file: 'pyproject.toml',
            content: "[tool.black]",
        }
    ],

    // https://flake8.pycqa.org/en/latest/user/configuration.html
    flake8: [
        {
            file: 'setup.cfg',
            content: "[flake8]",
        }, {
            file: 'tox.ini',
            content: "[flake8]",
        }
    ],

    // https://pycqa.github.io/isort/docs/configuration/config_files.html
    isort: [
        {
            file: 'pyproject.toml',
            content: '[tool.isort]',
        },
        {
            file: 'setup.cfg',
            content: "[isort]",
        },
        {
            file: 'tox.ini',
            content: "[isort]",
        },
    ],

    // https://pycodestyle.pycqa.org/en/latest/intro.html#configuration
    pycodestyle: [
        {
            file: 'setup.cfg',
            content: "[pycodestyle]",
        },
        {
            file: 'tox.ini',
            content: "[pycodestyle]",
        },
    ],

    // https://pylint.pycqa.org/en/latest/user_guide/usage/run.html#command-line-options
    pylint: [
        {
            file: 'pyproject.toml',
            content: "[tool.pylint.",
        },
        {
            file: 'setup.cfg',
            content: "[pylint.",
        },
        {
            file: 'tox.ini',
            content: "[pylint.",
        },
    ],
};

/**
 * Returns config directories in the following order:
 * - AZLINT_FOO_CONFIG_DIR
 * - AZLINT_CONFIG_DIR
 * - . (project root)
 * - ./.config
 */
function getConfigDirs(envName: string): string[] {
    const output: string[] = [];

    // First check if specific FOO_CONFIG_DIR is set
    const linterConfigDir = process.env[`AZLINT_${envName}_CONFIG_DIR`];
    if (linterConfigDir) {
        output.push(linterConfigDir);
    }

    // Check if global CONFIG_DIR is set
    const generalConfigDir = process.env['AZLINT_CONFIG_DIR'];
    if (generalConfigDir) {
        output.push(generalConfigDir);
    }

    // Add CWD as default
    output.push('.');

    // Check .config/ subdirectory
    if (fsSync.existsSync('.config')) {
        output.push('.config');
    }

    return output;
}

/**
 * Find config file for given linter
 *
 * NOTE: Has a special mode for python, because most python linters can be configured with:
 * - a) specific config file, eg. `.isort.cfg`
 * - b) common config file, eg. `setup.cfg` - but only when it contains eg. `[isort]` section
 */
async function findConfigFile(options: {
    linter: keyof typeof configFiles,
    linterType?: 'generic' | 'python' | undefined,
}): Promise<string | undefined> {
    const linter = options.linter;
    const envName = options.linter.replace(/\-/g, '_').toUpperCase();
    const customConfigFilePath = process.env[`AZLINT_${envName}_CONFIG_FILE`];
    const linterType = options.linterType ?? 'generic';

    const configDirectories = getConfigDirs(envName);

    if (customConfigFilePath) {
        const foundConfigFile = configDirectories
            .map((configDir) => {
                const overrideConfigFile = path.join(configDir, customConfigFilePath);
                return fsSync.existsSync(overrideConfigFile) ? overrideConfigFile : undefined;
            })
            .filter((el) => el)
            .at(0);
        if (foundConfigFile) {
            return foundConfigFile;
        }
    }

    if (linterType === 'python') {
        const pythonConfigFiles = (() => {
            let files = pythonGeneralConfigFiles[linter as keyof typeof pythonGeneralConfigFiles];
            if (!files) {
                return [];
            }
            return Array.isArray(files) ? files : [files];
        })();

        const pythonConfigFile = (await Promise.all(configDirectories
            .map(async (configDir) => {
                const allFilesInConfigDirectory = await listDirectory(configDir, { recursive: false });
                return (await Promise.all(pythonConfigFiles.map(async (configEntry) => {
                    const existingConfigFiles = matchFiles(allFilesInConfigDirectory, configEntry.file);
                    return existingConfigFiles.filter((existingConfigFile) => {
                        const configContent = fsSync.readFileSync(existingConfigFile, 'utf8');
                        return configContent.split('\n').some((line) => line.includes(configEntry.content))
                    }).at(0);
                })))
                .filter((file) => file)
                .at(0);
            })))
            .filter((file) => file)
            .at(0);

        if (pythonConfigFile) {
            return pythonConfigFile;
        }
    }

    const defaultConfigFiles = (() => {
        let files = configFiles[linter];
        return Array.isArray(files) ? files : [files];
    })();

    const foundConfigFile = (await Promise.all(configDirectories
        .map(async (configDir) => {
            const filesInConfig = await listDirectory(configDir, { recursive: false });
            const configFiles = matchFiles(filesInConfig, defaultConfigFiles);
            return configFiles.at(0);
        })))
        .filter((file) => file)
        .at(0);
    if (foundConfigFile) {
        return foundConfigFile;
    }

    return undefined;
}

/**
 * Determine config arguments to use for any linter
 * @returns array of CLI arguments to use when calling the linter as subprocess
 */
export async function getConfigArgs(options: {
    linter: keyof typeof configFiles,
    configMode?: 'file' | 'directory' | undefined,
    linterType?: 'generic' | 'python' | undefined,
    configArgName: string,
}): Promise<string[]> {
    let configFile = await findConfigFile({
        linter: options.linter,
        linterType: options.linterType,
    });

    if (!configFile) {
        return [];
    }

    if (options.configMode === 'directory') {
        configFile = path.dirname(configFile);
    }

    return options.configArgName.endsWith('=') ?
        [`${options.configArgName}${configFile}`] :
        [options.configArgName, configFile];
}
