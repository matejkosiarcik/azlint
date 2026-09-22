import path from 'node:path';
import fs from 'node:fs/promises';
import fsSync from 'node:fs';
import crypto from 'crypto';
import { execa, ExecaError, Options as ExecaOptions } from 'execa';
import { logAlways, logVerbose } from './log.ts';

export type OneOrArray<T> = T | T[];
export type ColorOptions = 'auto' | 'never' | 'always';
export type ProgressOptions = 'no' | 'yes';

/**
 * Check if `cwd` is a git repository
 */
export async function isProjectGitRepo(): Promise<boolean> {
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
 * List files in a directory (be default recursive)
 */
export async function listDirectory(directory: string, options?: { recursive?: boolean }): Promise<string[]>  {
    const recursive = options?.recursive ?? true;
    return (await fs.readdir(directory, { withFileTypes: true, recursive: recursive }))
        .filter((el) => el.isFile())
        .map((file) => path.join(file.parentPath, file.name).replaceAll('\\', '/'))
        .sort();
}

/**
 * Return a list of files in current project
 */
export async function listProjectFiles(onlyChanged: boolean): Promise<string[]> {
    const isGit = await isProjectGitRepo();
    logVerbose(`Project is git repository: ${isGit ? 'yes' : 'no'}`);

    if (!isGit) {
        if (onlyChanged) {
            logAlways(`Could not get only-changed files - not a git repository`);
        }

        return await listDirectory('.');
    }

    // NOTE: `git ls-files` accepts kinda non-standard globs
    // `git ls-files *.js` does not glob *files* with a name of "*.json", it globs *PATHS* with pattern of "*.json"
    // So if we glob literal name of certain files, such as "package.json":
    // `git ls-files package.json` -> this will only find package.json in the root of the repository
    // `git ls-files */package.json` -> this will find package.json anywhere except the root of the repository
    // `git ls-files package.json */package.json` -> this will find it anywhere, which we want

    // Files tracked by git (default)
    const trackedFiles = (await customExeca(["git", "ls-files", "-z"])).stdout.split('\0').filter((file) => !!file);

    // Files tracked by git, which are deleted in working tree
    const deletedFiles = (await customExeca(["git", "ls-files", "-z", "--deleted"])).stdout.split('\0').filter((file) => !!file);

    // Files which are not yet tracked/staged in git
    // These should be in both full output and only-changed output
    const untrackedFiles = (await customExeca(["git", "ls-files", "-z", "--others", "--exclude-standard"])).stdout.split("\0").filter((file) => !!file);

    // Staged files
    const stagedFiles = (await customExeca(["git", "diff", "--name-only", "--cached", "-z"])).stdout.split('\0').filter((file) => !!file);

    // Files modified in working tree
    const dirtyFiles = (await customExeca(["git", "diff", "--name-only", "HEAD", "-z"])).stdout.split('\0').filter((file) => !!file);

    let outputFiles = [...trackedFiles, ...untrackedFiles, ...stagedFiles, ...dirtyFiles];

    if (onlyChanged) {
        // Get all branches which are associated with current HEAD
        const allCurrentBranches = (await customExeca(["git", "branch", "--contains", 'HEAD', "--format=%(refname:short)"])).stdout.split("\n").filter((file) => !!file);

        // Get commit which is the point of divergence from parent branch
        let divergentCommit = '';
        for (let i = 1; true; i += 1) {
            divergentCommit = `HEAD~${i}`;
            try {
                const commitBranches = (await customExeca(["git", "branch", "--contains", divergentCommit, "--format=%(refname:short)"])).stdout.split("\n").filter((branch) => !!branch).filter((branch) => allCurrentBranches.includes(branch));
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
            divergentFiles = (await customExeca(["git", "diff", "--name-only", "-z", `${divergentCommit}..HEAD`])).stdout.split('\0').filter((file) => !!file);
        }

        outputFiles = [...untrackedFiles, ...stagedFiles, ...dirtyFiles, ...divergentFiles];
    }

    return Array.from(new Set(outputFiles)).map((file) => file.replaceAll('\\', '/')).sort().filter((file) => !deletedFiles.includes(file)).filter((file) => fsSync.existsSync(file));
}

/**
 * Get SHA1 hash of file
 */
export async function hashFile(file: string): Promise<string> {
    const fileContent = await fs.readFile(file, 'utf8');
    return crypto.createHash('sha1').update(fileContent).digest('base64');
}

/**
 * Transform wildcard to regex
 * This might not be foolproof, but should be ok for our use-case
 * Handles even relatively complex things like '*.{c,h}{,pp}'
 */
export function wildcard2regex(wildcard: string): RegExp {
    const regex = wildcard
        .replace(/-/g, "\\-")
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

export type CustomExecaProcessReturn = {
    all: string,
    command: string,
    error: string,
    exitCode: number,
    stdout: string,
    stderr: string,
}

/**
 * Custom `execa` wrapper with useful default options
 */
export async function customExeca(command: string[], options?: ExecaOptions): Promise<CustomExecaProcessReturn> {
    options = {
        timeout: 300_000, // 5 minutes
        stdio: 'pipe', // Capture output
        all: true, // Merge stdout and stderr
        ...options ?? {},
    };

    function stringifyOutput(output: string | string[] | unknown[] | Uint8Array<ArrayBufferLike> | null | undefined): string {
        if (typeof output === 'string') {
            return output;
        } else if (typeof output === 'undefined') {
            return '';
        } else if (typeof output === 'object' && output === null) {
            return '';
        } else if (Array.isArray(output)) {
            return output.map((el) => `${el}`).join('\n');
        } else if (output instanceof Uint8Array) {
            return Buffer.from(output).toString('utf-8');
        }

        return '';
    }

    try {
        const program = await execa(command[0], command.slice(1), options);
        return {
            all: stringifyOutput(program.all),
            command: command.join(' '),
            error: '',
            exitCode: program.exitCode ?? -1,
            stdout: stringifyOutput(program.stdout),
            stderr: stringifyOutput(program.stderr),
        };
    } catch (_error) {
        if (!(_error instanceof ExecaError)) {
            return {
                all: '',
                command: command.join(' '),
                error: `${_error}`,
                exitCode: -1,
                stdout: '',
                stderr: '',
            };
        }

        const error = _error as ExecaError;
        return {
            all: stringifyOutput(error.all),
            command: command.join(' '),
            error: '',
            exitCode: error.exitCode ?? -1,
            stdout: stringifyOutput(error.stdout),
            stderr: stringifyOutput(error.stderr),
        };
    }
}

/**
 * Match list of files given wildcards or predicates
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
 * Detect shell
 */
export async function detectShell(file: string): Promise<'bash' | 'dash' | 'ksh' | 'sh' | 'yash' | 'zsh' | string> {
    const extension = path.extname(file).slice(1);
    let likelyShell = '';
    if (['bash', 'ksh', 'yash', 'zsh'].includes(extension)) {
        likelyShell = extension;
    }

    if (extension === 'sh') {
        const fileContent = await fs.readFile(file, 'utf8');
        if (fileContent.length === 0) {
            return likelyShell;
        }
        const shebang = fileContent.split('\n')[0].trim();
        const execPath = shebang.split(' ').at(-1)!.split('/').at(-1)!;
        const possibleShells: { [key: string]: (string | RegExp)[]} = {
            'bash': ['bash', /bash\d+/],
            'yash': ['yash', /yash\d+/],
            'zsh': ['zsh', /zsh\d+/],
            'ksh': ['ksh', 'ksh88', 'ksh93', 'loksh', 'mksh', 'oksh', 'pdksh', /ksh\d+/],
            'sh': ['sh'],
            'dash': ['ash', /ash\d+/, 'dash', /dash\d+/],
        };

        for (const shell of Object.keys(possibleShells)) {
            for (const predicate of possibleShells[shell]) {
                if (typeof predicate === 'string' && execPath === predicate) {
                    return shell;
                } else if (typeof predicate === 'object' && predicate.test(execPath)) {
                    return shell;
                }
            }
        }
    }

    return  likelyShell;
}
