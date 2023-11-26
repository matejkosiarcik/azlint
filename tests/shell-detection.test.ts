import assert from 'node:assert';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { test, describe } from 'node:test';
import { detectShell } from '../src/utils';

describe('Shell detection', function () {
    let tmpDir: string;

    test.beforeEach(async function () {
        tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-'));
    });

    test.afterEach(async function () {
        await fs.rm(tmpDir, { force: true, recursive: true });
    });

    for (const shell of ['bash', 'ksh', 'yash', 'zsh']) {
        test(`Shell detection for .${shell}`, async function () {
            const filePath = path.join(tmpDir, `file.${shell}`);
            await fs.writeFile(filePath, '', 'utf8');
            const output = await detectShell(filePath);
            assert.strictEqual(output, shell);
        });
    }

    test(`Shell detection with shebang and more content`, async function () {
        const filePath = path.join(tmpDir, 'file.sh');
        await fs.writeFile(filePath, `#!/usr/bin/env zsh\nsomethingelse\n`, 'utf8');
        const output = await detectShell(filePath);
        assert.strictEqual(output, 'zsh');
    });

    test(`Shell detection with only shebang`, async function () {
        const filePath = path.join(tmpDir, 'file.sh');
        await fs.writeFile(filePath, `#!/usr/bin/env zsh`, 'utf8');
        const output = await detectShell(filePath);
        assert.strictEqual(output, 'zsh');
    });

    test(`Shell detection for "#!/bin/shell"`, async function () {
        const filePath = path.join(tmpDir, 'file.sh');
        await fs.writeFile(filePath, `#!/bin/yash`, 'utf8');
        const output = await detectShell(filePath);
        assert.strictEqual(output, 'yash');
    });

    test(`Shell detection for "#!/usr/bin/env shell"`, async function () {
        const filePath = path.join(tmpDir, 'file.sh');
        await fs.writeFile(filePath, `#!/bin/yash`, 'utf8');
        const output = await detectShell(filePath);
        assert.strictEqual(output, 'yash');
    });

    let testShells: { [key: string]: string[] } = {
        'bash': ['bash', 'bash4'],
        'dash': ['ash', 'dash'],
        'ksh': ['ksh', 'ksh93', 'mksh'],
        'sh': ['sh'],
        'yash': ['yash'],
        'zsh': ['zsh'],
    };
    for (const shellTarget of Object.keys(testShells)) {
        for (const shebang of testShells[shellTarget]) {
            test(`Shell detection for shebang ${shellTarget}-${shebang}`, async function () {
                const filePath = path.join(tmpDir, `file.sh`);
                await fs.writeFile(filePath, `#!/bin/${shebang}`, 'utf8');
                const output = await detectShell(filePath);
                assert.strictEqual(output, shellTarget);
            });
        }
    }
});
