import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import process from 'process';
import { expect } from 'chai';
import { listProjectFiles } from "../src/utils";
import { execa as baseExeca } from '@esm2cjs/execa';

async function touch(...files: string[]) {
    // const files = Array.isArray(file) ? file : [file];
    await Promise.all(files.map(async (file) => fs.appendFile(file, Buffer.from(''))));
}
/**
 * Custom `execa` wrapper with useful default options
 */
export async function execa(...command: string[]) {
    await baseExeca(command[0], command.slice(1));
}

context('Find files in raw directory', function () {
    let tmpDir: string;
    let currDir: string;

    this.beforeEach(async function () {
        currDir = process.cwd();
        tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-tests-'));
        process.chdir(tmpDir);
    });

    this.afterEach(async function () {
        process.chdir(currDir);
        await fs.rm(tmpDir, { force: true, recursive: true });
    });

    it('Find single file', async () => {
        await touch('foo.txt');
        expect(await listProjectFiles(false)).deep.eq(['foo.txt']);
    });

    it('Find multiple file with sorting', async () => {
        await touch('1.txt', '4.txt', '2.txt');
        expect(await listProjectFiles(false)).deep.eq(['1.txt', '2.txt', '4.txt']);
    });
});

context('Find files', function () {
    let tmpDir: string;
    let currDir: string;

    this.beforeEach(async function () {
        currDir = process.cwd();
        tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-tests-'));
        process.chdir(tmpDir);
        await execa('git', 'init');
    });

    this.afterEach(async function () {
        process.chdir(currDir);
        await fs.rm(tmpDir, { force: true, recursive: true });
    });

    it('Empty repo', async () => {
        expect(await listProjectFiles(false)).deep.eq([]);
    });

    it('Single dirty file', async () => {
        await touch('foo.txt');
        expect(await listProjectFiles(false)).deep.eq(['foo.txt']);
    });

    it('Two dirty files', async () => {
        await touch('foo', 'bar.txt');
        expect(await listProjectFiles(false)).deep.eq(['bar.txt', 'foo']);
    });

    it('Single staged file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        expect(await listProjectFiles(false)).deep.eq(['foo.txt']);
    });

    it('Single commited file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        await execa('git', 'commit', '-m', 'message');
        expect(await listProjectFiles(false)).deep.eq(['foo.txt']);
    });

    it('Staged and deleted file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        await fs.rm('foo.txt');
        expect(await listProjectFiles(false)).deep.eq([]);
    });

    it('Commited and deleted file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        await execa('git', 'commit', '-m', 'message');
        await fs.rm('foo.txt');
        expect(await listProjectFiles(false)).deep.eq([]);
    });

    it('Commited and deleted file', async () => {
        await touch('foo.txt');
        await execa('git', 'add', 'foo.txt');
        await execa('git', 'commit', '-m', 'message');
        await fs.rm('foo.txt');
        expect(await listProjectFiles(false)).deep.eq([]);
    });

    it('Complicated scenario 1', async () => {
        await touch('1.txt', '2.txt', '3.txt');
        await execa('git', 'add', '1.txt');
        await execa('git', 'commit', '-m', 'message');
        await execa('git', 'add', '2.txt');
        expect(await listProjectFiles(false)).deep.eq(['1.txt', '2.txt', '3.txt']);
    });

    it('Complicated scenario 2', async () => {
        await touch('1.txt', '2.txt', '3.txt');
        await execa('git', 'add', '1.txt');
        await execa('git', 'commit', '-m', 'message');
        await execa('git', 'add', '2.txt');
        await fs.rm('1.txt');
        await fs.rm('2.txt');
        await fs.rm('3.txt');
        expect(await listProjectFiles(false)).deep.eq([]);
    });

    it('Only-changed', async () => {
        await touch('1.txt');
        await execa('git', 'add', '1.txt');
        await execa('git', 'commit', '-m', 'message');
        await execa('git', 'checkout', '-b', 'branch');
        await touch('2.txt');
        await execa('git', 'add', '2.txt');
        await execa('git', 'commit', '-m', 'message');
        expect(await listProjectFiles(true)).deep.eq(['2.txt']);
    });
});
