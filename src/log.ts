import { ExecaReturnValue } from "@esm2cjs/execa";
import { ColorOptions } from "./utils";

export enum LogLevel {
    QUIET = 0,
    NORMAL = 1,
    VERBOSE = 2,
    EXTRA_VERBOSE = 3,
    EXTRA_EXTRA_VERBOSE = 4,
};

let level: LogLevel;
let color: ColorOptions;

export function setLogSettings(options: {
    level: LogLevel,
    color: ColorOptions
}) {
    level = options.level;
    color = options.color;
}

export function logNormal(...args: unknown[]): boolean {
    if (level.valueOf() >= LogLevel.NORMAL.valueOf()) {
        console.log(...args);
        return true;
    }
    return false;
}

export function logVerbose(...args: unknown[]): boolean {
    if (level.valueOf() >= LogLevel.VERBOSE.valueOf()) {
        console.log(...args);
        return true;
    }
    return false;
}

export function logExtraVerbose(...args: unknown[]): boolean {
    if (level.valueOf() >= LogLevel.EXTRA_VERBOSE.valueOf()) {
        console.log(...args);
        return true;
    }
    return false;
}

export function logExtraExtraVerbose(...args: unknown[]): boolean {
    if (level.valueOf() >= LogLevel.EXTRA_EXTRA_VERBOSE.valueOf()) {
        console.log(...args);
        return true;
    }
    return false;
}

export function logAlways(...args: unknown[]): boolean {
    console.log(...args);
    return true;
}

export function logLintSuccess(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logVerbose(`✅ ${color}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logLintFail(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[31m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logAlways(`❌ ${color}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logFixingUnchanged(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logVerbose(`💯 Unchanged: ${color}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logFixingSuccess(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logNormal(`🛠️ Fixed: ${color}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logFixingError(toolName: string, file: string, command: ExecaReturnValue<string>) {
    const color = process.stdout.isTTY ? '\x1b[32m' : '';
    const endColor = process.stdout.isTTY ? '\x1b[0m' : '';
    logAlways(`❗️ Error fixing: ${color}${toolName} - ${file}${endColor}`);
    const cmdOutput = command.all ? `:\n${command.all}` : '';
    logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`)
}
