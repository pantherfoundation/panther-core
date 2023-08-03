import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {abi as zkpTokenAbi} from '../../deployments/ARCHIVE/externalAbis/ZKPToken.json';
import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;
    const {deployer} = await getNamedAccounts();

    const MockFxPortalProxyAddress = await getContractAddress(
        hre,
        'MockFxPortal_Proxy',
        '',
    );
    const {abi: mockFxPortalAbi} = await artifacts.readArtifact('MockFxPortal');
    const mockFxPortal = await ethers.getContractAt(
        mockFxPortalAbi,
        MockFxPortalProxyAddress,
    );

    const zkpTokenAddress = await getContractAddress(hre, 'Zkp_token', '');

    const token = await ethers.getContractAt(zkpTokenAbi, zkpTokenAddress);

    const convertibleZkp = process.env.CONVERTIBLE_ZKP as string;
    const deployerBalance = await token.balanceOf(deployer);

    if (ethers.BigNumber.from(convertibleZkp).gt(deployerBalance)) {
        if ((await token.minter()) == deployer) {
            console.log('Deployer does not have enough ZKP balance.');
            console.log(
                `Minting ${ethers.utils.formatEther(
                    convertibleZkp,
                )} Zkp to deployer ${deployer}...`,
            );

            const tx = await token.mint(deployer, convertibleZkp);
            const res = await tx.wait();
            console.log('Transaction confirmed', res.transactionHash);
        } else {
            console.log('Skipping converting zkp tokens...');
            return;
        }
    }

    console.log(
        `Converting ${ethers.utils.formatEther(
            convertibleZkp,
        )} Zkp to ${deployer} address`,
    );

    const depositData = hre.ethers.utils.defaultAbiCoder.encode(
        ['uint256'],
        [convertibleZkp],
    );

    await token.approve(mockFxPortal.address, convertibleZkp);
    const tx = await mockFxPortal.depositFor(
        deployer,
        token.address,
        depositData,
    );
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['convert-zkp', 'protocol'];
func.dependencies = ['check-params', 'fx-portal'];
