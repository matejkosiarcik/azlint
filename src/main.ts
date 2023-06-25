import path from 'path';
import fs from 'fs';
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import dotenv from 'dotenv';
import { ColorOptions, findFiles } from './utils';
import { LogLevel, logExtraExtraVerbose, logVerbose, setLogLevel } from './log';
import { Linters } from './linters';

(async () => {
    const argv = await yargs(hideBin(process.argv))
        .scriptName('azlint')
        .help(true)
        .version(false)
        .usage('Usage: azlint <command> [options...] [dir]')
        .option('help', {
            alias: 'h', describe: 'Show usage', type: 'boolean',
        })
        .option('version', {
            alias: 'V', describe: 'Show version', type: 'boolean',
        })
        .option('verbose', {
            alias: 'v', describe: 'Verbose logging (stackable, max: -vvv)', type: 'count',
        })
        .option('quiet', {
            alias: 'q', describe: 'Less logging', type: 'boolean',
        })
        .option('only-changed', {
            describe: 'Analyze only changed files (requires project to be a git directory)', type: 'boolean',
        })
        .option('dry-run', {
            alias: 'n', describe: 'Dry run', type: 'boolean',
        })
        .option('color', {
            describe: 'Colored output', type: 'string', choices: ['auto', 'always', 'never'], default: 'auto',
        })
        .command('lint', 'Lint project (default)', (yargs) => {
            yargs.usage('Usage: azlint lint [options...] [dir]');
        })
        .command('fmt', 'Format project (autofix)', (yargs) => {
            yargs.usage('Usage: azlint fmt [options...] [dir]');
        })
        .demandCommand()
        .strictCommands()
        .positional('dir', {
            describe: 'Path to project directory', type: 'string', default: '.',
        })
        .parse();
    // TODO: make "lint" default command
    // TODO: Handle situations when no command is supplied and directorty is supplied

    if (fs.existsSync('.env')) {
        dotenv.config({ path: '.env' });
    }

    // Shortcircuit version
    if (argv.version) {
        console.log(`${argv.$0} 1.2.3`); // TODO: load version dynamically
        return;
    }

    // Extract arguments
    const logLevel = argv.quiet ? LogLevel.QUIET :
        argv.verbose >= 3 ? LogLevel.EXTRA_EXTRA_VERBOSE :
        argv.verbose >= 2 ? LogLevel.EXTRA_VERBOSE :
        argv.verbose >= 1 ? LogLevel.VERBOSE :
        LogLevel.NORMAL; // TODO: Simplify expression
    const directory = (() => {
        if (argv._.length > 1) {
            return argv._[1].toString();
        }
        return argv.dir;
    })();
    const onlyChanged = argv.onlyChanged ?? false;
    const command: 'lint' | 'fmt' = (() => {
        if (!argv._ || argv._.length === 0) {
            return 'lint';
        }

        const cmd = argv._[0].toString();
        if (['lint', 'fmt'].includes(cmd)) {
            return cmd as 'lint' | 'fmt';
        }

        console.error(`Unrecognized command: ${cmd}`);
        process.exit(1);
    })();
    const color = argv.color as ColorOptions;

    // Set global properties
    setLogLevel(logLevel);
    process.chdir(directory);

    // Setup paths for dependencies
    const dependenciesDir = path.resolve(path.join(__dirname, '..', 'dependencies'));
    const binPaths = {
        node: path.join(dependenciesDir, 'node_modules', '.bin'),
        cargo: path.join(dependenciesDir, '.cargo', 'bin'),
        venv: path.join(dependenciesDir, 'venv', 'bin'),
        composer: path.join(dependenciesDir, 'vendor', 'bin'),
        checkmake: path.join(dependenciesDir, 'checkmake', 'bin'),
        editorconfig: path.join(dependenciesDir, 'editorconfig-checker', 'bin'),
    };
    // process.env['PATH'] = `${binPaths.node}:${binPaths.cargo}:${binPaths.venv}:${binPaths.composer}:${binPaths.checkmake}:${binPaths.editorconfig}:${process.env['PATH']}`;
    process.env['PATH'] = `${Object.values(binPaths).join(':')}:${process.env['PATH']}`;
    process.env['BUNDLE_DISABLE_SHARED_GEMS'] = 'true';
    process.env['BUNDLE_PATH__SYSTEM'] = 'false';
    process.env['BUNDLE_PATH'] = path.join(dependenciesDir, '.bundle');
    process.env['BUNDLE_GEMFILE'] = path.join(dependenciesDir, 'Gemfile');

    logVerbose(`Performing: ${command}`);
    logVerbose(`Project path: ${path.resolve(process.cwd())}`);

    const projectFiles = await findFiles(onlyChanged);
    logExtraExtraVerbose(`Found ${projectFiles.length} project files:\n${projectFiles.map((el) => `- ${el}`).join('\n')}`);

    const linters = new Linters(command, projectFiles, color);
    const success = await linters.run();
    process.exit(success ? 0 : 1);
})();
