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

let greenColor = '\x1b[32m';
let redColor = '\x1b[31m';
let yellowColor = '\x1b[93m';
let endColor = '\x1b[0m';

export function setLogSettings(options: {
    level: LogLevel,
    color: ColorOptions
}) {
    level = options.level;
    const color = (() => {
        if (options.color === 'always') {
            return true;
        } else if (options.color === 'never') {
            return false;
        } else {
            return process.stdout.isTTY;
        }
    })();

    if (!color) {
        greenColor = '';
        redColor = '';
        endColor = '';
    }
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
    logVerbose(`✅ ${greenColor}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logLintWarning(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    logAlways(`⚠️ ${yellowColor}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logLintFail(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    logAlways(`❌ ${redColor}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logFixingUnchanged(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    logVerbose(`💯 Unchanged: ${greenColor}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logFixingSuccess(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    logNormal(`🛠️ Fixed: ${greenColor}${toolName} - ${file}${endColor}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logFixingWarning(toolName: string, file: string, command: ExecaReturnValue<string>) {
    logAlways(`⚠️ Warning fixing: ${greenColor}${toolName} - ${file}${endColor}`);
    const cmdOutput = command.all ? `:\n${command.all}` : '';
    logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`)
}

export function logFixingError(toolName: string, file: string, command: ExecaReturnValue<string>) {
    logAlways(`❌ Error fixing: ${greenColor}${toolName} - ${file}${endColor}`);
    const cmdOutput = command.all ? `:\n${command.all}` : '';
    logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`)
}
