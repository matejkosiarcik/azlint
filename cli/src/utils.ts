import path from 'node:path';
import fs from 'node:fs/promises';
import fsSync from 'node:fs';
import crypto from 'crypto';
import { execa, ExecaError, Options as ExecaOptions } from 'execa';
import { logAlways, logVerbose } from './log.ts';

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
export async function resolvePromiseOrValue<T>(value: MaybePromise<T>): Promise<T> {
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
        const baseCommit = await (async () => {
            if (process.env['AZLINT_DEFAULT_BASE_BRANCH']) {
                const customBaseRef = process.env['AZLINT_DEFAULT_BASE_BRANCH'];
                const resolvedBaseProcess = await customExeca(['git', 'rev-parse', '--verify', `${customBaseRef}^{commit}`]);
                if (resolvedBaseProcess.exitCode === 0 && resolvedBaseProcess.stdout.trim()) {
                    return resolvedBaseProcess.stdout.trim();
                }
            }

            let remotes: string[] = [];
            const remoteNameProcess = await customExeca(['git', 'remote']);
            if (remoteNameProcess.exitCode === 0) {
                remotes = remoteNameProcess.stdout.split('\n').map((line) => line.trim()).filter((line) => !!line);
            }

            if (remotes.includes('origin')) {
                const remoteHead = await customExeca(['git', 'symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD']);
                if (remoteHead.exitCode === 0 && remoteHead.stdout.trim()) {
                    return remoteHead.stdout.trim();
                }
            }

            for (const remote of remotes) {
                const remoteHead = await customExeca(['git', 'symbolic-ref', '--quiet', '--short', `refs/remotes/${remote}/HEAD`]);
                if (remoteHead.exitCode === 0 && remoteHead.stdout.trim()) {
                    return remoteHead.stdout.trim();
                }
            }

            const defaultBranches = ['main', 'master'];
            if (remotes.includes('origin')) {
                defaultBranches.push(...defaultBranches.map((branch) => `origin/${branch}`));
            } else {
                remotes.forEach((remote) => {
                    defaultBranches.push(...defaultBranches.map((branch) => `${remote}/${branch}`));
                })
            }

            for (const branch of defaultBranches) {
                const branchHeadProcess = await customExeca(['git', 'rev-parse', '--verify', `${branch}^{commit}`]);
                if (branchHeadProcess.exitCode === 0 && branchHeadProcess.stdout.trim()) {
                    return branchHeadProcess.stdout.trim();
                }
            }

            let currentBranch = '';
            const currentBranchProcess = await customExeca(['git', 'branch', '--show-current']);
            if (currentBranchProcess.exitCode === 0 && currentBranchProcess.stdout.trim()) {
                currentBranch = currentBranchProcess.stdout.trim()
            }

            if (currentBranch) {
                const commits = (await customExeca(['git', 'rev-list', '--first-parent', currentBranch])).stdout
                    .split('\n')
                    .filter(Boolean);

                for (const commit of commits) {
                    const candidatesProcess = (await customExeca(['git', 'for-each-ref', `--contains=${commit}`, '--format=%(refname:short)', 'refs/heads']));
                    if (candidatesProcess.exitCode === 0 && candidatesProcess.stdout.trim()) {
                        const candidatesBranches = candidatesProcess.stdout.split('\n').filter((branch) => !!branch && branch !== currentBranch).length;
                        if (candidatesBranches > 0) {
                            return commit;
                        }
                    }
                }
            }

            return '';
        })();

        if (!baseCommit) {
            logAlways('Could not find a comparison base for only-changed files; linting all files instead');
        } else {
            const changedFilesProcess = await customExeca(['git', 'diff', '--name-only', '-z', `${baseCommit}..HEAD`]);
            if (changedFilesProcess.exitCode === 0) {
                const changedFiles = changedFilesProcess.stdout.split('\0').filter((file) => !!file);
                outputFiles = [...untrackedFiles, ...stagedFiles, ...dirtyFiles, ...changedFiles];
            } else {
                logAlways('Could not list only-changed files; linting all files instead');
            }
        }
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

// type RecursivePartial<T> = T | Partial<T> | {
//     [K in keyof T]?: RecursivePartial<T[K]>;
// };

/**
 * Custom `execa` wrapper with useful default options
 */
export async function customExeca(command: string[], _options?: Partial<ExecaOptions>): Promise<CustomExecaProcessReturn> {
    const options: ExecaOptions = {
        timeout: _options?.timeout ?? 300_000, // Default 5 minutes
        stdio: 'pipe', // Capture output
        all: true, // Merge stdout and stderr
        ..._options ?? {},
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
            error: error.shortMessage,
            exitCode: error.exitCode ?? -1,
            stdout: stringifyOutput(error.stdout),
            stderr: stringifyOutput(error.stderr),
        };
    }
}

/**
 * Match list of files given wildcards or predicates
 */
export function matchFiles(allFiles: string[], fileMatch: MaybeArray<string | RegExp | ((file: string) => boolean)>): string[] {
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
