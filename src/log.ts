import { ExecaReturnValue } from "@esm2cjs/execa";
import { ColorOptions } from "./utils";

export enum LogLevel {
    QUIET = 0,
    NORMAL = 1,
    VERBOSE = 2,
    EXTRA_VERBOSE = 3,
    EXTRA_EXTRA_VERBOSE = 4,
};

let level: LogLevel = LogLevel.QUIET;

export const TerminalColors = {
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[93m',
    end: '\x1b[0m',
}

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
        TerminalColors.green = '';
        TerminalColors.red = '';
        TerminalColors.end = '';
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
    logVerbose(`✅ ${TerminalColors.green}${toolName} - ${file}${TerminalColors.end}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logLintWarning(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    logAlways(`⚠️ ${TerminalColors.yellow}${toolName} - ${file}${TerminalColors.end}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logLintFail(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    logAlways(`❌ ${TerminalColors.red}${toolName} - ${file}${TerminalColors.end}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logFixingUnchanged(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    logVerbose(`💯 Unchanged: ${TerminalColors.green}${toolName} - ${file}${TerminalColors.end}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logFixingSuccess(toolName: string, file: string, command?: ExecaReturnValue<string>) {
    logNormal(`🛠️ Fixed: ${TerminalColors.green}${toolName} - ${file}${TerminalColors.end}`);
    if (command) {
        const cmdOutput = command.all ? `:\n${command.all}` : '';
        logExtraVerbose(`"${command.command}" -> ${command.exitCode}${cmdOutput}`);
    }
}

export function logFixingWarning(toolName: string, file: string, command: ExecaReturnValue<string>) {
    logAlways(`⚠️ Warning fixing: ${TerminalColors.yellow}${toolName} - ${file}${TerminalColors.end}`);
    const cmdOutput = command.all ? `:\n${command.all}` : '';
    logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`)
}

export function logFixingError(toolName: string, file: string, command: ExecaReturnValue<string>) {
    logAlways(`❗️ Error fixing: ${TerminalColors.red}${toolName} - ${file}${TerminalColors.end}`);
    const cmdOutput = command.all ? `:\n${command.all}` : '';
    logNormal(`"${command.command}" -> ${command.exitCode}${cmdOutput}`)
}
