import fs from 'fs/promises';
import fsSync from 'fs';
import path from "path";
import { execa as baseExeca, ExecaError, Options as ExecaOptions, ExecaReturnValue } from "@esm2cjs/execa";
import { logAlways, logExtraVerbose, logNormal, logVerbose } from "./log";
import { hashFile, isProjectGitRepo, wildcard2regex } from "./utils";

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
    configDir: string;

    constructor(readonly mode: 'lint' | 'fmt', readonly files: string[], configDir?: string | undefined) {
        this.configDir = configDir ?? '.';
    }

    async runLinter(
        options: {
            linterName: string,
            fileMatch: string | string[] | ((file: string) => boolean), // TODO: Remove closure maybe?
            preCommand?: (() => (boolean | Promise<boolean>)) | undefined,
            lintCommand: (file: string, toolName: string) => Promise<void>,
            fmtCommand?: (file: string, toolName: string) => Promise<void>,
            envName: string,
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

        if (options.preCommand) {
            let returnValue = options.preCommand();
            if (typeof returnValue !== 'boolean') {
                returnValue = await returnValue;
            }

            if (returnValue === false) {
                return;
            }
        }

        await Promise.all(files.map(async (file) => {
            if (this.mode === 'lint') {
                await options.lintCommand(file, options.linterName);
            } else if (this.mode === 'fmt' && options.fmtCommand) {
                await options.fmtCommand(file, options.linterName);
            }
        }));
    }

    async run(): Promise<boolean> {
        const jsonFileMatch = '*.{json,json5,jsonl,geojson,babelrc,ecrc,htmlhintrc,htmllintrc,jscsrc,jshintrc,jslintrc,remarkrc}'
        const yamlFileMatch = '*.{yml,yaml}';

        // Gitignore
        await this.runLinter({
            linterName: 'git-check-ignore',
            envName: 'GITIGNORE',
            fileMatch: '*',
            preCommand: async () => isProjectGitRepo(),
            lintCommand: async (file: string, toolName: string) => {
                const cmd = await execa(['git', 'check-ignore', '--no-index', file]);
                if (cmd.exitCode !== 0) { // Success
                    logLintSuccess(toolName, file, cmd);
                } else { // Fail
                    this.foundProblems += 1;
                    logLintFail(toolName, file, cmd);
                }
            },
            fmtCommand: async (file: string, toolName: string) => {
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
            lintCommand: async (file: string, toolName: string) => {
                const cmd = await execa(['ec', file]);
                if (cmd.exitCode === 0) {
                    logLintSuccess(toolName, file, cmd);
                } else {
                    this.foundProblems += 1;
                    logLintFail(toolName, file, cmd);
                }
            },
        });

        // Jsonlint
        await this.runLinter({
            linterName: 'jsonlint',
            envName: 'JSONLINT',
            fileMatch: jsonFileMatch,
            lintCommand: async (file: string, toolName: string) => {
                const cmd = await execa(['jsonlint', '--quiet', '--comments', '--no-duplicate-keys', file]);
                if (cmd.exitCode === 0) {
                    logLintSuccess(toolName, file, cmd);
                } else {
                    this.foundProblems += 1;
                    logLintFail(toolName, file, cmd);
                }
            },
        });

        // Yamllint
        const yamllintConfigArgs = configArgs('YAMLLINT',
            ['yamllint.yml', 'yamllint.yaml', '.yamllint.yml', '.yamllint.yaml'],
            '--config-file');
        await this.runLinter({
            linterName: 'yamllint',
            envName: 'YAMLLINT',
            fileMatch: yamlFileMatch,
            lintCommand: async (file: string, toolName: string) => {
                const cmd = await execa(['yamllint', '--strict', ...yamllintConfigArgs, file]);
                if (cmd.exitCode === 0) {
                    logLintSuccess(toolName, file, cmd);
                } else {
                    this.foundProblems += 1;
                    logLintFail(toolName, file, cmd);
                }
            },
        });

        // Prettier
        await this.runLinter({
            linterName: 'prettier',
            envName: 'PRETTIER',
            fileMatch: [jsonFileMatch, yamlFileMatch, '*.{html,vue,css,scss,sass,less}'],
            lintCommand: async (file: string, toolName: string) => {
                const cmd = await execa(['prettier', '--list-different', file]);
                if (cmd.exitCode === 0) {
                    logLintSuccess(toolName, file, cmd);
                } else {
                    this.foundProblems += 1;
                    logLintFail(toolName, file, cmd);
                }
            },
            fmtCommand: async (file: string, toolName: string) => {
                const originalHash = await hashFile(file);
                const cmd = await execa(['prettier', '--write', file]);
                const updatedHash = await hashFile(file);
                if (cmd.exitCode === 0) {
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
            },
        });

        // Package.json validator
        await this.runLinter({
            linterName: 'package-json-validator',
            envName: 'PACKAGE_JSON',
            fileMatch: 'package.json',
            lintCommand: async (file: string, toolName: string) => {
                const packageJson = JSON.parse(await fs.readFile(file, 'utf8'));
                if (packageJson['private'] === true) {
                    logExtraVerbose(`⏩ Skipping ${toolName} - ${file}, because it's private`);
                    return;
                }

                const cmd = await execa(['pjv', '--warnings', '--recommendations', '--filename', file]);
                if (cmd.exitCode === 0) { // Success
                    logLintSuccess(toolName, file);
                } else { // Fail
                    this.foundProblems += 1;
                    logLintFail(toolName, file, cmd);
                }
            },
        });

        // TomlJson
        await this.runLinter({
            linterName: 'tomljson',
            envName: 'TOMLJSON',
            fileMatch: '*.toml',
            lintCommand: async (file: string, toolName: string) => {
                const cmd = await execa(['tomljson', file]);
                if (cmd.exitCode === 0) { // Success
                    logLintSuccess(toolName, file);
                } else { // Fail
                    this.foundProblems += 1;
                    logLintFail(toolName, file, cmd);
                }
            },
        });

        // Dotenv
        await this.runLinter({
            linterName: 'dotenv-linter',
            envName: 'DOTENV',
            fileMatch: '*.env',
            lintCommand: async (file: string, toolName: string) => {
                const cmd = await execa(['dotenv-linter', file]); // TODO: maybe add --quiet
                if (cmd.exitCode === 0) { // Success
                    logLintSuccess(toolName, file);
                } else { // Fail
                    this.foundProblems += 1;
                    logLintFail(toolName, file, cmd);
                }
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
