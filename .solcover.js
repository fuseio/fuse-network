module.exports = {
    skipFiles: [
        'Migrations.sol',
        'test/BlockRewardMock.sol',
        'test/ConsensusMock.sol',
        'test/EternalStorageProxyMock.sol',
        'test/ProxyStorageMock.sol',
        'test/VotingMock.sol',
    ],
    // need for dependencies
    copyNodeModules: true,
    copyPackages: [
        'openzeppelin-solidity'
    ],
    dir: '.',
    providerOptions: {
        total_accounts: 110,
        default_balance_ether: 100000000,
        gasPrice: '0x1'
    },
    norpc: false
};
