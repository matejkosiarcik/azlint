import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import process from 'process';
import { test, describe } from 'node:test';
import { expect } from 'chai';
import { delay, hashFile, isProjectGitRepo, resolvePromiseOrValue, wildcard2regex } from '../src/utils';

test('Project is git repo', async function () {
    expect(await isProjectGitRepo(), 'Project should be a git repo').true;
});

test('TEMPDIR is not git repo', async function () {
    const currDir = process.cwd();
    const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-tests-'));
    process.chdir(tmpDir);

    expect(await isProjectGitRepo(), 'TempDir should not be a git repo').false;

    process.chdir(currDir);
    await fs.rm(tmpDir, { force: true, recursive: true });
});

test('Delay', async function () {
    const start = Date.now();
    await delay(10);
    const end = Date.now();
    const difference = (end - start) / 1000;
    expect(difference, 'Delay should be delayed').gte(0.001).lte(0.1);
});

test('Resolve promises', async function () {
    const values = [
        {
            input: 30,
            expected: 30,
        },
        {
            input: (async () => 670)(),
            expected: 670,
        },
        {
            input: (async () => {
                await delay(1);
                return -9;
            })(),
            expected: -9,
        },
        {
            input: new Promise((resolve) => resolve(6)),
            expected: 6,
        },
    ];

    for (const value of values) {
        const expected = value.expected;
        const tested = await resolvePromiseOrValue(value.input);
        expect(tested).eq(expected);
    }
});

test('Hash file', async function () {
    const currDir = process.cwd();
    const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-tests-'));
    process.chdir(tmpDir);

    await fs.writeFile('file.txt', 'abc123', 'utf8');
    expect(await hashFile('file.txt'), 'Hash should match - 1').eq('Y2fEjdGT1W6nsLqtJbGUVeUp9e4=');
    expect(await hashFile('file.txt'), 'Hash should match - 2').eq('Y2fEjdGT1W6nsLqtJbGUVeUp9e4=');

    await fs.appendFile('file.txt', 'v2', 'utf8');
    expect(await hashFile('file.txt'), 'Hash should match - 2').eq('WCEPr/lhPcJbiYs9aW2reUk+Uvc=');

    process.chdir(currDir);
    await fs.rm(tmpDir, { force: true, recursive: true });
});

test('Wildcard to Regex conversion', async function () {
    const simpleRegex = wildcard2regex('foo');
    expect(simpleRegex.test('foo')).true;
    expect(simpleRegex.test('bar')).false;

    const fileRegex = wildcard2regex('abc.txt');
    expect(fileRegex.test('abc.txt')).true;
    expect(fileRegex.test('abc,txt')).false;

    const questionRegex = wildcard2regex('ab?.txt');
    expect(questionRegex.test('abc.txt')).true;
    expect(questionRegex.test('abd.txt')).true;
    expect(questionRegex.test('abcd.txt')).false;

    const starRegex = wildcard2regex('ab*.txt');
    expect(starRegex.test('ab.txt')).true;
    expect(starRegex.test('abc.txt')).true;
    expect(starRegex.test('abcd.txt')).true;

    const pathRegex = wildcard2regex('ab/*.txt');
    expect(pathRegex.test('ab/file.txt')).true;
    expect(pathRegex.test('ab/dir/file.txt')).false;
    expect(pathRegex.test('ab.txt')).false;

    const recursiveGlobRegex = wildcard2regex('ab/**/*.txt');
    expect(recursiveGlobRegex.test('ab/file.txt')).true;
    expect(recursiveGlobRegex.test('ab/dir/file.txt')).true;
    expect(recursiveGlobRegex.test('ab/dir/dir2/file.txt')).true;
    expect(recursiveGlobRegex.test('ab.txt')).false;

    const multichoiceRegex = wildcard2regex('ab.{txt,md}');
    expect(multichoiceRegex.test('ab.txt')).true;
    expect(multichoiceRegex.test('ab.md')).true;
    expect(multichoiceRegex.test('ab.txtmd')).false;
    expect(multichoiceRegex.test('ab.mdtxt')).false;
    expect(multichoiceRegex.test('ab.jpg')).false;
});
