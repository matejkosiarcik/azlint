import { ExecaReturnValue } from "@esm2cjs/execa";
import { logAlways, logExtraVerbose, logNormal, logVerbose } from "./log-levels";

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
