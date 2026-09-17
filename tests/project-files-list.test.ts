import assert from 'node:assert';
import fsx from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { test, describe } from 'node:test';
import { execa as baseExeca } from '@esm2cjs/execa';
import { listProjectFiles } from "../src/utils";

async function touch(...files: string[]) {
    await Promise.all(files.map(async (file) => fsx.mkdir(path.dirname(files[0]), { recursive: true })));
    await Promise.all(files.map(async (file) => fsx.appendFile(file, Buffer.from([]))));
}

/**
 * Custom `execa` wrapper with useful default options
 */
export async function execa(...command: string[]) {
    await baseExeca(command[0], command.slice(1));
}

describe('Find files in raw directory', function () {
    let tmpDir: string;
    let currDir: string;

    test.beforeEach(async function () {
        currDir = process.cwd();
        tmpDir = await fsx.mkdtemp(path.join(os.tmpdir(), 'azlint-tests-'));
        process.chdir(tmpDir);
    });

    test.afterEach(async function () {
        process.chdir(currDir);
        await fsx.rm(tmpDir, { force: true, recursive: true });
    });

    test('Find single file', async () => {
        await touch('foo.txt');
        assert.deepStrictEqual(await listProjectFiles(false), ['foo.txt']);
    });

    test('Find multiple files with sorting', async () => {
        await touch('1.txt', '4.txt', '2.txt');
        assert.deepStrictEqual(await listProjectFiles(false), ['1.txt', '2.txt', '4.txt']);
    });

    test('Find files recursively with sorting', async () => {
        await touch('1.txt', 'bar/foo/3.txt', 'foo/foo.txt', 'foo/2.txt');
        assert.deepStrictEqual(await listProjectFiles(false), ['1.txt', 'bar/foo/3.txt', 'foo/2.txt', 'foo/foo.txt']);
    });
});

describe('Find files in git repository', function () {
    let tmpDir: string;
    let currDir: string;

    test.beforeEach(async function () {
        currDir = process.cwd();
        tmpDir = await fsx.mkdtemp(path.join(os.tmpdir(), 'azlint-tests-'));
        process.chdir(tmpDir);
        await execa('git', 'init');
    });

    test.afterEach(async function () {
        process.chdir(currDir);
        await fsx.rm(tmpDir, { force: true, recursive: true });
    });

    test('Empty repo', async () => {
        assert.deepStrictEqual(await listProjectFiles(false), []);
    });

    test('Single dirty file', async () => {
        await touch('foo.txt');
        assert.deepStrictEqual(await listProjectFiles(false), ['foo.txt']);
    });

    test('Two dirty files', async () => {
        await touch('foo', 'bar.txt');
        assert.deepStrictEqual(await listProjectFiles(false), ['bar.txt', 'foo']);
    });

    test('Single staged file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        assert.deepStrictEqual(await listProjectFiles(false), ['foo.txt']);
    });

    test('Single commited file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        await execa('git', 'commit', '-m', 'message');
        assert.deepStrictEqual(await listProjectFiles(false), ['foo.txt']);
    });

    test('Staged and deleted file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        await fsx.rm('foo.txt');
        assert.deepStrictEqual(await listProjectFiles(false), []);
    });

    test('Commited and deleted file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        await execa('git', 'commit', '-m', 'message');
        await fsx.rm('foo.txt');
        assert.deepStrictEqual(await listProjectFiles(false), []);
    });

    test('Commited and deleted file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        await execa('git', 'commit', '-m', 'message');
        await fsx.rm('foo.txt');
        assert.deepStrictEqual(await listProjectFiles(false), []);
    });

    test('Complicated scenario 1', async () => {
        await touch('1.txt', '2.txt', '3.txt');
        await execa('git', 'add', '1.txt');
        await execa('git', 'commit', '-m', 'message');
        await execa('git', 'add', '2.txt');
        assert.deepStrictEqual(await listProjectFiles(false), ['1.txt', '2.txt', '3.txt']);
    });

    test('Complicated scenario 2', async () => {
        await touch('1.txt', '2.txt', '3.txt');
        await execa('git', 'add', '1.txt');
        await execa('git', 'commit', '-m', 'message');
        await execa('git', 'add', '2.txt');
        await fsx.rm('1.txt');
        await fsx.rm('2.txt');
        await fsx.rm('3.txt');
        assert.deepStrictEqual(await listProjectFiles(false), []);
    });

    test('Only-changed', async () => {
        await touch('1.txt');
        await execa('git', 'add', '1.txt');
        await execa('git', 'commit', '-m', 'message');
        await execa('git', 'checkout', '-b', 'branch');
        await touch('2.txt');
        await execa('git', 'add', '2.txt');
        await execa('git', 'commit', '-m', 'message');
        assert.deepStrictEqual(await listProjectFiles(true), ['2.txt']);
    });

    // TODO: Add test for --only-changed with commits in a feature branch
});
