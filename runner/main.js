const process = require('process')
const fs = require('fs')
const execa = require('execa')
const glob = require('glob')
const git = require('simple-git/promise')
const path = require('path')

// just bail on error
process.on('unhandledRejection', error => {
    process.exit(1)
})

// default version for development
if (!('AZLINT_VERSION' in process.env)) {
    process.env['AZLINT_VERSION'] = 'dev'
}

// TODO: argument parsing (help, version)

function dockerVolumeArgumets(filelistPath) {
    if (fs.existsSync('/.dockerenv') || fs.existsSync('/.dockerinit')) {
        // if we are inside container, we can't (generally?) mount volume directly
        // so we **copy** it into intermediary container and mount that instead
        console.error('Using intermediary container for volumes')
        let volume_container = execa.sync('docker', ['create', '-v', '/project', '-v', '/projectlist', 'alpine', '/bin/true']).stdout
        process.on('exit', () => execa.sync('docker', ['rm', '--force', volume_container]))
        execa.sync('docker', ['cp', `${process.cwd()}/.`, `${volume_container}:/project`])
        execa.sync('docker', ['cp', path.resolve(filelistPath), `${volume_container}:/projectlist/projectlist.txt`])
        return ['--volumes-from', volume_container]
    } else {
        // If we are not in a container, it is more efficient(slightly) to mount volume directly
        console.error('Mounting volumes directly')
        return ['--volume', `${process.cwd()}:/project`, '--volume', `${path.resolve(filelistPath)}:/projectlist/projectlist.txt`]
    }
}

async function getProjectFileList() {
    const repo = git('.')
    let allFiles = glob.sync('**/*', { nodir: true, dot: true, ignore: '.git/**/*' })

    if (await repo.checkIsRepo()) {
        console.log('Is repo')
        files = allFiles;
        let newAllFiles = [];
        while (files.length > 0) {
            const currentFiles = files.splice(0, 1000);
            const currentIgnoredFiles = await repo.checkIgnore(currentFiles);
            newAllFiles = newAllFiles.concat(currentFiles.filter(file => !currentIgnoredFiles.includes(file)));
        }
        allFiles = newAllFiles;
    } else {
        console.log('Not repo')
    }

    return allFiles
}

function writeProjectFileList(files) {
    const tmpDir = fs.mkdtempSync('azlint-tmp')
    const fileString = files.reduce((sum, el) => `${sum}${el}\n`, '')
    const filePath = path.join(tmpDir, 'projectlist.txt')
    fs.writeFileSync(filePath, fileString)
    process.on('exit', () => fs.rmdirSync(tmpDir, { recursive: true }))
    return filePath
}

(async () => {
    const files = await getProjectFileList()
    const listPath = writeProjectFileList(files)
    const someArgs = ['run', '--rm', '--tty'].concat(dockerVolumeArgumets(listPath))
    const dockerTagPrefix = `matejkosiarcik/azlint:${process.env['AZLINT_VERSION']}`
    await execa('docker', someArgs.concat([`${dockerTagPrefix}-shellcheck`]), { stdout: process.stdout, stderr: process.stderr })
    await execa('docker', someArgs.concat([`${dockerTagPrefix}-python`]), { stdout: process.stdout, stderr: process.stderr })
    await execa('docker', someArgs.concat([`${dockerTagPrefix}-composer`]), { stdout: process.stdout, stderr: process.stderr })
})()
