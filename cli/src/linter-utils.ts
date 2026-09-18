import path from 'node:path';
import { Options as ExecaOptions } from '@esm2cjs/execa';
import { resolvePromiseOrValue } from './utils';

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
 * Turn arguments into `execa` options
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
export function resolveLintSuccessExitCode(successStatus: number | number[] | ((exitCode: number) => boolean) | undefined): ((exitCode: number) => boolean) {
    if (successStatus === undefined) {
        successStatus = 0;
    }

    if (typeof successStatus === 'number') {
        const successExitCode = successStatus;
        return (exitCode: number) => exitCode === successExitCode;
    }

    if (Array.isArray(successStatus)) {
        const successExitCodes = successStatus;
        return (exitCode: number) => successExitCodes.includes(exitCode);
    }

    return successStatus;
}
