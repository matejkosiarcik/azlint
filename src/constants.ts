export const configFiles = {
    // No source
    checkmake: 'checkmake.ini',

    // https://github.com/replicatedhq/dockerfilelint#configuring
    dockerfilelint: '.dockerfilelintrc',

    // https://github.com/hadolint/hadolint#configure
    hadolint: ['hadolint.yaml', '.hadolint.yaml'],

    // https://htmlhint.com/docs/user-guide/configuration
    htmlhint: '.htmlhintrc',

    // No source
    htmllint: '.htmllintrc',

    // https://github.com/kucherenko/jscpd/tree/master/packages/jscpd#config-file
    jscpd: '.jscpd.json',

    // https://github.com/prantlf/jsonlint#configuration
    jsonlint: ['.jsonlintrc', '.jsonlintrc.{cjs,js,json,yaml,yml}', 'jsonlint.config.{cjs,js}'],

    // No source
    markdownLinkCheck: '.markdown-link-check.json',

    // https://github.com/igorshubovych/markdownlint-cli#configuration
    markdownlint: ['.markdownlintrc', '.markdownlint.{json,jsonc,yaml,yml}'],

    // https://github.com/markdownlint/markdownlint/blob/main/docs/configuration.md#mdl-configuration
    mdl: '.mdlrc',

    // https://prettier.io/docs/en/configuration.html
    prettier: ['.prettierrc', '.prettierrc.{js,cjs,mjs,json,json5,toml,yaml,yml}', 'prettier.config.{cjs,js,mjs}'],

    // https://github.com/amperser/proselint#checks
    proselint: '.proselintrc',

    // https://github.com/secretlint/secretlint#configuration
    secretlint: '.secretlintrc.{js,json,yml}',

    // https://github.com/birjj/svglint#config
    svglint: '.svglintrc.js',

    // https://textlint.github.io/docs/configuring.html#configuration-files
    textlint: ['.textlintrc', '.textlintrc.{js,json,yaml,yml}'],

    // https://yamllint.readthedocs.io/en/stable/configuration.html
    yamllint: ['.yamllint', '.yamllint.{yaml,yml}'],
};
