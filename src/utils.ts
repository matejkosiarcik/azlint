import path from 'path';
import fs from 'fs/promises';
import crypto from 'crypto';
import { execa, ExecaError, Options as ExecaOptions, ExecaReturnValue } from "@esm2cjs/execa";
import { logVerbose } from './log';

export type ColorOptions = 'auto' | 'always' | 'never';
export type ProgressOptions = 'auto' | 'always' | 'never';

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

// TODO: rewrite findFiles natively in TypeScript
export async function findFiles(onlyChanged: boolean): Promise<string[]> {
    const isGit = await isCwdGitRepo();
    logVerbose(`Project is git repository: ${isGit ? 'yes' : 'no'}`);

    const listArguments = [path.join(__dirname, 'find_files.py')];
    if (onlyChanged) {
        listArguments.push('--only-changed');
    }

    const listCommand = await execa('python3', listArguments, { stdio: 'pipe' });
    return listCommand.stdout.split('\n').filter((file) => file);
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
    const regex = wildcard.replace(/\./, "\\.")
        .replace(/\?/, ".")
        .replace(/\*/, ".*")
        .replace(/\{/, "(")
        .replace(/\}/, ")")
        .replace(/,/, "|");
    return new RegExp(`^(.*/)?${regex}$`, 'i');
}

/**
 * Custom `execa` wrapper with useful default options
 */
export async function customExeca(command: string[], _options?: ExecaOptions<string>): Promise<ExecaReturnValue<string>> {
    const options: ExecaOptions = {
        timeout: 60_000,
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
