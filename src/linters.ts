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

    async runLinter(
        options: {
            linterName: string,
            envName: string,
            fileMatch: string | string[] | ((file: string) => boolean), // TODO: Remove closure maybe?
            beforeAllFiles?: (toolName: string) => (boolean | Promise<boolean>),
            beforeFile?: (file: string, toolName: string) => (boolean | Promise<boolean>),
            lintFile: { args: string[], options?: ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | ExecaOptions | undefined, successExitCode?: number | undefined } | ((file: string, toolName: string) => Promise<void>),
            fmtFile?: { args: string[], options?: ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | ExecaOptions | undefined, successExitCode?: number | undefined } | ((file: string, toolName: string) => Promise<void>),
        }
    ): Promise<void> {
        const files = (() => {
            const fileMatch = options.fileMatch;
            if (typeof fileMatch === 'string') {
                const regex = wildcard2regex(fileMatch);
                return this.files.filter((file) => regex.test(file));
            }

            if (Array.isArray(fileMatch)) {
                const regexes = fileMatch.map((wildcard) => wildcard2regex(wildcard));
                return this.files.filter((file) => regexes.some((regex) => regex.test(file)));
            }

            return this.files.filter((file) => fileMatch(file));
        })();

        const envEnable = 'VALIDATE_' + options.envName;
        if (process.env[envEnable] && process.env[envEnable] === 'false') {
            logExtraVerbose(`Skipped ${options.linterName} - ${envEnable} is false`);
            return;
        }

        if (options.beforeAllFiles) {
            let returnValue = options.beforeAllFiles(options.linterName);
            if (typeof returnValue !== 'boolean') {
                returnValue = await returnValue;
            }

            if (returnValue === false) {
                return;
            }
        }

        await Promise.all(files.map(async (file) => {
            if (options.beforeFile) {
                let returnValue = options.beforeFile(file, options.linterName);
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
                        const args = execaConfig.args.map((el) => el.replace('#file#', file));
                        const options: ExecaOptions = await (async () => {
                            if (execaConfig.options === undefined) {
                                return {};
                            } else if (typeof execaConfig.options === 'object') {
                                return execaConfig.options;
                            } else {
                                let returnValue = execaConfig.options(file);
                                if ('then' in returnValue) {
                                    returnValue = await returnValue;
                                }
                                return returnValue;
                            }
                        })();
                        const successExitCode = execaConfig.successExitCode ?? 0;

                        const cmd = await execa(args, options);
                        if (cmd.exitCode === successExitCode) { // Success
                            logLintSuccess(toolName, file);
                        } else { // Fail
                            this.foundProblems += 1;
                            logLintFail(toolName, file, cmd);
                        }
                    };
                }
                await options.lintFile(file, options.linterName);
            } else if (this.mode === 'fmt' && options.fmtFile) {
                if (typeof options.fmtFile === 'object') {
                    const execaConfig = options.fmtFile;
                    options.fmtFile = async (file: string, toolName: string) => {
                        const args = execaConfig.args.map((el) => el.replace('#file#', file));
                        const options: ExecaOptions = await (async () => {
                            if (execaConfig.options === undefined) {
                                return {};
                            } else if (typeof execaConfig.options === 'object') {
                                return execaConfig.options;
                            } else {
                                let returnValue = execaConfig.options(file);
                                if ('then' in returnValue) {
                                    returnValue = await returnValue;
                                }
                                return returnValue;
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
                await options.fmtFile(file, options.linterName);
            }
        }));
    }

    async run(): Promise<boolean> {
        const matchers = {
            json: '*.{json,json5,jsonl,geojson,babelrc,ecrc,eslintrc,htmlhintrc,htmllintrc,jscsrc,jshintrc,jslintrc,prettierrc,remarkrc}',
            yaml: '*.{yml,yaml}',
            envfile: '{*.env,env.*,env}',
            dockerfile: '{Dockerfile,*.Dockerfile,Dockerfile.*}',
            makefile: '{Makefile,*.make}',
            gnumakefile: '{GNU,G,}{Makefile,*.make}',
            bsdmakefile: '{BSD,B,}{Makefile,*.make}',
        };

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

        // Jsonlint
        await this.runLinter({
            linterName: 'jsonlint',
            envName: 'JSONLINT',
            fileMatch: matchers.json,
            lintFile: { args: ['jsonlint', '--quiet', '--comments', '--no-duplicate-keys', '#file#'] },
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

        // Prettier
        await this.runLinter({
            linterName: 'prettier',
            envName: 'PRETTIER',
            fileMatch: [matchers.json, matchers.yaml, '*.{html,vue,css,scss,sass,less}'],
            lintFile: { args: ['prettier', '--list-different', '#file#'] },
            fmtFile: { args: ['prettier', '--write', '#file#'] },
        });

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

        // TomlJson
        await this.runLinter({
            linterName: 'tomljson',
            envName: 'TOMLJSON',
            fileMatch: '*.toml',
            lintFile: { args: ['tomljson', '#file#'] },
        });

        // Dotenv
        await this.runLinter({
            linterName: 'dotenv-linter',
            envName: 'DOTENV',
            fileMatch: matchers.envfile,
            lintFile: { args: ['dotenv-linter', '#file#'] }, // TODO: maybe add --quiet
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

        // Continuos integration

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

        // Final work
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
