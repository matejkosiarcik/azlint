import { execa as baseExeca, ExecaError, Options as ExecaOptions, ExecaReturnBase } from "@esm2cjs/execa";
import { logAlways, logExtraVerbose, logNormal, logVerbose } from "./log";
import { isProjectGitRepo } from "./utils";

function logLintSuccess(toolName: string, file: string) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logVerbose(`✅ ${color}${toolName} - ${file}${endColor}`);
}

function logLintFail(toolName: string, file: string) {
    const color = process.stdout.isTTY ? '\x1b[31m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logAlways(`❌ ${color}${toolName} - ${file}${endColor}`);
}

function logFixingSuccess(toolName: string, file: string) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logNormal(`🛠️ ${color}${toolName} - ${file}${endColor}`);
}

function logFixingError(toolName: string, file: string, command: ExecaReturnBase<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logAlways(`🪓 ${color}${toolName} - There was error fixing ${file}${endColor}: ${command.exitCode} ${command.stdout} ${command.stderr}`);
}

async function execa(command: string[], _options: ExecaOptions<string>): Promise<ExecaReturnBase<string>> {
    const options = {
        ..._options,
        timeout: 30,
    };

    try {
        const cmd = await baseExeca(command[0], command.slice(1), options);
        return cmd;
    } catch (error) {
        const cmdError = error as ExecaError;
        return cmdError;
    }
}

export async function runLinters(fileList: string[], mode: 'lint' | 'fmt'): Promise<boolean> {
    let foundProblems = 0;
    let fixedProblems = 0;

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

        await Promise.all(fileList.map(async (file ) => {
            if (mode === 'lint') {
                const cmd = await execa(['git', 'check-ignore', '--no-index', file], { stdio: 'ignore' });
                if (cmd.exitCode !== 0) { // Success
                    logLintSuccess(toolName, file);
                } else { // Fail
                    foundProblems += 1;
                    logLintFail(toolName, file);
                    logAlways(`File ${file} should be gitignored`);
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

    logNormal(`Found ${foundProblems} problems`);
    if (mode === 'lint') {
        return foundProblems === 0;
    } else if (mode === 'fmt') {
        logNormal(`Fixed ${fixedProblems} problems`);
        return foundProblems === fixedProblems;
    }

    return true;
}
