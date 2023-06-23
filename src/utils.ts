import { execa } from '@esm2cjs/execa';
import path from 'path';
import { logVerbose } from './log';

export async function isProjectGitRepo(): Promise<boolean> {
    try {
        await execa('git', ['rev-parse']);
        return true;
    } catch {
        return false;
    }
}

export async function findFiles(onlyChanged: boolean): Promise<string[]> {
    const isGit = await isProjectGitRepo();

    logVerbose(`Project is git repository: ${isGit ? 'yes' : 'no'}`);

    const listArguments = [path.join(__dirname, 'find_files.py')];
    if (onlyChanged) {
        listArguments.push('--only-changed');
    }

    const listCommand = await execa('python3', listArguments, { stdio: 'pipe' });
    return listCommand.stdout.split('\n').filter((file) => file);
}
