import fs from 'fs/promises';
import fsSync from 'fs';
import path from "path";
import os from 'os';
import { Options as ExecaOptions } from "@esm2cjs/execa";
import pLimit, { LimitFunction } from "@esm2cjs/p-limit";
import { logExtraVerbose, logNormal, logVerbose, logFixingError, logFixingSuccess, logFixingUnchanged, logLintFail, logLintSuccess } from "./log";
import { combine, customExeca, getConfigArgs, getPythonConfigArgs, hashFile, isCwdGitRepo, matchFiles, OneOrArray, ProgressOptions, resolveLintArgs, resolveLintOptions, resolveLintSuccessExitCode, resolvePromiseOrValue } from "./utils";

function shouldSkipLinter(envName: string, linterName: string): boolean {
    const envEnable = 'VALIDATE_' + envName;
    if (process.env[envEnable] === 'false') {
        logExtraVerbose(`Skipped ${linterName} - ${envEnable} is false`);
        return true;
    }

    return false;
}

export class Linters {
    readonly mode: 'lint' | 'fmt';
    readonly files: string[];
    readonly progress: ProgressOptions;
    private _randomDir: string = '';
    private readonly savedJobs: Promise<void>[] = [];
    private limit: LimitFunction; // = pLimit(os.cpus().length * 10);

    foundProblems = 0;
    fixedProblems = 0;

    constructor(options: {
        mode: 'lint' | 'fmt',
        files: string[],
        progress: ProgressOptions,
        jobs: number,
    }) {
        this.mode = options.mode;
        this.files = options.files;
        this.progress = options.progress;
        this.limit = pLimit(options.jobs);
    }

    private async randomDir(): Promise<string> {
        return await fs.mkdtemp(path.join(this._randomDir, 'dir-'));
    }

    private async runLinter(
        options: {
            fileMatch: OneOrArray<string | RegExp | ((file: string) => boolean)>,
            linterName: string,
            envName: string,
            beforeAllFiles?: (toolName: string) => (void | Promise<void>),
            afterAllFiles?: (toolName: string) => (void | Promise<void>),
            shouldSkipAllFiles?: (toolName: string) => (boolean | Promise<boolean>),
            beforeFile?: ((file: string, toolName: string) => (void | Promise<void>)) | undefined,
            shouldSkipFile?: ((file: string, toolName: string) => (boolean | Promise<boolean>)) | undefined,
            afterFile?: ((file: string, toolName: string) => (void | Promise<void>)) | undefined,
            lintFile: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | number[] | ((status: number) => boolean) |  undefined,
            } | ((file: string, toolName: string) => Promise<void>),
            fmtFile?: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | number[] | ((status: number) => boolean) |  undefined,
            } | ((file: string, toolName: string) => Promise<void>),
            jobs?: number | undefined,
        }
    ): Promise<void> {
        if (shouldSkipLinter(options.envName, options.linterName)) {
            return;
        }

        if (options.shouldSkipAllFiles) {
            const returnValue = await resolvePromiseOrValue(options.shouldSkipAllFiles(options.linterName));

            if (returnValue) {
                return;
            }
        }

        if (options.beforeAllFiles) {
            await resolvePromiseOrValue(options.beforeAllFiles(options.linterName));
        }

        const files = matchFiles(this.files, options.fileMatch);
        await Promise.all(files.map(async (file) => {
            await this.runLinterFile({
                file: file,
                ...options,
            });
        }));

        if (options.afterAllFiles) {
            await resolvePromiseOrValue(options.afterAllFiles(options.linterName));
        }
    }

    private async runLinterFile(
        options: {
            linterName: string,
            envName: string,
            file: string,
            beforeFile?: ((file: string, toolName: string) => (void | Promise<void>)) | undefined,
            shouldSkipFile?: ((file: string, toolName: string) => (boolean | Promise<boolean>)) | undefined,
            afterFile?: ((file: string, toolName: string) => (void | Promise<void>)) | undefined,
            lintFile: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | number[] | ((status: number) => boolean) |  undefined,
            } | ((file: string, toolName: string) => Promise<void>),
            fmtFile?: {
                args: string[] | ((file: string) => (string[] | Promise<string[]>)),
                options?: ExecaOptions | ((file: string) => (ExecaOptions | Promise<ExecaOptions>)) | undefined,
                successExitCode?: number | number[] | ((status: number) => boolean) |  undefined,
            } | ((file: string, toolName: string) => Promise<void>),
        }
    ): Promise<void> {
        if (options.shouldSkipFile) {
            const returnValue = await resolvePromiseOrValue(options.shouldSkipFile(options.file, options.linterName));

            if (returnValue) {
                return;
            }
        }

        if (options.beforeFile) {
            options.beforeFile(options.file, options.linterName);
        }

        if (this.mode === 'lint') {
            let lintCallback: (file: string, toolName: string) => Promise<void> = async () => {};

            if (typeof options.lintFile === 'object') {
                const execaConfig = options.lintFile;
                lintCallback = async (file: string, toolName: string) => {
                    const args = await resolveLintArgs(execaConfig.args, file);
                    const options = await resolveLintOptions(execaConfig.options, file);
                    const isExitCodeSuccess = resolveLintSuccessExitCode(execaConfig.successExitCode);

                    const cmd = await customExeca(args, options);
                    if (isExitCodeSuccess(cmd.exitCode)) { // Success
                        logLintSuccess(toolName, file, cmd);
                    } else { // Fail
                        this.foundProblems += 1;
                        logLintFail(toolName, file, cmd);
                    }
                };
            } else {
                lintCallback = options.lintFile;
            }

            const lintJob = this.limit(async () => lintCallback(options.file, options.linterName));
            this.savedJobs.push(lintJob);
        } else if (this.mode === 'fmt' && options.fmtFile) {
            if (typeof options.fmtFile === 'object') {
                const execaConfig = options.fmtFile;
                options.fmtFile = async (file: string, toolName: string) => {
                    const args = await resolveLintArgs(execaConfig.args, file);
                    const options = await resolveLintOptions(execaConfig.options, file);
                    const isExitCodeSuccess = resolveLintSuccessExitCode(execaConfig.successExitCode);

                    const originalHash = await hashFile(file);
                    const cmd = await customExeca(args, options);
                    const updatedHash = await hashFile(file);
                    if (isExitCodeSuccess(cmd.exitCode)) {
                        if (originalHash !== updatedHash) {
                            this.foundProblems += 1;
                            this.fixedProblems += 1;
                            logFixingSuccess(toolName, file, cmd);
                        } else {
                            logFixingUnchanged(toolName, file, cmd);
                        }
                    } else {
                        logFixingError(toolName, file, cmd);
                    }
                };
            }
            await options.fmtFile(options.file, options.linterName);
        }

        if (options.afterFile) {
            options.afterFile(options.file, options.linterName);
        }
    }

    async run(): Promise<boolean> {
        this._randomDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-'));

        const matchers = {
            json: '*.{json,json5,jsonl,geojson,babelrc,ecrc,eslintrc,htmlhintrc,htmllintrc,jscsrc,jshintrc,jslintrc,prettierrc,remarkrc}',
            yaml: '*.{yml,yaml}',
            env: '{*.env,env.*,env}',
            dockerfile: '{Dockerfile,*.Dockerfile,Dockerfile.*}',
            markdown: '*.{md,mdown,markdown}',
            text: '*.{txt, text}',
            makefile: '{Makefile,*.make}',
            gnumakefile: ['{GNU,G}Makefile', '*.{gnu,g}make'],
            bsdmakefile: ['{BSD,B}Makefile', '*.{bsd,b}make'],
            html: '*.{html,htm,html5,xhtml}',
            shell: '*.{sh,bash,ksh,ksh93,mksh,oksh,loksh,ash,dash,zsh,yash}',
            python: '*.{py,py3,python,python3}',
            allText: [] as string[],
        };
        matchers.allText = [matchers.markdown, matchers.text, 'README', 'LICENSE'];

        /* Slow linters */
        // Here are linters which take the longest time, so we launch them first

        // Markdown link check
        const markdownLinkCheckConfigArgs = getConfigArgs('MARKDOWN_LINK_CHECK', '--config', ['markdown-link-check.json', '.markdown-link-check.json']);
        await this.runLinter({
            linterName: 'markdown-link-check',
            envName: 'MARKDOWN_LINK_CHECK',
            fileMatch: matchers.markdown,
            lintFile: { args: ['markdown-link-check', ...markdownLinkCheckConfigArgs, '--retry', '--verbose', "#file#"] },
            // lintFile: async (file: string, toolName: string) => {
            //     let attempt = 0;
            //     const self = this;
            //     async function run() {
            //         attempt += 1;
            //         const cmd = await customExeca(['markdown-link-check', ...markdownLinkCheckConfigArgs, '--retry', '--verbose', file]);
            //         if (cmd.exitCode === 0) { // Success
            //             logLintSuccess(toolName, file, cmd);
            //         } else { // Fail
            //             if (attempt < 3 && cmd.all?.includes(' → Status: 0')) {
            //                 logLintWarning(toolName, file);
            //                 await delay(1000);
            //                 await run();
            //             } else {
            //                 logLintFail(toolName, file, cmd);
            //                 self.foundProblems += 1;
            //             }
            //         }
            //     }

            //     await run();
            // },
        });

        // NPM install
        await this.runLinter({
            linterName: 'npm-install',
            envName: 'NPM_INSTALL',
            fileMatch: ['package.json'],
            lintFile: {
                args: ['npm', 'install', '--dry-run'],
                options: async (file) => {
                    const workdir = await this.randomDir();
                    await fs.copyFile(file, path.join(workdir, path.basename(file)));
                    return {
                        cwd: workdir,
                    };
                }
            },
        });

        /* Generic linters for all files */

        // Gitignore
        await this.runLinter({
            linterName: 'git-check-ignore',
            envName: 'GITIGNORE',
            fileMatch: '*',
            shouldSkipAllFiles: async (toolName: string) => {
                const isGit = await isCwdGitRepo();
                if (!isGit) {
                    logVerbose(`⏩ Skipping ${toolName}, not a git repository`);
                }
                return isGit;
            },
            lintFile: {
                args: ['git', 'check-ignore', '--no-index', '#file#'],
                successExitCode: 1,
            },
            fmtFile: async (file: string, toolName: string) => {
                const cmd = await customExeca(['git', 'check-ignore', '--no-index', file]);
                if (cmd.exitCode !== 0) { // Success
                    logLintSuccess(toolName, file, cmd);
                } else { // Fail
                    this.foundProblems += 1;
                    const cmd2 = await customExeca(['git', 'rm', '--cached', file]);
                    if (cmd2.exitCode === 0) {
                        logFixingSuccess(toolName, file);
                        this.fixedProblems += 1;
                    } else {
                        logFixingError(toolName, file, cmd2);
                    }
                }
            },
        });

        // Editorconfig-checker
        await this.runLinter({
            linterName: 'editorconfig-checker',
            envName: 'EDITORCONFIG_CHECKER',
            fileMatch: '*',
            lintFile: { args: ['ec', '#file#'] },
        });

        // ECLint
        await this.runLinter({
            linterName: 'eclint',
            envName: 'ECLINT',
            fileMatch: '*',
            lintFile: { args: ['eclint', '#file#'] },
        });

        /* Package Managers */

        // Composer install
        await this.runLinter({
            linterName: 'composer-install',
            envName: 'COMPOSER_INSTALL',
            fileMatch: 'composer.json',
            lintFile: { args: ['composer', 'install', '--dry-run', '--working-dir=#directory#'], },
        });

        // Pip install
        await this.runLinter({
            linterName: 'pip-install',
            envName: 'PIP_INSTALL',
            fileMatch: ['requirements.txt', 'requirements{-,_}*.txt', '*{-,_}requirements.txt'],
            lintFile: { args: ['python3', '-m', 'pip', 'install', '--dry-run', '--ignore-installed', '--break-system-packages', '--requirement', '#file#'] },
        });

        // HomeBrew
        await this.runLinter({
            linterName: 'brew-bundle',
            envName: 'BREW_BUNDLE',
            fileMatch: ['Brewfile', '*.Brewfile', 'Brewfile.*'],
            lintFile: { args: ['brew', 'bundle', 'list', '--file', '#file#', '--no-lock'] },
        });

        // NPM install - lockfile
        await this.runLinter({
            linterName: 'npm-install-lock',
            envName: 'NPM_INSTALL_LOCK',
            fileMatch: ['package-lock.json'],
            shouldSkipFile(file, toolName) {
                const skip = !fsSync.existsSync(path.join(path.dirname(file), 'package.json'));
                if (skip) {
                    logExtraVerbose(`⏩ Skipping ${toolName} - ${file}, no package.json find`);
                }
                return skip;
            },
            lintFile: {
                args: ['npm', 'ci', '--dry-run'],
                options: async (file) => {
                    const workdir = await this.randomDir();
                    await fs.copyFile(file, path.join(workdir, path.basename(file)));
                    await fs.copyFile(path.join(path.dirname(file), 'package.json'), path.join(workdir, 'package.json'));
                    return {
                        cwd: workdir,
                    };
                }
            },
        });

        /* Prettier - MultiLang */

        // Prettier
        const prettierConfigArgs = getConfigArgs('PRETTIER', '--config', ([] as string[]).concat(combine(['', '.'], 'prettier', ['', 'rc'], ['js', 'json', 'yaml', 'yml']), combine(['', '.'], 'prettierrc')));
        await this.runLinter({
            linterName: 'prettier',
            envName: 'PRETTIER',
            fileMatch: matchers.json,
            lintFile: { args: ['prettier', ...prettierConfigArgs, '--parser', 'json-stringify', '--list-different', '#file#'] },
            fmtFile: { args: ['prettier', ...prettierConfigArgs, '--parser', 'json-stringify', '--write', '#file#'] },
        });
        await this.runLinter({
            linterName: 'prettier',
            envName: 'PRETTIER',
            fileMatch: matchers.yaml,
            lintFile: { args: ['prettier', ...prettierConfigArgs, '--parser', 'yaml', '--list-different', '#file#'] },
            fmtFile: { args: ['prettier', ...prettierConfigArgs, '--parser', 'yaml', '--write', '#file#'] },
        });
        await this.runLinter({
            linterName: 'prettier',
            envName: 'PRETTIER',
            fileMatch: '*.{html,vue,css,scss,sass,less}',
            lintFile: { args: ['prettier', ...prettierConfigArgs, '--list-different', '#file#'] },
            fmtFile: { args: ['prettier', ...prettierConfigArgs, '--write', '#file#'] },
        });

        /* JSON, YAML, TOML */

        // Jsonlint
        const jsonlintConfigArgs = getConfigArgs('JSONLINT', '--config', ([] as string[]).concat(combine(['', '.'], 'jsonlintrc.', ['js', 'json', 'mjs', 'yaml', 'yml']), combine(['', '.'], 'jsonlintrc')));
        await this.runLinter({
            linterName: 'jsonlint',
            envName: 'JSONLINT',
            fileMatch: matchers.json,
            lintFile: { args: ['jsonlint', ...jsonlintConfigArgs, '--quiet', '--comments', '--no-duplicate-keys', '#file#'] },
        });

        // Yamllint
        const yamllintConfigArgs = getConfigArgs('YAMLLINT', '--config-file',
            ['yamllint.yml', 'yamllint.yaml'].flatMap((el) => [`${el}`, `.${el}`]));
        await this.runLinter({
            linterName: 'yamllint',
            envName: 'YAMLLINT',
            fileMatch: matchers.yaml,
            lintFile: { args: ['yamllint', '--strict', ...yamllintConfigArgs, '#file#'] },
        });

        // TomlJson
        await this.runLinter({
            linterName: 'tomljson',
            envName: 'TOMLJSON',
            fileMatch: '*.toml',
            lintFile: { args: ['tomljson', '#file#'] },
        });

        // Stoml
        await this.runLinter({
            linterName: 'stoml',
            envName: 'STOML',
            fileMatch: '*.{toml,cfg,ini}',
            lintFile: { args: ['stoml', '#file#', '.'] },
        });

        /* HTML, XML, SVG */

        // XmlLint
        await this.runLinter({
            linterName: 'xmllint',
            envName: 'XMLLINT',
            fileMatch: '*.xml',
            lintFile: { args: ['xmllint', '--noout', '#file#'] },
            fmtFile: { args: ['xmllint', '--format', '--output', '#file#', '#file#'] }
        });

        // HtmlLint
        const htmllintConfigArgs = getConfigArgs('HTMLLINT', '--rc', ['.htmllintrc']);
        await this.runLinter({
            linterName: 'htmllint',
            envName: 'HTMLLINT',
            fileMatch: matchers.html,
            lintFile: { args: ['htmllint', ...htmllintConfigArgs, '#file#'] },
        });

        // HtmlHint
        const htmlhintConfigArgs = getConfigArgs('HTMLHINT', '--config', ['.htmlhintrc']);
        await this.runLinter({
            linterName: 'htmlhint',
            envName: 'HTMLHINT',
            fileMatch: matchers.html,
            lintFile: { args: ['htmlhint', ...htmlhintConfigArgs, '#file#'] },
        });

        // Svglint
        const svglintConfigArgs = getConfigArgs('SVGLINT', '--config', ['.svglintrc.js', 'svglintrc.js']);
        await this.runLinter({
            linterName: 'svglint',
            envName: 'SVGLINT',
            fileMatch: '*.svg',
            lintFile: { args: ['svglint', '--ci', ...svglintConfigArgs, '#file#'] },
        });

        /* Markdown, Text */

        // Markdown-table-formatter
        await this.runLinter({
            linterName: 'markdown-table-formatter',
            envName: 'MARKDOWN_TABLE_FORMATTER',
            fileMatch: matchers.markdown,
            lintFile: { args: ['markdown-table-formatter', '--check', '#file#'] },
            fmtFile: { args: ['markdown-table-formatter', '#file#'] },
        });

        // Markdownlint
        const markdownlintConfigArgs = getConfigArgs('MDL', '--config', ['markdownlint.json', '.markdownlint.json']);
        await this.runLinter({
            linterName: 'markdownlint',
            envName: 'MARKDOWNLINT',
            fileMatch: matchers.markdown,
            lintFile: { args: ['markdownlint', ...markdownlintConfigArgs, '#file#'] },
            fmtFile: { args: ['markdownlint', ...markdownlintConfigArgs, '--fix', '#file#'] },
        });

        // mdl
        const mdlConfigArgs = getConfigArgs('MDL', '--config', ['.mdlrc']);
        await this.runLinter({
            linterName: 'mdl',
            envName: 'MDL',
            fileMatch: matchers.markdown,
            lintFile: { args: ['bundle', 'exec', 'mdl', ...mdlConfigArgs, '#file#'] },
        });

        // Proselint
        const proselintConfigArgs = getConfigArgs('PROSELINT', '--config', ['proselintrc', '.proselintrc']);
        await this.runLinter({
            linterName: 'proselint',
            envName: 'PROSELINT',
            fileMatch: matchers.allText,
            lintFile: { args: ['proselint', ...proselintConfigArgs, "#file#"] },
        });

        /* Shell */

        // Shfmt
        await this.runLinter({
            linterName: 'shfmt',
            envName: 'SHFMT',
            fileMatch: matchers.shell,
            lintFile: { args: ['shfmt', '-l', '-d', '#file#'] },
            fmtFile: { args: ['shfmt', '-w', '#file#'] }
        });

        // Shellharden
        await this.runLinter({
            linterName: 'shellharden',
            envName: 'SHELLHARDEN',
            fileMatch: matchers.shell,
            lintFile: { args: ['shellharden', '--check', '--suggest', '--', '#file#'] },
            fmtFile: { args: ['shellharden', '--replace', '--', '#file#'] }
        });

        // Bashate
        await this.runLinter({
            linterName: 'bashate',
            envName: 'BASHATE',
            fileMatch: matchers.shell,
            lintFile: { args: ['bashate', '--ignore', 'E001,E002,E003,E004,E005,E006', "#file#"] },
        });

        // Shellcheck
        await this.runLinter({
            linterName: 'shellcheck',
            envName: 'SHELLCHECK',
            fileMatch: [matchers.shell, '*.bats'],
            lintFile: { args: ['shellcheck', '--external-sources', "#file#"] },
        });

        // Bats
        await this.runLinter({
            linterName: 'bats',
            envName: 'BATS',
            fileMatch: '*.bats',
            lintFile: { args: ['bats', '--count', "#file#"] },
        });

        // Shell dry-run
        await this.runLinter({
            linterName: 'shell-dry-run',
            envName: 'SHELL_DRY_RUN',
            fileMatch: matchers.shell,
            lintFile: { args: ['sh', path.join(__dirname, 'shell-dry-run.sh'), "#file#"] },
        });

        // Hush
        await this.runLinter({
            linterName: 'hush-check',
            envName: 'HUSH_CHECK',
            fileMatch: '*.hush',
            lintFile: { args: ['hush', '--check', "#file#"] },
        });

        /* Python */

        // Autopep8
        await this.runLinter({
            linterName: 'autopep8',
            envName: 'AUTOPEP8',
            fileMatch: matchers.python,
            lintFile: { args: ['autopep8', '--diff', "#file#"], },
        });

        // isort
        const isortConfigArgs = getPythonConfigArgs('ISORT', 'isort', '--settings-file', ['isort.cfg', '.isort.cfg'], ['pyproject.toml', 'setup.cfg', 'tox.ini']);
        await this.runLinter({
            linterName: 'isort',
            envName: 'ISORT',
            fileMatch: matchers.python,
            lintFile: { args: ['isort', ...isortConfigArgs, '--honor-noqa', '--check-only', '--diff', "#file#"] },
            fmtFile: { args: ['isort', ...isortConfigArgs, '--honor-noqa', "#file#"] },
        });

        // Black
        const blackConfigArgs = getPythonConfigArgs('BLACK', 'black', '--config', ['black', '.black'], ['pyproject.toml']);
        await this.runLinter({
            linterName: 'black',
            envName: 'BLACK',
            fileMatch: matchers.python,
            lintFile: { args: ['black', ...blackConfigArgs, '--check', '--diff', '--quiet', "#file#"] },
            fmtFile: { args: ['black', ...blackConfigArgs, '--quiet', "#file#"] },
        });

        // Pycodestyle
        const pycodestyleConfigArgs = getPythonConfigArgs('PYCODESTYLE', 'pycodestyle', '--config', ['pycodestyle', '.pycodestyle'], ['setup.cfg', 'tox.ini']);
        await this.runLinter({
            linterName: 'pycodestyle',
            envName: 'PYCODESTYLE',
            fileMatch: matchers.python,
            lintFile: { args: ['pycodestyle', ...pycodestyleConfigArgs, "#file#"] },
        });

        // Flake8
        const flake8ConfigArgs = getPythonConfigArgs('FLAKE8', 'flake8', '--config', ['flake8', '.flake8'], ['setup.cfg', 'tox.ini']);
        await this.runLinter({
            linterName: 'flake8',
            envName: 'FLAKE8',
            fileMatch: matchers.python,
            lintFile: { args: ['flake8', ...flake8ConfigArgs, "#file#"] },
        });

        // Pylint
        const pylintConfigArgs = getPythonConfigArgs('PYLINT', 'pylint', '--rcfile', ['pylintrc', '.pylintrc'], ['pyproject.toml', 'setup.cfg', 'tox.ini']);
        await this.runLinter({
            linterName: 'pylint',
            envName: 'PYLINT',
            fileMatch: matchers.python,
            lintFile: { args: ['pylint', ...pylintConfigArgs, "#file#"] },
        });

        // MyPy
        await this.runLinter({
            linterName: 'mypy',
            envName: 'MYPY',
            fileMatch: matchers.python,
            lintFile: { args: ['mypy', '--follow-imports', 'skip', "#file#"] },
        });

        /* Package manager files */

        // Package.json validator
        await this.runLinter({
            linterName: 'package-json-validator',
            envName: 'PACKAGE_JSON',
            fileMatch: 'package.json',
            shouldSkipFile: async (file: string, toolName: string) => {
                const packageJson = JSON.parse(await fs.readFile(file, 'utf8'));
                const skip = packageJson['private'] === true;
                if (skip) {
                    logExtraVerbose(`⏩ Skipping ${toolName} - ${file}, because it's private`);
                }
                return skip;
            },
            lintFile: { args: ['pjv', '--warnings', '--recommendations', '--filename', '#file#'] },
        });

        // Composer validate
        await this.runLinter({
            linterName: 'composer-validate',
            envName: 'COMPOSER_VALIDATE',
            fileMatch: 'composer.json',
            lintFile: { args: ['composer', 'validate', '--no-interaction', '--no-cache', '--ansi', '--no-check-all', '--no-check-publish', '#file#'] },
        });

        // Composer normalize
        await this.runLinter({
            linterName: 'composer-normalize',
            envName: 'COMPOSER_NORMALIZE',
            fileMatch: 'composer.json',
            lintFile: {
                args: ['composer', 'normalize', '--no-interaction', '--no-cache', '--ansi', '--dry-run', '--diff', '#file[abs]#'],
                options: {
                    cwd: path.resolve(path.join(__dirname, '..', 'linters')),
                },
            },
            fmtFile: {
                args: ['composer', 'normalize', '--no-interaction', '--no-cache', '--ansi', '#file[abs]#'],
                options: {
                    cwd: path.resolve(path.join(__dirname, '..', 'linters')),
                },
            }
        });

        /* Docker */

        const dockerfilelintConfigArgs = getConfigArgs('DOCKERFILELINT', '--config', ['.dockerfilelintrc'], { mode: 'directory' });
        await this.runLinter({
            linterName: 'dockerfilelint',
            envName: 'DOCKERFILELINT',
            fileMatch: matchers.dockerfile,
            lintFile: { args: ['dockerfilelint', ...dockerfilelintConfigArgs, '#file#'] },
        });

        const hadolintConfigArgs = getConfigArgs('HADOLINT', '--config', combine(['', '.'], 'hadolint', ['', 'rc'], '.', ['yml', 'yaml']));
        await this.runLinter({
            linterName: 'hadolint',
            envName: 'HADOLINT',
            fileMatch: matchers.dockerfile,
            lintFile: { args: ['hadolint', ...hadolintConfigArgs, '#file#'] },
        });

        /* Makefile */

        // Checkmake
        const checkmakeConfigArgs = getConfigArgs('CHECKMAKE', '--config',
            ['checkmake.ini', '.checkmake.ini']);
        await this.runLinter({
            linterName: 'checkmake',
            envName: 'CHECKMAKE',
            fileMatch: [matchers.makefile, ...matchers.gnumakefile, ...matchers.bsdmakefile],
            lintFile: { args: ['checkmake', ...checkmakeConfigArgs, '#file#'] },
        });

        // GNU Make
        await this.runLinter({
            linterName: 'gmake',
            envName: 'GMAKE',
            fileMatch: [matchers.makefile, ...matchers.gnumakefile],
            lintFile: { args: ['gmake', '--dry-run', '-f', '#file#'] },
        });

        // BMake
        await this.runLinter({
            linterName: 'bmake',
            envName: 'BMAKE',
            fileMatch: [matchers.makefile, ...matchers.bsdmakefile],
            lintFile: { args: ['bmake', '-n', '-f', '#file#'] },
        });

        // BSD Make
        // TODO: Install bsdmake in docker and remove the following workaround
        const hasBsdMake = await (async () => {
            const cmd = await customExeca(['command', '-v', 'bsdmake']);
            return cmd.exitCode === 0;
        })();
        if (!hasBsdMake) {
            process.env['VALIDATE_BSDMAKE'] = 'false';
        }
        await this.runLinter({
            linterName: 'bsdmake',
            envName: 'BSDMAKE',
            fileMatch: [matchers.makefile, ...matchers.bsdmakefile],
            lintFile: { args: ['bsdmake', '-n', '-f', '#file#'] },
        });

        /* CI/CD Services */

        // CircleCI validate
        await this.runLinter({
            linterName: 'circleci-validate',
            envName: 'CIRCLECI_VALIDATE',
            fileMatch: '.circleci/config.yml',
            lintFile: {
                args: ['circleci', '--skip-update-check', 'config', 'validate'],
                options: (file: string) => {
                    return { cwd: path.dirname(path.dirname(file)) };
                },
            },
        });

        // GitLabCI Lint
        await this.runLinter({
            linterName: 'gitlab-ci-lint',
            envName: 'GITLABCI_LINT',
            fileMatch: '.gitlab-ci.yml',
            lintFile: { args: ['gitlab-ci-lint', '#file#'] },
        });

        // GitLabCI Validate
        await this.runLinter({
            linterName: 'gitlab-ci-validate',
            envName: 'GITLABCI_VALIDATE',
            fileMatch: '.gitlab-ci.yml',
            lintFile: { args: ['gitlab-ci-validate', 'validate', '#file#'] },
        });

        // TravisLint
        await this.runLinter({
            linterName: 'travis-lint',
            envName: 'TRAVIS_LINT',
            fileMatch: '.travis.yml',
            lintFile: {
                args: ['travis', 'lint', '--no-interactive', '--skip-version-check', '--skip-completion-check', '--exit-code', '--quiet'],
                options: (file: string) => {
                    return { cwd: path.dirname(file) };
                },
            },
        });

        // jscpd
        // const jscpdConfigArgs = getConfigArgs('JSCPD', '--config',
        //     ['jscpd.json', '.jscpd.json']);
        // const jscpdTmpdir = await this.randomDir();
        // await this.runLinter({
        //     linterName: 'jscpd',
        //     envName: 'JSCPD',
        //     fileMatch: '*',
        //     lintFile: { args: ['exitzero', 'jscpd', ...jscpdConfigArgs, '--output', jscpdTmpdir, '#file#'] },
        // });
        // await fs.rm(jscpdTmpdir, { force: true, recursive: true });

        /* Other */

        // Dotenv
        await this.runLinter({
            linterName: 'dotenv-linter',
            envName: 'DOTENV',
            fileMatch: matchers.env,
            lintFile: { args: ['dotenv-linter', '--quiet', '#file#'] },
        });

        /* End of linters */

        await Promise.all(this.savedJobs);

        // Report results
        logNormal(`Found ${this.foundProblems} problems`);
        if (this.mode === 'lint') {
            return this.foundProblems === 0;
        } else if (this.mode === 'fmt') {
            logNormal(`Fixed ${this.fixedProblems} problems`);
            return this.foundProblems === this.fixedProblems;
        }

        await fs.rm(this._randomDir, { force: true, recursive: true });
        return true;
    }
}
