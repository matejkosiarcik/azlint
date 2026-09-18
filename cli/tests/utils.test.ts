import assert from 'node:assert';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { test, describe } from 'node:test';
import { delay, hashFile, isProjectGitRepo, resolvePromiseOrValue, wildcard2regex } from '../src/utils';

describe('Utils', () => {
    test('Project is git repo', async function () {
        assert.ok(await isProjectGitRepo(), 'Project should be a git repo');
    });

    test('TEMPDIR is not git repo', async function () {
        const currDir = process.cwd();
        const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-tests-'));
        process.chdir(tmpDir);

        assert.strictEqual(await isProjectGitRepo(), false, 'TempDir should not be a git repo');

        process.chdir(currDir);
        await fs.rm(tmpDir, { force: true, recursive: true });
    });

    test('Delay', async function () {
        const start = Date.now();
        await delay(10);
        const end = Date.now();
        const difference = (end - start) / 1000;
        assert.ok(difference >= 0.001 && difference <= 0.1, `Delay should be delayed around 10ms, got ${difference}`);
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
            assert.strictEqual(tested, expected);
        }
    });

    test('Hash file', async function () {
        const currDir = process.cwd();
        const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-tests-'));
        process.chdir(tmpDir);

        await fs.writeFile('file.txt', 'abc123', 'utf8');
        assert.strictEqual(await hashFile('file.txt'), 'Y2fEjdGT1W6nsLqtJbGUVeUp9e4=', 'Hash should match - 1');
        assert.strictEqual(await hashFile('file.txt'), 'Y2fEjdGT1W6nsLqtJbGUVeUp9e4=', 'Hash should match - 2');

        await fs.appendFile('file.txt', 'v2', 'utf8');
        assert.strictEqual(await hashFile('file.txt'), 'WCEPr/lhPcJbiYs9aW2reUk+Uvc=', 'Hash should match - 2');

        process.chdir(currDir);
        await fs.rm(tmpDir, { force: true, recursive: true });
    });

    test('Wildcard to Regex conversion', async function () {
        const simpleRegex = wildcard2regex('foo');
        assert.ok(simpleRegex.test('foo'));
        assert.ok(!simpleRegex.test('bar'));

        const fileRegex = wildcard2regex('abc.txt');
        assert.ok(fileRegex.test('abc.txt'));
        assert.ok(!fileRegex.test('abc,txt'));

        const questionRegex = wildcard2regex('ab?.txt');
        assert.ok(questionRegex.test('abc.txt'));
        assert.ok(questionRegex.test('abd.txt'));
        assert.ok(!questionRegex.test('abcd.txt'));

        const starRegex = wildcard2regex('ab*.txt');
        assert.ok(starRegex.test('ab.txt'));
        assert.ok(starRegex.test('abc.txt'));
        assert.ok(starRegex.test('abcd.txt'));

        const pathRegex = wildcard2regex('ab/*.txt');
        assert.ok(pathRegex.test('ab/file.txt'));
        assert.ok(!pathRegex.test('ab/dir/file.txt'));
        assert.ok(!pathRegex.test('ab.txt'));

        const recursiveGlobRegex = wildcard2regex('ab/**/*.txt');
        assert.ok(recursiveGlobRegex.test('ab/file.txt'));
        assert.ok(recursiveGlobRegex.test('ab/dir/file.txt'));
        assert.ok(recursiveGlobRegex.test('ab/dir/dir2/file.txt'));
        assert.ok(!recursiveGlobRegex.test('ab.txt'));

        const multichoiceRegex = wildcard2regex('ab.{txt,md}');
        assert.ok(multichoiceRegex.test('ab.txt'));
        assert.ok(multichoiceRegex.test('ab.md'));
        assert.ok(!multichoiceRegex.test('ab.txtmd'));
        assert.ok(!multichoiceRegex.test('ab.mdtxt'));
        assert.ok(!multichoiceRegex.test('ab.jpg'));
    });
})
