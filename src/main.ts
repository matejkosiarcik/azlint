import path from 'path';
import fs from 'fs';
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import dotenv from 'dotenv';
import { ColorOptions, ProgressOptions, findFiles } from './utils';
import { LogLevel, logExtraExtraVerbose, logVerbose, setLogSettings } from './log';
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
        .option('progress', {
            describe: 'Display progress', type: 'string', choices: ['auto', 'always', 'never'], default: 'auto',
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

    if (fs.existsSync(path.join(__dirname, '..', '.env'))) {
        dotenv.config({ path: path.join(__dirname, '..', '.env') });
    }

    // Shortcircuit version
    if (argv.version) {
        console.log(`${argv.$0} 1.2.3`); // TODO: load version dynamically
        return;
    }

    if (argv.quiet && argv.verbose > 0) {
        console.error("Can't combine quiet and verbose!");
        process.exit(1);
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
    const progress = argv.progress as ProgressOptions;

    // Set global properties
    setLogSettings({
        level: logLevel,
        color: color,
    });
    process.chdir(directory);

    // Setup paths for dependencies
    const lintersDir = path.resolve(path.join(__dirname, '..', 'linters'));
    const binPaths = {
        node: path.join(lintersDir, 'node_modules', '.bin'),
        cargo: path.join(lintersDir, 'cargo', 'bin'),
        venv: path.join(lintersDir, 'venv', 'bin'),
        python: path.join(lintersDir, 'python', 'bin'),
        composer: path.join(lintersDir, 'vendor', 'bin'),
        go: path.join(lintersDir, 'go', 'bin'),
        checkmake: path.join(lintersDir, 'checkmake'),
        ec: path.join(lintersDir, 'editorconfig-checker', 'bin'),
    };
    process.env['PATH'] = `${Object.values(binPaths).join(':')}:${process.env['PATH']}`;
    process.env['PYTHONPATH'] = `${path.join(lintersDir, 'python')}`;
    process.env['BUNDLE_DISABLE_SHARED_GEMS'] = 'true';
    process.env['BUNDLE_PATH__SYSTEM'] = 'false';
    process.env['BUNDLE_PATH'] = path.join(lintersDir, 'bundle');
    process.env['BUNDLE_GEMFILE'] = path.join(lintersDir, 'Gemfile');

    logVerbose(`Performing: ${command}`);
    logVerbose(`Project path: ${path.resolve(process.cwd())}`);

    const projectFiles = await findFiles(onlyChanged);
    logExtraExtraVerbose(`Found ${projectFiles.length} project files:\n${projectFiles.map((el) => `- ${el}`).join('\n')}`);

    const linters = new Linters({
        mode: command,
        files: projectFiles,
        progress: progress,
    });
    const success = await linters.run();
    process.exit(success ? 0 : 1);
})();
