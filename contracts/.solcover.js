const shell = require('shelljs');

module.exports = {
    istanbulReporter: ['html', 'lcov', 'cobertura'],
    onCompileComplete: async function (_config) {
        await run('typechain');
    },
    onIstanbulComplete: async function (_config) {
        // We need to do this because solcover generates bespoke artifacts.
        shell.rm('-rf', './artifacts');
        shell.rm('-rf', './typechain');
    },
    skipFiles: [
        'staking',
        'common',
        'protocol/v0',
        'protocol/v1/mocks',
        'protocol/v1/interfaces',
        'protocol/v1/errMsgs',
        'protocol/v1/DeFi',
    ],
};
