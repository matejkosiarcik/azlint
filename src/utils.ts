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
        .map((file) => path.join(directory, file.name))
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

/**
 * Custom `execa` wrapper with useful default options
 */
export async function customExeca(command: string[], options?: ExecaOptions<string>): Promise<ExecaReturnValue<string>> {
    options = {
        timeout: 300_000, // 5 minutes
        stdio: 'pipe', // Capture output
        all: true, // Merge stdout and stderr
        ...options ?? {},
    };

    try {
        const program = await execa(command[0], command.slice(1), options);
        return program;
    } catch (error) {
        return error as ExecaError;
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
