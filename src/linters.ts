import fs from 'fs/promises';
import fsSync from 'fs';
import path from "path";
import { Options as ExecaOptions } from "@esm2cjs/execa";
import { logExtraVerbose, logNormal, logVerbose, logFixingError, logFixingSuccess, logFixingUnchanged, logLintFail, logLintSuccess } from "./log";
import { ColorOptions, customExeca, hashFile, isCwdGitRepo, ProgressOptions, wildcard2regex } from "./utils";

function shouldSkipLinter(envName: string, linterName: string): boolean {
    const envEnable = 'VALIDATE_' + envName;
    if (process.env[envEnable] && process.env[envEnable] === 'false') {
        logExtraVerbose(`Skipped ${linterName} - ${envEnable} is false`);
        return true;
    }

    return false;
}

/**
 * Determine config file to use for linter `X`
 * - if `X_CONFIG_FILE` is specified, returns `LINTER_RULES_PATH/X_CONFIG_FILE`
 * - else searches `LINTER_RULES_PATH` for config files and returns first found
 * @returns array of arguments to use in subprocess call
 */
function getConfigArgs(envName: string, configArgName: string, possibleFiles: string[]): string[] {
    const configDir = process.env['LINTER_RULES_PATH'] ?? '.';
    const configFile = (() => {
        const envValue = process.env[envName + '_CONFIG_FILE'];
        if (envValue) {
            if (fsSync.existsSync(envValue)) {
                return envValue;
            } else if (fsSync.existsSync(path.join(configDir, envValue))) {
                return path.join(configDir, envValue);
            }
        }

        const potentialConfigs = possibleFiles
            .map((file) => path.join(configDir, file))
            .filter((file) => fsSync.existsSync(file));
        if (potentialConfigs.length === 0) {
            return;
        }
        return potentialConfigs[0];
    })();

    return configFile ? (configArgName.endsWith('=') ? [`${configArgName}${configFile}`] : [configArgName, configFile]) : [];
}

/**
 * Determine config file to use for linter `X` - Python oriented
 * Python needs specific logic, because Python tools are a little different
 * Some have dedicated config files, but they are also configurable by shared config files, eg. setup.cfg or pyproject.toml
 */
function getPythonConfigArgs(envName: string, linterName: string, configArgName: string, specificFiles: string[], commonFiles: string[]): string[] {
    const specificConfigArgs = getConfigArgs(envName, configArgName, specificFiles);
    if (specificConfigArgs.length > 0) {
        return specificConfigArgs;
    }

    const configDir = process.env['LINTER_RULES_PATH'] ?? '.';
    const configFile = (() => {
        const commonConfigs = commonFiles
            .map((file) => path.join(configDir, file))
            .filter((file) => fsSync.existsSync(file))
            .filter((file) => {
                const configContent = fsSync.readFileSync(file, 'utf8');
                return configContent.split('\n')
                    .some((line) => line.includes(`[${linterName}]`) ||
                        line.includes(`[tool.${linterName}]`) ||
                        line.includes(`[tool.${linterName}.`)
                    );
            });
        if (commonConfigs.length > 0) {
            return commonConfigs[0];
        }

        return;
    })();

    return configFile ? (configArgName.endsWith('=') ? [`${configArgName}${configFile}`] : [configArgName, configFile]) : [];
}

export class Linters {
    foundProblems = 0;
    fixedProblems = 0;
    readonly mode: 'lint' | 'fmt';
    readonly files: string[];
    readonly color: ColorOptions;
    readonly progress: ProgressOptions;

    constructor(options: {
        mode: 'lint' | 'fmt',
        files: string[],
        color: ColorOptions,
        progress: ProgressOptions
    }) {
        this.mode = options.mode;
        this.files = options.files;
        this.color = options.color;
        this.progress = options.progress;
    }

    matchFiles(fileMatch: string | string[] | ((file: string) => boolean)): string[] {
        if (typeof fileMatch === 'string') {
            const regex = wildcard2regex(fileMatch);
            return this.files.filter((file) => regex.test(file));
        }

        if (Array.isArray(fileMatch)) {
            const regexes = fileMatch.map((wildcard) => wildcard2regex(wildcard));
            return this.files.filter((file) => regexes.some((regex) => regex.test(file)));
        }

        return this.files.filter((file) => fileMatch(file));
    }

    async runLinter(
        options: {
            fileMatch: string | string[] | ((file: string) => boolean),
            linterName: string,
            envName: string,
            beforeAllFiles?: (toolName: string) => (boolean | Promise<boolean>),
            beforeFile?: ((file: string, toolName: string) => (boolean | Promise<boolean>)) | undefined,
            lintFile: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | undefined,
            } | ((file: string, toolName: string) => Promise<void>),
            fmtFile?: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | undefined,
            } | ((file: string, toolName: string) => Promise<void>),
        }
    ): Promise<void> {
        const files = this.matchFiles(options.fileMatch);
        if (shouldSkipLinter(options.envName, options.linterName)) {
            return;
        }

        if (options.beforeAllFiles) {
            let returnValue = options.beforeAllFiles(options.linterName);
            if (typeof returnValue !== 'boolean') {
                returnValue = await returnValue;
            }

            if (!returnValue) {
                return;
            }
        }

        await Promise.all(files.map(async (file) => {
            await this.runLinterFile({
                file: file,
                ...options,
            });
        }));
    }

    async runLinters(
        commonOptions: {
            fileMatch: string | string[] | ((file: string) => boolean),
        },
        individualOptions: {
            linterName: string,
            envName: string,
            beforeAllFiles?: (toolName: string) => (boolean | Promise<boolean>),
            beforeFile?: ((file: string, toolName: string) => (boolean | Promise<boolean>)) | undefined,
            lintFile: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | undefined,
            } | ((file: string, toolName: string) => Promise<void>),
            fmtFile?: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | undefined,
            } | ((file: string, toolName: string) => Promise<void>),
        }[]
    ): Promise<void> {
        const files = this.matchFiles(commonOptions.fileMatch);

        const acceptedIndividualOptions = (await Promise.all(individualOptions.map(async (options) => {
            if (shouldSkipLinter(options.envName, options.linterName)) {
                return {
                    pass: false,
                    options: options
                };
            }

            if (options.beforeAllFiles) {
                let returnValue = options.beforeAllFiles(options.linterName);
                if (typeof returnValue !== 'boolean') {
                    returnValue = await returnValue;
                }

                if (!returnValue) {
                    return {
                        pass: false,
                        options: options
                    };
                }
            }

            return {
                pass: true,
                options: options
            };
        }))).filter((options) => options.pass).map((options) => options.options);

        await Promise.all(files.map(async (file) => {
            for (const options of acceptedIndividualOptions) {
                await this.runLinterFile({
                    file: file,
                    ...options,
                });
            }
        }));
    }

    async runLinterFile(
        options: {
            linterName: string,
            envName: string,
            file: string,
            beforeFile?: ((file: string, toolName: string) => (boolean | Promise<boolean>)) | undefined,
            lintFile: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | undefined,
            } | ((file: string, toolName: string) => Promise<void>),
            fmtFile?: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | undefined,
            } | ((file: string, toolName: string) => Promise<void>),
        }
    ): Promise<void> {
        if (options.beforeFile) {
            let returnValue = options.beforeFile(options.file, options.linterName);
            if (typeof returnValue !== 'boolean') {
                returnValue = await returnValue;
            }

            if (!returnValue) {
                return;
            }
        }

        if (this.mode === 'lint') {
            if (typeof options.lintFile === 'object') {
                const execaConfig = options.lintFile;
                options.lintFile = async (file: string, toolName: string) => {
                    const args: string[] = await (async () => {
                        if (Array.isArray(execaConfig.args)) {
                            return execaConfig.args.map((el) => el
                                .replace('#file#', file)
                                .replace('#filename#', path.basename(file))
                                .replace('#directory#', path.dirname(file))
                                .replace('#file[abs]#', path.resolve(file))
                                .replace('#directory[abs]#', path.resolve(path.dirname(file)))
                            );
                        }
                        let args = execaConfig.args(file);
                        return 'then' in args ? await args : args;
                    })();
                    const options: ExecaOptions = await (async () => {
                        if (execaConfig.options === undefined) {
                            return {};
                        } else if (typeof execaConfig.options === 'object') {
                            return execaConfig.options;
                        } else {
                            let options = execaConfig.options(file);
                            return 'then' in options ? await options : options;
                        }
                    })();
                    const successExitCode = execaConfig.successExitCode ?? 0;

                    const cmd = await customExeca(args, options);
                    if (cmd.exitCode === successExitCode) { // Success
                        logLintSuccess(toolName, file, cmd);
                    } else { // Fail
                        this.foundProblems += 1;
                        logLintFail(toolName, file, cmd);
                    }
                };
            }
            await options.lintFile(options.file, options.linterName);
        } else if (this.mode === 'fmt' && options.fmtFile) {
            if (typeof options.fmtFile === 'object') {
                const execaConfig = options.fmtFile;
                options.fmtFile = async (file: string, toolName: string) => {
                    const args: string[] = await (async () => {
                        if (Array.isArray(execaConfig.args)) {
                            return execaConfig.args.map((el) => el
                            .replace('#file#', file)
                            .replace('#filename#', path.basename(file))
                            .replace('#directory#', path.dirname(file))
                            .replace('#file[abs]#', path.resolve(file))
                            .replace('#directory[abs]#', path.resolve(path.dirname(file)))
                            );
                        }
                        let args = execaConfig.args(file);
                        return 'then' in args ? await args : args;
                    })();
                    const options: ExecaOptions = await (async () => {
                        if (execaConfig.options === undefined) {
                            return {};
                        } else if (typeof execaConfig.options === 'object') {
                            return execaConfig.options;
                        } else {
                            let options = execaConfig.options(file);
                            return 'then' in options ? await options : options;
                        }
                    })();
                    const successExitCode = execaConfig.successExitCode ?? 0;

                    const originalHash = await hashFile(file);
                    const cmd = await customExeca(args, options);
                    const updatedHash = await hashFile(file);
                    if (cmd.exitCode === successExitCode) {
                        if (originalHash !== updatedHash) {
                            this.foundProblems += 1;
                            this.fixedProblems += 1;
                            logFixingSuccess(toolName, file, cmd);
                        } else {
                            logFixingUnchanged(toolName, file, cmd);
                        }
                    } else {
                        logFixingError(toolName, file, cmd);
                    }
                };
            }
            await options.fmtFile(options.file, options.linterName);
        }
    }

    async run(): Promise<boolean> {
        const matchers = {
            json: '*.{json,json5,jsonl,geojson,babelrc,ecrc,eslintrc,htmlhintrc,htmllintrc,jscsrc,jshintrc,jslintrc,prettierrc,remarkrc}',
            yaml: '*.{yml,yaml}',
            envfile: '{*.env,env.*,env}',
            dockerfile: '{Dockerfile,*.Dockerfile,Dockerfile.*}',
            markdown: '*.{md,mdown,markdown}',
            makefile: '{Makefile,*.make}',
            gnumakefile: '{GNU,G,}{Makefile,*.make}',
            bsdmakefile: '{BSD,B,}{Makefile,*.make}',
            html: '*.{html,htm,html5,xhtml}',
            shell: '*.{sh,bash,ksh,ksh93,mksh,loksh,ash,dash,zsh,yash}',
            python: '*.{py,py3,python,python3}',
        };

        /* Generic linters for all files */

        // Gitignore
        await this.runLinter({
            linterName: 'git-check-ignore',
            envName: 'GITIGNORE',
            fileMatch: '*',
            beforeAllFiles: async (toolName: string) => {
                const isGit = await isCwdGitRepo();
                if (!isGit) {
                    logVerbose(`⏩ Skipping ${toolName}, because it's private`);
                }
                return isGit;
            },
            lintFile: {
                args: ['git', 'check-ignore', '--no-index', '#file#'],
                successExitCode: 1,
            },
            fmtFile: async (file: string, toolName: string) => {
                const cmd = await customExeca(['git', 'check-ignore', '--no-index', file]);
                if (cmd.exitCode !== 0) { // Success
                    logLintSuccess(toolName, file, cmd);
                } else { // Fail
                    this.foundProblems += 1;
                    const cmd2 = await customExeca(['git', 'rm', '--cached', file]);
                    if (cmd2.exitCode === 0) {
                        logFixingSuccess(toolName, file);
                        this.fixedProblems += 1;
                    } else {
                        logFixingError(toolName, file, cmd2);
                    }
                }
            },
        });

        // Editorconfig-checker
        await this.runLinter({
            linterName: 'editorconfig-checker',
            envName: 'EDITORCONFIG',
            fileMatch: '*',
            lintFile: { args: ['ec', '#file#'] },
        });

        /* HTML, JSON, SVG, TOML, XML, YAML */

        // Prettier
        const prettierConfigArgs = getConfigArgs('PRETTIER', '--config',
            ['prettierrc', 'prettierrc.yml', 'prettierrc.yaml', 'prettierrc.json', 'prettierrc.js', '.prettierrc', '.prettierrc.yml', '.prettierrc.yaml', '.prettierrc.json', '.prettierrc.js']);
        await this.runLinter({
            linterName: 'prettier',
            envName: 'PRETTIER',
            fileMatch: [matchers.json, matchers.yaml, '*.{html,vue,css,scss,sass,less}'],
            lintFile: { args: ['prettier', ...prettierConfigArgs, '--list-different', '#file#'] },
            fmtFile: { args: ['prettier', ...prettierConfigArgs, '--write', '#file#'] },
        });

        // Jsonlint
        const jsonlintConfigArgs = getConfigArgs('JSONLINT', '--config', []); // TODO: Finish config files
        await this.runLinter({
            linterName: 'jsonlint',
            envName: 'JSONLINT',
            fileMatch: matchers.json,
            lintFile: { args: ['jsonlint', ...jsonlintConfigArgs, '--quiet', '--comments', '--no-duplicate-keys', '#file#'] },
        });

        // Yamllint
        const yamllintConfigArgs = getConfigArgs('YAMLLINT', '--config-file',
            ['yamllint.yml', 'yamllint.yaml', '.yamllint.yml', '.yamllint.yaml']);
        await this.runLinter({
            linterName: 'yamllint',
            envName: 'YAMLLINT',
            fileMatch: matchers.yaml,
            lintFile: { args: ['yamllint', '--strict', ...yamllintConfigArgs, '#file#'] },
        });

        // TomlJson
        await this.runLinter({
            linterName: 'tomljson',
            envName: 'TOMLJSON',
            fileMatch: '*.toml',
            lintFile: { args: ['tomljson', '#file#'] },
        });

        // XmlLint
        await this.runLinter({
            linterName: 'xmllint',
            envName: 'XMLLINT',
            fileMatch: '*.xml',
            lintFile: { args: ['xmllint', '--noout', '#file#'] },
            fmtFile: { args: ['xmllint', '--format', '--output', '#file#', '#file#'] }
        });

        // HtmlLint
        const htmllintConfigArgs = getConfigArgs('HTMLLINT', '--rc', ['.htmllintrc']);
        await this.runLinter({
            linterName: 'htmllint',
            envName: 'HTMLLINT',
            fileMatch: matchers.html,
            lintFile: { args: ['htmllint', ...htmllintConfigArgs, '#file#'] },
        });

        // HtmlHint
        const htmlhintConfigArgs = getConfigArgs('HTMLHINT', '--config', ['.htmlhintrc']);
        await this.runLinter({
            linterName: 'htmlhint',
            envName: 'HTMLHINT',
            fileMatch: matchers.html,
            lintFile: { args: ['htmlhint', ...htmlhintConfigArgs, '#file#'] },
        });

        // Svglint
        const svglintConfigArgs = getConfigArgs('SVGLINT', '--config', ['.svglintrc.js', 'svglintrc.js']);
        await this.runLinter({
            linterName: 'svglint',
            envName: 'SVGLINT',
            fileMatch: '*.svg',
            lintFile: { args: ['svglint', '--ci', ...svglintConfigArgs, '#file#'] },
        });

        // Dotenv
        await this.runLinter({
            linterName: 'dotenv-linter',
            envName: 'DOTENV',
            fileMatch: matchers.envfile,
            lintFile: { args: ['dotenv-linter', '--quiet', '#file#'] },
        });

        /* Documentation (Markdown) */

        // Markdownlint
        const markdownlintConfigArgs = getConfigArgs('MDL', '--config', ['markdownlint.json', '.markdownlint.json']);
        await this.runLinter({
            linterName: 'markdownlint',
            envName: 'MARKDOWNLINT',
            fileMatch: matchers.markdown,
            lintFile: { args: ['markdownlint', ...markdownlintConfigArgs, '#file#'] },
            fmtFile: { args: ['markdownlint', ...markdownlintConfigArgs, '--fix', '#file#'] },
        });

        // mdl
        const mdlConfigArgs = getConfigArgs('MDL', '--config', ['.mdlrc']);
        await this.runLinter({
            linterName: 'mdl',
            envName: 'MDL',
            fileMatch: matchers.markdown,
            lintFile: { args: ['bundle', 'exec', 'mdl', ...mdlConfigArgs, '#file#'] },
        });

        // Markdown link check
        const markdownLinkCheckConfigArgs = getConfigArgs('MARKDOWN_LINK_CHECK', '--config', ['markdown-link-check.json', '.markdown-link-check.json']);
        await this.runLinter({
            linterName: 'markdown-link-check',
            envName: 'MARKDOWN_LINK_CHECK',
            fileMatch: matchers.markdown,
            lintFile: { args: ['markdown-link-check', '--quiet', ...markdownLinkCheckConfigArgs, '--retry', "#file#"] },
        });

        /* Shell */

        // Shfmt
        await this.runLinter({
            linterName: 'shfmt',
            envName: 'SHFMT',
            fileMatch: matchers.shell,
            lintFile: { args: ['shfmt', '-l', '-d', '#file#'] },
            fmtFile: { args: ['shfmt', '-w', '#file#'] }
        });

        // Shellharden
        await this.runLinter({
            linterName: 'shellharden',
            envName: 'SHELLHARDEN',
            fileMatch: matchers.shell,
            lintFile: { args: ['shellharden', '--check', '--suggest', '--', '#file#'] },
            fmtFile: { args: ['shellharden', '--replace', '--', '#file#'] }
        });

        // Bashate
        await this.runLinter({
            linterName: 'bashate',
            envName: 'BASHATE',
            fileMatch: matchers.shell,
            lintFile: { args: ['bashate', '--ignore', 'E001,E002,E003,E004,E005,E006', "#file#"] },
        });

        // Shellcheck
        await this.runLinter({
            linterName: 'shellcheck',
            envName: 'SHELLCHECK',
            fileMatch: [matchers.shell, '*.bats'],
            lintFile: { args: ['shellcheck', '--external-sources', "#file#"] },
        });

        // Bats
        await this.runLinter({
            linterName: 'bats',
            envName: 'BATS',
            fileMatch: '*.bats',
            lintFile: { args: ['bats', '--count', "#file#"] },
        });

        // Shell-dry
        await this.runLinter({
            linterName: 'shell-dry',
            envName: 'SHELL_DRY',
            fileMatch: matchers.shell,
            lintFile: { args: ['sh', path.join(__dirname, 'shell-dry.sh'), "#file#"] },
        });

        /* Python */

        // Autopep8
        // await this.runLinter({
        //     linterName: 'autopep8',
        //     envName: 'AUTOPEP8',
        //     fileMatch: matchers.python,
        //     lintFile: { args: ['autopep8', '--diff', "#file#"], },
        //     fmtFile: { args: ['autopep8', '--in-place', "#file#"], },
        // });

        // isort
        const isortConfigArgs = getPythonConfigArgs('ISORT', 'isort', '--settings-file', ['isort.cfg', '.isort.cfg'], ['pyproject.toml', 'setup.cfg', 'tox.ini']);
        await this.runLinter({
            linterName: 'isort',
            envName: 'ISORT',
            fileMatch: matchers.python,
            lintFile: { args: ['isort', ...isortConfigArgs, '--honor-noqa', '--check-only', '--diff', "#file#"] },
            fmtFile: { args: ['isort', ...isortConfigArgs, '--honor-noqa', "#file#"] },
        });

        // Black
        const blackConfigArgs = getPythonConfigArgs('BLACK', 'black', '--config', ['black', '.black'], ['pyproject.toml']);
        await this.runLinter({
            linterName: 'black',
            envName: 'BLACK',
            fileMatch: matchers.python,
            lintFile: { args: ['black', ...blackConfigArgs, '--check', '--diff', '--quiet', "#file#"] },
            fmtFile: { args: ['black', ...blackConfigArgs, '--quiet', "#file#"] },
        });

        // Pycodestyle
        const pycodestyleConfigArgs = getPythonConfigArgs('PYCODESTYLE', 'pycodestyle', '--config', ['pycodestyle', '.pycodestyle'], ['setup.cfg', 'tox.ini']);
        await this.runLinter({
            linterName: 'pycodestyle',
            envName: 'PYCODESTYLE',
            fileMatch: matchers.python,
            lintFile: { args: ['pycodestyle', ...pycodestyleConfigArgs, "#file#"] },
        });

        // Flake8
        const flake8ConfigArgs = getPythonConfigArgs('FLAKE8', 'flake8', '--config', ['flake8', '.flake8'], ['setup.cfg', 'tox.ini']);
        await this.runLinter({
            linterName: 'flake8',
            envName: 'FLAKE8',
            fileMatch: matchers.python,
            lintFile: { args: ['flake8', ...flake8ConfigArgs, "#file#"] },
        });

        // Pylint
        const pylintConfigArgs = getPythonConfigArgs('PYLINT', 'pylint', '--rcfile', ['pylintrc', '.pylintrc'], ['pyproject.toml', 'setup.cfg', 'tox.ini']);
        await this.runLinter({
            linterName: 'pylint',
            envName: 'PYLINT',
            fileMatch: matchers.python,
            lintFile: { args: ['pylint', ...pylintConfigArgs, "#file#"] },
        });

        // MyPy
        await this.runLinter({
            linterName: 'mypy',
            envName: 'MYPY',
            fileMatch: matchers.python,
            lintFile: { args: ['mypy', '--follow-imports', 'skip', "#file#"] },
        });

        /* Package manager files */

        // Package.json validator
        await this.runLinter({
            linterName: 'package-json-validator',
            envName: 'PACKAGE_JSON',
            fileMatch: 'package.json',
            beforeFile: async (file: string, toolName: string) => {
                const packageJson = JSON.parse(await fs.readFile(file, 'utf8'));
                if (packageJson['private'] === true) {
                    logExtraVerbose(`⏩ Skipping ${toolName} - ${file}, because it's private`);
                    return false;
                }
                return true;
            },
            lintFile: { args: ['pjv', '--warnings', '--recommendations', '--filename', '#file#'] },
        });

        // Composer validate
        await this.runLinter({
            linterName: 'composer-validate',
            envName: 'COMPOSER_VALIDATE',
            fileMatch: 'composer.json',
            lintFile: { args: ['composer', 'validate', '--no-interaction', '--no-cache', '--ansi', '--no-check-all', '--no-check-publish', '#file#'] },
        });

        // Composer normalize
        await this.runLinter({
            linterName: 'composer-normalize',
            envName: 'COMPOSER_NORMALIZE',
            fileMatch: 'composer.json',
            lintFile: {
                args: ['composer', 'normalize', '--no-interaction', '--no-cache', '--ansi', '--dry-run', '--diff', '#filename#'],
                options: (file) => {
                    return {
                        cwd: path.dirname(file),
                    }
                },
            },
            fmtFile: {
                args: ['composer', 'normalize', '--no-interaction', '--no-cache', '--ansi', '#filename#'],
                options: (file) => {
                    return {
                        cwd: path.dirname(file),
                    }
                },
            }
        });

        /* Docker */

        const dockerfilelintConfigArgs = getConfigArgs('DOCKERFILELINT', '--config', ['.dockerfilelintrc']);
        await this.runLinter({
            linterName: 'dockerfilelint',
            envName: 'DOCKERFILELINT',
            fileMatch: matchers.dockerfile,
            lintFile: { args: ['dockerfilelint', ...dockerfilelintConfigArgs, '#file#'] },
        });

        const hadolintConfigArgs = getConfigArgs('HADOLINT', '--config',
            ['hadolint.yml', 'hadolint.yaml', '.hadolint.yml', '.hadolint.yaml']);
        await this.runLinter({
            linterName: 'hadolint',
            envName: 'HADOLINT',
            fileMatch: matchers.dockerfile,
            lintFile: { args: ['hadolint', ...hadolintConfigArgs, '#file#'] },
        });

        /* Makefile */

        // Checkmake
        const checkmakeConfigArgs = getConfigArgs('CHECKMAKE', '--config',
            ['checkmake.ini', '.checkmake.ini']);
        await this.runLinter({
            linterName: 'checkmake',
            envName: 'CHECKMAKE',
            fileMatch: [matchers.makefile, matchers.gnumakefile, matchers.bsdmakefile],
            lintFile: { args: ['checkmake', ...checkmakeConfigArgs, '#file#'] },
        });

        // GNU Make
        await this.runLinter({
            linterName: 'gmake',
            envName: 'GMAKE',
            fileMatch: [matchers.makefile, matchers.gnumakefile],
            lintFile: { args: ['gmake', '--dry-run', '-f', '#file#'] },
        });

        // BMake
        await this.runLinter({
            linterName: 'bmake',
            envName: 'BMAKE',
            fileMatch: matchers.bsdmakefile,
            lintFile: { args: ['bmake', '-n', '-f', '#file#'] },
        });

        // BSD Make
        await this.runLinter({
            linterName: 'bmake',
            envName: 'BSDMAKE',
            fileMatch: matchers.bsdmakefile,
            lintFile: { args: ['bsdmake', '-n', '-f', '#file#'] },
        });

        /* CI/CD Services */

        // CircleCI validate
        await this.runLinter({
            linterName: 'circleci-validate',
            envName: 'CIRCLECI_VALIDATE',
            fileMatch: '.circleci/config.yml',
            lintFile: {
                args: ['circleci', '--skip-update-check', 'config', 'validate'],
                options: (file: string) => {
                    return { cwd: path.dirname(path.dirname(file)) };
                },
            },
        });

        // GitLabCI Lint
        await this.runLinter({
            linterName: 'gitlab-ci-lint',
            envName: 'GITLABCI_LINT',
            fileMatch: '.gitlab-ci.yml',
            lintFile: { args: ['gitlab-ci-lint', '#file#'] },
        });

        // GitLabCI Validate
        await this.runLinter({
            linterName: 'gitlab-ci-lint',
            envName: 'GITLABCI_VALIDATE',
            fileMatch: '.gitlab-ci.yml',
            lintFile: { args: ['gitlab-ci-validate', 'validate', '#file#'] },
        });

        // TravisLint
        await this.runLinter({
            linterName: 'travis-lint',
            envName: 'TRAVIS_LINT',
            fileMatch: '.travis.yml',
            lintFile: {
                args: ['travis', 'lint', '--no-interactive', '--skip-version-check', '--skip-completion-check', '--exit-code', '--quiet'],
                options: (file: string) => {
                    return { cwd: path.dirname(file) };
                },
            },
        });

        /* End of linters */

        // Report results
        logNormal(`Found ${this.foundProblems} problems`);
        if (this.mode === 'lint') {
            return this.foundProblems === 0;
        } else if (this.mode === 'fmt') {
            logNormal(`Fixed ${this.fixedProblems} problems`);
            return this.foundProblems === this.fixedProblems;
        }

        return true;
    }
}
