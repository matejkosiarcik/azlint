import fs from 'fs/promises';
import fsSync from 'fs';
import path from "path";
import { execa as baseExeca, ExecaError, Options as ExecaOptions, ExecaReturnValue } from "@esm2cjs/execa";
import { logAlways, logExtraVerbose, logNormal, logVerbose } from "./log";
import { ColorOptions, hashFile, isProjectGitRepo, wildcard2regex } from "./utils";

function logLintSuccess(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logVerbose(`✅ ${color}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

function logLintFail(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[31m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logAlways(`❌ ${color}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

function logFixingUnchanged(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logVerbose(`💯 Unchanged: ${color}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

function logFixingSuccess(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logNormal(`🛠️ Fixed: ${color}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

function logFixingError(toolName: string, file: string, command: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logAlways(`❗️ Error fixing: ${color}${toolName} - ${file}${endColor}`);
    const cmdOutput = command.all ? `:\n${command.all}` : '';
    logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`)
}

function shouldSkipLinter(envName: string, linterName: string): boolean {
    const envEnable = 'VALIDATE_' + envName;
    if (process.env[envEnable] && process.env[envEnable] === 'false') {
        logExtraVerbose(`Skipped ${linterName} - ${envEnable} is false`);
        return true;
    }

    return false;
}

/**
 * Custom `execa` wrapper with default options
 */
async function execa(command: string[], _options?: ExecaOptions<string>): Promise<ExecaReturnValue<string>> {
    const options: ExecaOptions = {
        timeout: 60_000,
        stdio: 'pipe',
        all: true,
        ..._options ?? {},
    };

    try {
        const cmd = await baseExeca(command[0], command.slice(1), options);
        return cmd;
    } catch (error) {
        const cmdError = error as ExecaError;
        return cmdError;
    }
}

/**
 * Determine config file to use for linter `X`
 * - if `X_CONFIG_FILE` is specified, returns `LINTER_RULES_PATH/X_CONFIG_FILE`
 * - else searches `LINTER_RULES_PATH` for config files and returns first found
 * @returns array of arguments to use in subprocess call
 */
function configArgs(envName: string, possibleFiles: string[], configArgName: string): string[] {
    const configDir = process.env['LINTER_RULES_PATH'] ?? '.';
    const configFile = (() => {
        const envValue = process.env[envName + '_CONFIG_FILE'];
        if (envValue) {
            return path.join(configDir, envValue);
        }

        const potentialConfigs = possibleFiles
            .map((file) => path.join(configDir, file))
            .filter((file) => fsSync.existsSync(file));
        if (potentialConfigs.length === 0) {
            return undefined;
        }
        return potentialConfigs[0];
    })();

    return configFile ? [configArgName, configFile] : [];
}

export class Linters {
    foundProblems = 0;
    fixedProblems = 0;

    constructor(readonly mode: 'lint' | 'fmt', readonly files: string[], readonly color: ColorOptions) {}

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
                                .replace('#file-basename#', path.basename(file))
                                .replace('#file-dirname#', path.dirname(file))
                                .replace('#file-absolute#', path.resolve(file))
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

                    const cmd = await execa(args, options);
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
                                .replace('#file-basename#', path.basename(file))
                                .replace('#file-dirname#', path.dirname(file))
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
                    const cmd = await execa(args, options);
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
        };

        /* Generic linters for all files */

        // Gitignore
        await this.runLinter({
            linterName: 'git-check-ignore',
            envName: 'GITIGNORE',
            fileMatch: '*',
            beforeAllFiles: async (toolName: string) => {
                const isGit = await isProjectGitRepo();
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
                const cmd = await execa(['git', 'check-ignore', '--no-index', file]);
                if (cmd.exitCode !== 0) { // Success
                    logLintSuccess(toolName, file, cmd);
                } else { // Fail
                    this.foundProblems += 1;
                    const cmd2 = await execa(['git', 'rm', '--cached', file]);
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
        const prettierConfigArgs = configArgs('PRETTIER',
            ['prettierrc', 'prettierrc.yml', 'prettierrc.yaml', 'prettierrc.json', 'prettierrc.js', '.prettierrc', '.prettierrc.yml', '.prettierrc.yaml', '.prettierrc.json', '.prettierrc.js'],
            '--config');
        await this.runLinter({
            linterName: 'prettier',
            envName: 'PRETTIER',
            fileMatch: [matchers.json, matchers.yaml, '*.{html,vue,css,scss,sass,less}'],
            lintFile: { args: ['prettier', ...prettierConfigArgs, '--list-different', '#file#'] },
            fmtFile: { args: ['prettier', ...prettierConfigArgs, '--write', '#file#'] },
        });

        // Jsonlint
        const jsonlintConfigArgs = configArgs('JSONLINT',
            [], // TODO: Finish
            '--config');
        await this.runLinter({
            linterName: 'jsonlint',
            envName: 'JSONLINT',
            fileMatch: matchers.json,
            lintFile: { args: ['jsonlint', ...jsonlintConfigArgs, '--quiet', '--comments', '--no-duplicate-keys', '#file#'] },
        });

        // Yamllint
        const yamllintConfigArgs = configArgs('YAMLLINT',
            ['yamllint.yml', 'yamllint.yaml', '.yamllint.yml', '.yamllint.yaml'],
            '--config-file');
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
        const htmllintConfigArgs = configArgs('HTMLLINT',
            ['.htmllintrc'],
            '--rc');
        await this.runLinter({
            linterName: 'htmllint',
            envName: 'HTMLLINT',
            fileMatch: matchers.html,
            lintFile: { args: ['htmllint', ...htmllintConfigArgs, '#file#'] },
        });

        // HtmlHint
        const htmlhintConfigArgs = configArgs('HTMLHINT',
            ['.htmlhintrc'],
            '--config');
        await this.runLinter({
            linterName: 'htmlhint',
            envName: 'HTMLHINT',
            fileMatch: matchers.html,
            lintFile: { args: ['htmlhint', ...htmlhintConfigArgs, '#file#'] },
        });

        // Svglint
        const svglintConfigArgs = configArgs('SVGLINT',
            ['.svglintrc.js', 'svglintrc.js'],
            '--config');
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
        const markdownlintConfigArgs = configArgs('MDL',
            ['markdownlint.json', '.markdownlint.json'],
            '--config');
        await this.runLinter({
            linterName: 'markdownlint',
            envName: 'MARKDOWNLINT',
            fileMatch: matchers.markdown,
            lintFile: { args: ['markdownlint', ...markdownlintConfigArgs, '#file#'] },
            fmtFile: { args: ['markdownlint', ...markdownlintConfigArgs, '--fix', '#file#'] },
        });

        // mdl
        const mdlConfigArgs = configArgs('MDL',
            ['.mdlrc'],
            '--config');
        await this.runLinter({
            linterName: 'mdl',
            envName: 'MDL',
            fileMatch: matchers.markdown,
            lintFile: { args: ['bundle', 'exec', 'mdl', ...mdlConfigArgs, '#file#'] },
        });

        // Markdown link check
        const markdownLinkCheckConfigArgs = configArgs('MDL',
            ['markdown-link-check.json', '.markdown-link-check.json'],
            '--config');
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
                args: ['composer', 'normalize', '--no-interaction', '--no-cache', '--ansi', '--dry-run', '--diff', '#file-basename#'],
                options: (file) => {
                    return {
                        cwd: path.dirname(file),
                    }
                },
            },
            fmtFile: {
                args: ['composer', 'normalize', '--no-interaction', '--no-cache', '--ansi', '#file-basename#'],
                options: (file) => {
                    return {
                        cwd: path.dirname(file),
                    }
                },
            }
        });

        /* Docker */

        const dockerfilelintConfigArgs = configArgs('DOCKERFILELINT',
            ['.dockerfilelintrc'],
            '--config');
        await this.runLinter({
            linterName: 'dockerfilelint',
            envName: 'DOCKERFILELINT',
            fileMatch: matchers.dockerfile,
            lintFile: { args: ['dockerfilelint', ...dockerfilelintConfigArgs, '#file#'] },
        });

        const hadolintConfigArgs = configArgs('HADOLINT',
            ['hadolint.yml', 'hadolint.yaml', '.hadolint.yml', '.hadolint.yaml'],
            '--config');
        await this.runLinter({
            linterName: 'hadolint',
            envName: 'HADOLINT',
            fileMatch: matchers.dockerfile,
            lintFile: { args: ['hadolint', ...hadolintConfigArgs, '#file#'] },
        });

        /* Makefile */

        // Checkmake
        const checkmakeConfigArgs = configArgs('CHECKMAKE',
            ['checkmake.ini', '.checkmake.ini'],
            '--config');
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
