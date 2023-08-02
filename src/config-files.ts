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

export function findConfigFile(linter: keyof typeof configFiles): string {
    const envName = linter.replace(/\-/g, '_').toUpperCase();
    console.log(linter, envName);
    return ''; // TODO: Finish function
}

export function findPythonConfigFile(linter: keyof typeof pythonGeneralConfigFiles): string {
    const envName = linter.replace(/\-/g, '_').toUpperCase();
    console.log(linter, envName);
    return ''; // TODO: Finish function
}
