import fs from 'fs/promises';
import os from 'os';
import path from 'path';

// TODO: Reenable shell-detection tests
context.skip('Test', function () {
    let tmpDir: string;

    this.beforeEach(async function () {
        tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'azlint-'));
    });

    this.afterEach(async function () {
        await fs.rm(tmpDir, { force: true, recursive: true });
    });

    const fileTypes = {
        'bash': ['bash'],
        'ksh': ['ksh', 'ksh93', 'mksh', 'oksh', 'loksh'],
        'yash': ['yash'],
        'zsh': ['zsh'],
    };

    for (const fileType of Object.keys(fileTypes)) {
        const target = fileType;
        const files = fileTypes[fileType as keyof typeof fileTypes].map((ext) => `file.${ext}`);

        for (const file of files) {
            it(`Shell detection ${target}`, async function () {
                const filePath = path.join(tmpDir, file);
                await fs.writeFile(filePath, Buffer.from(''));
                console.log(`Example - ${target}!`);
            });
        }
    }
});
