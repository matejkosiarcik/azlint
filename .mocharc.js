module.exports = {
    extension: ['ts'],
    spec: 'tests/mocha/**/*.test.ts',
    require: ['ts-node/register'],
    retries: 0,
    timeout: 10_000,
    parallel: false,
    asyncOnly: true,
    checkLeaks: true,
    failZero: true,
};
