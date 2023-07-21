import path from 'path';
import fs from 'fs/promises';
import fsSync from 'fs';
import crypto from 'crypto';
import { execa, ExecaError, Options as ExecaOptions, ExecaReturnValue } from "@esm2cjs/execa";
import { logAlways, logVerbose } from './log';

export type OneOrArray<T> = T | T[];

export type ColorOptions = 'auto' | 'never' | 'always';
export type ProgressOptions = 'no' | 'yes';

/**
 * Check if `cwd` is a git repository
 */
export async function isCwdGitRepo(): Promise<boolean> {
    try {
        await execa('git', ['rev-parse']);
        return true;
    } catch {
        return false;
    }
}

/**
 * Just delay for specified timeout (ms)
 */
export async function delay(timeout: number) {
    return new Promise((resolve) => {
        setTimeout(() => resolve(true), timeout);
    });
}

/**
 * Turn sync value into async value
 */
export async function resolvePromiseOrValue<T>(value: T | Promise<T>): Promise<T> {
    if (value && typeof value === 'object') {
        return 'then' in value ? await value : value;
    }
    return value;
}

/**
 * Turn arguments into executable command
 * Replace occurences of #file# and similar with actual filepaths
 */
export async function resolveLintArgs(args: string[] | ((file: string) => (string[] | Promise<string[]>)), file: string): Promise<string[]> {
    if (Array.isArray(args)) {
        return args.map((el) => el
            .replace('#file#', file)
            .replace('#filename#', path.basename(file))
            .replace('#directory#', path.dirname(file))
            .replace('#file[abs]#', path.resolve(file))
            .replace('#directory[abs]#', path.resolve(path.dirname(file)))
        );
    }

    return resolvePromiseOrValue(args(file));
}

/**
 * Turn arguments into Execa options
 */
export async function resolveLintOptions(options: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined, file: string): Promise<ExecaOptions> {
    if (options === undefined) {
        return {};
    } else if (typeof options === 'object') {
        return options;
    } else {
        return resolvePromiseOrValue(options(file));
    }
}

/**
 * Turn arguments into a predicate
 */
export function resolveLintSuccessExitCode(successExitCode: number | number[] | ((status: number) => boolean) |  undefined): ((status: number) => boolean) {
    if (successExitCode === undefined) {
        successExitCode = 0;
    }

    if (typeof successExitCode === 'number') {
        const staticSuccessExitCode = successExitCode;
        successExitCode = (success: number) => {
            return success === staticSuccessExitCode;
        }
    }

    if (Array.isArray(successExitCode)) {
        const staticSuccessExitCodes = successExitCode;
        successExitCode = (success: number) => {
            return staticSuccessExitCodes.includes(success);
        }
    }

    return successExitCode;
}

/**
 * Return a list of files in current project
 */
export async function findFiles(onlyChanged: boolean): Promise<string[]> {
    const isGit = await isCwdGitRepo();
    logVerbose(`Project is git repository: ${isGit ? 'yes' : 'no'}`);

    if (!isGit) {
        if (onlyChanged) {
            logAlways(`Could not get only-changed files - not a git repository`);
        }

        const rawFileList = await fs.readdir('.', { recursive: true });
        return rawFileList.sort();
    }

    // NOTE: `git ls-files` accepts kinda non-standard globs
    // `git ls-files *.js` does not glob *files* with a name of "*.json", it globs *PATHS* with pattern of "*.json"
    // So if we glob literal name of certain files, such as "package.json":
    // `git ls-files package.json` -> this will only find package.json in the root of the repository
    // `git ls-files */package.json` -> this will find package.json anywhere except the root of the repository
    // `git ls-files package.json */package.json` -> this will find it anywhere, which we want

    // Files tracked by git (default)
    const trackedFiles = (await customExeca(["git", "ls-files", "-z"])).stdout.split('\0').filter((el) => !!el);

    // Files tracked by git, which are deleted in working tree
    const deletedFiles = (await customExeca(["git", "ls-files", "-z", "--deleted"])).stdout.split('\0').filter((el) => !!el);

    // Files which are not yet tracked/staged in git
    // These should be in both full output and only-changed output
    const untrackedFiles = (await customExeca(["git", "ls-files", "-z", "--others", "--exclude-standard"])).stdout.split("\0").filter((el) => !!el);

    // Staged files
    const stagedFiles = (await customExeca(["git", "diff", "--name-only", "--cached", "-z"])).stdout.split('\0').filter((el) => !!el);

    // Files modified in working tree
    const dirtyFiles = (await customExeca(["git", "diff", "--name-only", "HEAD", "-z"])).stdout.split('\0').filter((el) => !!el);

    let outputFiles = [...trackedFiles, ...untrackedFiles, ...stagedFiles, ...dirtyFiles];

    if (onlyChanged) {
        // Get all branches which are associated with current HEAD
        const allCurrentBranches = (await customExeca(["git", "branch", "--contains", 'HEAD', "--format=%(refname:short)"])).stdout.split("\n").filter((el) => !!el);

        // Get commit which is the point of divergence from parent branch
        let divergentCommit = '';
        for (let i = 1; true; i += 1) {
            divergentCommit = `HEAD~${i}`;
            try {
                const commitBranches = (await customExeca(["git", "branch", "--contains", divergentCommit, "--format=%(refname:short)"])).stdout.split("\n").filter((el) => !!el).filter((el) => allCurrentBranches.includes(el));
                if (commitBranches.length > 0) {
                    break;
                }
            } catch {
                logAlways("Could not find parent branch for list of only-changed files - azlint may skip some files because of this");
                divergentCommit = '';
                break;
            }
        }

        let divergentFiles: string[] = [];
        if (divergentCommit !== '') {
            // Modified files between divergent-commit and HEAD
            divergentFiles = (await customExeca(["git", "whatchanged", "--name-only", "--pretty=", `${divergentCommit}..HEAD`, "-z"])).stdout.split('\0').filter((el) => !!el);
        }

        outputFiles = [...untrackedFiles, ...stagedFiles, ...dirtyFiles, ...divergentFiles];
    }

    return Array.from(new Set(outputFiles)).sort().filter((el) => !deletedFiles.includes(el)).filter((el) => fsSync.existsSync(el));
}

/**
 * Get SHA1 hash of file
 */
export async function hashFile(file: string): Promise<string> {
    const fileContent = await fs.readFile(file, 'utf8');
    const sha1 = crypto.createHash('sha1');
    return sha1.update(fileContent).digest('base64');
}

/**
 * Transform wildcard to regex
 * This might not be foolproof, but should be ok for our use-case
 * Handles even relatively complex things like '*.{c,h}{,pp}'
 */
export function wildcard2regex(wildcard: string): RegExp {
    const regex = wildcard
        .replace(/\./g, "\\.")
        .replace(/\?/g, ".")
        .replace(/\*{2}\//g, ".<star>/?")
        .replace(/\*{2}/g, ".<star>")
        .replace(/\*/g, "[^/\\\\]<star>")
        .replace(/\{/g, "(")
        .replace(/\}/g, ")")
        .replace(/,/g, "|")
        .replace(/<star>/g, "*");
    return new RegExp(`^(.*/)?${regex}$`, 'i');
}

/**
 * Custom `execa` wrapper with useful default options
 */
export async function customExeca(command: string[], _options?: ExecaOptions<string>): Promise<ExecaReturnValue<string>> {
    const options: ExecaOptions = {
        timeout: 300_000,
        stdio: 'pipe', // Capture output
        all: true, // Merge stdout and stderr
        ..._options ?? {},
    };

    try {
        const cmd = await execa(command[0], command.slice(1), options);
        return cmd;
    } catch (error) {
        const cmdError = error as ExecaError;
        return cmdError;
    }
}

/**
 * Match list of files agains a given wildcards or predicates
 */
export function matchFiles(allFiles: string[], fileMatch: OneOrArray<string | RegExp | ((file: string) => boolean)>): string[] {
    fileMatch = Array.isArray(fileMatch) ? fileMatch : [fileMatch];

    const predicates = fileMatch.map((fileMatchEntry) => {
        if (typeof fileMatchEntry === 'string') {
            const regex = wildcard2regex(fileMatchEntry);
            return (file: string) => regex.test(file);
        } else if (fileMatchEntry instanceof RegExp) {
            return (file: string) => fileMatchEntry.test(file);
        } else {
            return fileMatchEntry;
        }
    });

    return allFiles.filter((file) => predicates.some((predicate) => predicate(file)));
}

/**
 * Returns config directories in the following order:
 * - FOO_CONFIG_DIR
 * - CONFIG_DIR
 * - . (cwd)
 * - ./.config
 */
function getConfigDirs(envName: string): string[] {
    const output: string[] = [];

    // First check if specific FOO_CONFIG_DIR is set
    const linterConfigDir = process.env[`${envName}_CONFIG_DIR`];
    if (linterConfigDir) {
        output.push(linterConfigDir);
    }

    // Check if global CONFIG_DIR is set
    const generalConfigDir = process.env['CONFIG_DIR'];
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
 * Determine config file to use for linter `X`
 * - if `X_CONFIG_FILE` is specified, returns `CONFIG_DIR/X_CONFIG_FILE`
 * - else searches `CONFIG_DIR` for config files and returns first found
 * @returns array of arguments to use in subprocess call
 */
export function getConfigArgs(envName: string, configArgName: string, possibleDefaultConfigFiles: string[], options?: { mode: 'file' | 'directory' }): string[] {
    const mode = options?.mode ?? 'file';
    const customConfigFilePath = process.env[envName + '_CONFIG_FILE'];

    const configFiles = getConfigDirs(envName)
        .map((configDir) => {
            if (customConfigFilePath) {
                const overrideConfigFile = path.join(configDir, customConfigFilePath);
                if (fsSync.existsSync(overrideConfigFile)) {
                    return overrideConfigFile;
                }
            }

            const potentialConfigs = possibleDefaultConfigFiles
                .map((file) => path.join(configDir, file))
                .filter((file) => fsSync.existsSync(file));
            if (potentialConfigs.length === 0) {
                return '';
            }
            return potentialConfigs[0];
        })
        .filter((file) => file);

    if (configFiles.length === 0) {
        return [];
    }

    let configFile = configFiles[0];
    if (mode === 'directory') {
        configFile = path.dirname(configFile);
    }
    return configArgName.endsWith('=') ? [`${configArgName}${configFile}`] : [configArgName, configFile];
}

/**
 * Determine config file to use for linter `X` - Python oriented
 * Python needs specific logic, because Python tools are a little different
 * Some have dedicated config files, but they are also configurable by shared config files, eg. setup.cfg or pyproject.toml
 */
export function getPythonConfigArgs(envName: string, linterName: string, configArgName: string, possibleDefaultConfigFilesSpecific: string[], possibleDefaultConfigFilesCommon: string[]): string[] {
    const specificConfigArgs = getConfigArgs(envName, configArgName, possibleDefaultConfigFilesSpecific);
    if (specificConfigArgs.length > 0) {
        return specificConfigArgs;
    }

    const commonConfigFiles = getConfigDirs(envName)
        .map((configDir) => {
            const commonConfigs = possibleDefaultConfigFilesCommon
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

            return '';
        })
        .filter((file) => file);

    if (commonConfigFiles.length === 0) {
        return [];
    }

    const commonConfigFile = commonConfigFiles[0];
    return configArgName.endsWith('=') ? [`${configArgName}${commonConfigFile}`] : [configArgName, commonConfigFile];
}
