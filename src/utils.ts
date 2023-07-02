import path from 'path';
import fs from 'fs/promises';
import fsSync from 'fs';
import crypto from 'crypto';
import { execa, ExecaError, Options as ExecaOptions, ExecaReturnValue } from "@esm2cjs/execa";
import { logVerbose } from './log';

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

/**
 * Match list of files agains a given wildcards or predicates
 */
export function matchFiles(allFiles: string[], fileMatch: string | string[] | ((file: string) => boolean) | ((file: string) => boolean)[]): string[] {
    if (typeof fileMatch === 'string') {
        const regex = wildcard2regex(fileMatch);
        return allFiles.filter((file) => regex.test(file));
    }

    if (Array.isArray(fileMatch)) {
        if (fileMatch.length === 0) {
            return [];
        }

        if (typeof fileMatch[0] === 'string') {
            const regexes = (fileMatch as string[]).map((wildcard) => wildcard2regex(wildcard));
            return allFiles.filter((file) => regexes.some((regex) => regex.test(file)));
        }

        return allFiles.filter((file) => (fileMatch as ((file: string) => boolean)[]).some((predicate) => predicate(file)));
    }

    return allFiles.filter((file) => fileMatch(file));
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
export function getConfigArgs(envName: string, configArgName: string, possibleDefaultConfigFiles: string[]): string[] {
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

    const configFile = configFiles[0];
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
