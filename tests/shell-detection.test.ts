import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import { expect } from 'chai';
import { detectShell } from '../src/utils';

context('Test', function () {
    let tmpDir: string;

    this.beforeEach(async function () {
        tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-'));
    });

    this.afterEach(async function () {
        await fs.rm(tmpDir, { force: true, recursive: true });
    });

    for (const shell of ['bash', 'ksh', 'yash', 'zsh']) {
        it(`Shell detection for .${shell}`, async function () {
            const filePath = path.join(tmpDir, `file.${shell}`);
            await fs.writeFile(filePath, '', 'utf8');
            const output = await detectShell(filePath);
            expect(output).eq(shell);
        });
    }

    it(`Shell detection with shebang and more content`, async function () {
        const filePath = path.join(tmpDir, 'file.sh');
        await fs.writeFile(filePath, `#!/usr/bin/env zsh\nsomethingelse\n`, 'utf8');
        const output = await detectShell(filePath);
        expect(output).eq('zsh');
    });

    it(`Shell detection with only shebang`, async function () {
        const filePath = path.join(tmpDir, 'file.sh');
        await fs.writeFile(filePath, `#!/usr/bin/env zsh`, 'utf8');
        const output = await detectShell(filePath);
        expect(output).eq('zsh');
    });

    it(`Shell detection for "#!/bin/shell"`, async function () {
        const filePath = path.join(tmpDir, 'file.sh');
        await fs.writeFile(filePath, `#!/bin/yash`, 'utf8');
        const output = await detectShell(filePath);
        expect(output).eq('yash');
    });

    it(`Shell detection for "#!/usr/bin/env shell"`, async function () {
        const filePath = path.join(tmpDir, 'file.sh');
        await fs.writeFile(filePath, `#!/bin/yash`, 'utf8');
        const output = await detectShell(filePath);
        expect(output).eq('yash');
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
            it(`Shell detection for shebang ${shellTarget}`, async function () {
                const filePath = path.join(tmpDir, `file.sh`);
                await fs.writeFile(filePath, `#!/bin/${shebang}`, 'utf8');
                const output = await detectShell(filePath);
                expect(output).eq(shellTarget);
            });
        }
    }
});
