export enum LogLevel {
    QUIET = 0,
    NORMAL = 1,
    VERBOSE = 2,
    EXTRA_VERBOSE = 3,
};

let level: LogLevel;

export function setLogLevel(_level: LogLevel) {
    level = _level;
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

export function logAlways(...args: unknown[]): boolean {
    console.log(...args);
    return true;
}
