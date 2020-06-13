#!/usr/bin/env node
const process = require('process')
const fs = require('fs')
const execa = require('execa')
const glob = require('glob')
const git = require('simple-git/promise')
const path = require('path')

// just bail on error
process.on('unhandledRejection', error => {
    console.error(`${error.name}: ${error.text}`)
    console.error(error)
    process.exit(1)
})

const isDocker = fs.existsSync('/.dockerenv') || fs.existsSync('/.dockerinit')

if (isDocker) {
    if (!('AZLINT_VERSION' in process.env)) {
        // default version for development
        process.env['AZLINT_VERSION'] = 'dev'
    }
} else {
    if (!('AZLINT_VERSION' in process.env)) {
        // when installed as package, use that specific installed version
        process.env['AZLINT_VERSION'] = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json')))['version'] || 'dev'
    }
}

console.error(`Run azlint version ${process.env['AZLINT_VERSION']}`)

// TODO: argument parsing (help, version)

function dockerVolumeArgumets(filelistPath) {
    if (isDocker) {
        // if we are inside container, we can't (generally?) mount volume directly
        // so we **copy** it into intermediary container and mount that instead
        console.error('Using intermediary container for volumes')
        let volume_container = execa.sync('docker', ['create', '--rm', '--volume', '/project', '--volume', '/projectlist', 'alpine', '/bin/true']).stdout
        process.on('exit', () => execa.sync('docker', ['rm', '--force', volume_container]))
        execa.sync('docker', ['cp', `${process.cwd()}/.`, `${volume_container}:/project`])
        execa.sync('docker', ['cp', path.resolve(filelistPath), `${volume_container}:/projectlist/projectlist.txt`])
        return ['--volumes-from', volume_container]
    } else {
        // If we are not in a container, it is more efficient(slightly) to mount volume directly
        console.error('Mounting volumes directly')
        return ['--volume', `${process.cwd()}:/project:ro`, '--volume', `${path.resolve(filelistPath)}:/projectlist/projectlist.txt:ro`]
    }
}

async function getProjectFileList() {
    const repo = git('.')

    // TODO: consider other VCS
    if (await repo.checkIsRepo()) {
        console.log('Project is a git repository')
        const trackedFilesList = execa.sync('git', ['ls-files', '-z']).stdout
            .split('\0')
            .filter(file => file.length > 0)
        const deletedFilesList = execa.sync('git', ['ls-files', '-z', '--deleted']).stdout
            .split('\0')
            .filter(file => file.length > 0)
        const untrackedFilesList = execa.sync('git', ['ls-files', '-z', '--others', '--exclude-standard']).stdout
            .split('\0')
            .filter(file => file.length > 0)
        return trackedFilesList.filter(file => !deletedFilesList.includes(file)).concat(untrackedFilesList).sort()
    } else {
        console.log('Project is bare directory')
        return glob.sync('**/*', { nodir: true, dot: true, ignore: ['.git/**/*', '.hg/**/*', '.svn/**/*'] }).sort()
    }
}

function writeProjectFileList(files) {
    const tmpDir = fs.mkdtempSync('.azlint-tmp')
    const fileString = files.reduce((sum, el) => `${sum}${el}\n`, '')
    const filePath = path.join(tmpDir, 'projectlist.txt')
    fs.writeFileSync(filePath, fileString)
    process.on('exit', () => fs.rmdirSync(tmpDir, { recursive: true }))
    return filePath
}

async function runComponent(componentName, dockerArgs) {
    console.log(`--- ${componentName} ---`)
    // console.time(componentName)
    await execa(dockerArgs[0], dockerArgs.splice(1), { stdout: process.stdout, stderr: process.stderr })
    // console.timeEnd(componentName)
}

(async () => {
    const files = await getProjectFileList()
    const listPath = writeProjectFileList(files)
    const dockerArgs = ['docker', 'run', '--rm', '--tty'].concat(dockerVolumeArgumets(listPath))
    const dockerTagPrefix = `matejkosiarcik/azlint-internal:${process.env['AZLINT_VERSION']}-`

    try {
        await runComponent('Alpine', dockerArgs.concat(`${dockerTagPrefix}alpine`))
        await runComponent('Bash', dockerArgs.concat(`${dockerTagPrefix}bash`))
        await runComponent('Brew', dockerArgs.concat(`${dockerTagPrefix}brew`))
        await runComponent('Composer', dockerArgs.concat(`${dockerTagPrefix}composer`))
        await runComponent('Debian', dockerArgs.concat(`${dockerTagPrefix}debian`))
        await runComponent('Go', dockerArgs.concat(`${dockerTagPrefix}go`))
        await runComponent('Hadolint', dockerArgs.concat(`${dockerTagPrefix}hadolint`))
        await runComponent('Node', dockerArgs.concat(`${dockerTagPrefix}node`))
        await runComponent('Python', dockerArgs.concat(`${dockerTagPrefix}python`))
        await runComponent('Shellcheck', dockerArgs.concat(`${dockerTagPrefix}shellcheck`))
        await runComponent('Swift', dockerArgs.concat(`${dockerTagPrefix}swift`))
        await runComponent('Zsh', dockerArgs.concat(`${dockerTagPrefix}zsh`))
    } catch (error) {
        process.exit(1)
    }
})()
