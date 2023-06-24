import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import { findFiles } from './utils';
import { LogLevel, logExtraExtraVerbose, logVerbose, setLogLevel } from './log';
import path from 'path';
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
            alias: 'c', describe: 'Analyze only changed files (requires project to be a git directory)', type: 'boolean',
        })
        .option('dry-run', {
            alias: 'n', describe: 'Dry run', type: 'boolean',
        })
        .positional('dir', {
            describe: 'Path to project directory', type: 'string', default: '.',
        })
        .command('lint', 'Lint project (default)', (yargs) => {
            yargs.usage('Usage: azlint lint [options...] [dir]');
        })
        .command('fmt', 'Format project (autofix)', (yargs) => {
            yargs.usage('Usage: azlint fmt [options...] [dir]');
        })
        .parse();

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
    const directory = argv.dir;
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

    // Set global properties
    setLogLevel(logLevel);
    process.chdir(directory);

    // Setup paths for dependencies
    const dependenciesDir = path.resolve(path.join(__dirname, '..', 'dependencies'));
    const nodePath = path.join(dependenciesDir, 'node_modules', '.bin');
    const cargoPath = path.join(dependenciesDir, '.cargo', 'bin');
    const venvPath = path.join(dependenciesDir, 'venv', 'bin');
    const composerPath = path.join(dependenciesDir, 'vendor', 'bin');
    process.env['PATH'] = `${nodePath}:${cargoPath}:${venvPath}:${composerPath}:${process.env['PATH']}`;
    const bundlePath = path.join(dependenciesDir, '.bundle');
    const gemfilePath = path.join(dependenciesDir, 'Gemfile');
    process.env['BUNDLE_DISABLE_SHARED_GEMS'] = 'true';
    process.env['BUNDLE_PATH__SYSTEM'] = 'false';
    process.env['BUNDLE_PATH'] = bundlePath;
    process.env['BUNDLE_GEMFILE'] = gemfilePath;

    logVerbose(`Performing: ${command}`);
    logVerbose(`Project path: ${path.resolve(process.cwd())}`);

    const projectFiles = await findFiles(onlyChanged);
    logExtraExtraVerbose(`Found ${projectFiles.length} project files:\n${projectFiles.map((el) => `- ${el}`).join('\n')}`);

    const linters = new Linters(command, projectFiles, '.');
    const success = await linters.run();
    process.exit(success ? 0 : 1);
})();
