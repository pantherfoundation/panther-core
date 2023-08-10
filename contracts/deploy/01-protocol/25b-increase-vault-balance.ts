import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;
    const {deployer} = await getNamedAccounts();

    const vaultProxy = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    const pzkp = await getContractAddress(hre, 'PZkp_token', 'PZKP_TOKEN');
    const {abi} = await artifacts.readArtifact('TokenMock');

    const token = await ethers.getContractAt(abi, pzkp);

    const vaultBalance = process.env.VAULT_BALANCE as string;
    const deployerBalance = await token.balanceOf(deployer);

    if (ethers.BigNumber.from(vaultBalance).gt(deployerBalance)) {
        console.log(
            'Skipping increase of the vault balance due to lack of deployer ZKP balance.',
        );
        return;
    }

    console.log(
        'Increasing vault balance by',
        ethers.utils.formatEther(vaultBalance),
    );

    const tx = await token.transfer(vaultProxy, vaultBalance);
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['inc-vault-balance', 'protocol'];
func.dependencies = ['check-params', 'convert-zkp', 'vault-proxy'];
