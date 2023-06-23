import { execa as baseExeca, ExecaError, Options as ExecaOptions, ExecaReturnBase, ExecaReturnValue } from "@esm2cjs/execa";
import { logAlways, logExtraVerbose, logNormal, logVerbose } from "./log";
import { isProjectGitRepo } from "./utils";
import path from "path";
import fs from 'fs/promises';

function logLintSuccess(toolName: string, file: string) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logVerbose(`✅ ${color}${toolName} - ${file}${endColor}`);
}

function logLintFail(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[31m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logAlways(`❌ ${color}${toolName} - ${file}${endColor}`);
    if (command) {
        logNormal(`"${command.command}" -> ${command.exitCode}:\n${command.all}`);
    }
}

function logFixingSuccess(toolName: string, file: string) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logNormal(`🛠️ ${color}${toolName} - ${file}${endColor}`);
}

function logFixingError(toolName: string, file: string, command: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    let commandMessage = `${command.exitCode}`;
    if (command.stderr) {
        commandMessage += ` ${command.stderr}`;
    }
    if (command.stdout) {
        commandMessage += ` ${command.stdout}`;
    }
    logAlways(`❗️ ${color}${toolName} - There was error fixing ${file}${endColor}: ${commandMessage}`);
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

export async function runLinters(options: { files: string[], mode: 'lint' | 'fmt', configDir?: string | undefined }): Promise<boolean> {
    let foundProblems = 0;
    let fixedProblems = 0;

    // const configDir = options.configDir ?? '.';

    // Gitignore
    await (async () => {
        const toolName = 'git-check-ignore';

        if (process.env['VALIDATE_GITIGNORE'] && process.env['VALIDATE_GITIGNORE'] === 'false') {
            logExtraVerbose(`Skipped ${toolName} - VALIDATE_GITIGNORE is false`);
            return;
        }

        if (!await isProjectGitRepo()) {
            logVerbose(`Skipped ${toolName} - project is not a git repo`);
        }

        await Promise.all(options.files.map(async (file) => {
            if (options.mode === 'lint') {
                const cmd = await execa(['git', 'check-ignore', '--no-index', file]);
                if (cmd.exitCode !== 0) { // Success
                    logLintSuccess(toolName, file);
                } else { // Fail
                    foundProblems += 1;
                    logLintFail(toolName, file, cmd);
                }
            } else {
                const cmd = await execa(['git', 'check-ignore', '--no-index', file], { stdio: 'ignore' });
                if (cmd.exitCode !== 0) { // Success
                    logLintSuccess(toolName, file);
                } else { // Fail
                    foundProblems += 1;
                    const cmd2 = await execa(['git', 'rm', '--cached', file], { stdio: 'ignore' });
                    if (cmd2.exitCode === 0) {
                        logFixingSuccess(toolName, file);
                        fixedProblems += 1;
                    } else {
                        logFixingError(toolName, file, cmd2);
                    }
                }
            }
        }));
    })();

    // Package.json validator
    await (async () => {
        const toolName = 'package-json-validator';

        if (process.env['VALIDATE_PACKAGE_JSON'] && process.env['VALIDATE_PACKAGE_JSON'] === 'false') {
            logExtraVerbose(`Skipped ${toolName} - VALIDATE_PACKAGE_JSON is false`);
            return;
        }

        if (options.mode !== 'lint') {
            return;
        }

        await Promise.all(options.files.filter((file) => path.basename(file) === 'package.json').map(async (file) => {
            const packageJson = JSON.parse(await fs.readFile(file, 'utf8'));
            if (packageJson['private'] === true) {
                logExtraVerbose(`⏩ Skipping ${toolName} - ${file}, because it's private`);
                return;
            }

            const cmd = await execa(['pjv', '--warnings', '--recommendations', '--filename', file]);
            if (cmd.exitCode === 0) { // Success
                logLintSuccess(toolName, file);
            } else { // Fail
                foundProblems += 1;
                logLintFail(toolName, file, cmd);
            }
        }));
    })();

    // Final work
    logNormal(`Found ${foundProblems} problems`);
    if (options.mode === 'lint') {
        return foundProblems === 0;
    } else if (options.mode === 'fmt') {
        logNormal(`Fixed ${fixedProblems} problems`);
        return foundProblems === fixedProblems;
    }

    return true;
}
