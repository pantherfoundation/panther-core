import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    deployContentDeterministically,
    reuseEnvAddress,
    getContractEnvVariable,
} from '../../lib/deploymentHelpers';
import {encodeVerificationKey} from '../../lib/encodeVerificationKey';
import verificationKeys from '../../test/protocol/data/verificationKeys.json';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    // TODO all the VKs should be added in the future
    const nPublicInputKeysToBeAdded = [1, 5];

    for (let i = 0; i < nPublicInputKeysToBeAdded.length; i++) {
        const inputs = nPublicInputKeysToBeAdded[i];
        const envName = `${inputs}_PUBLIC_INPUT_VK_POINTER`;

        if (reuseEnvAddress(hre, `${envName}`)) {
            continue;
        }

        const verificationKey = verificationKeys[inputs];
        if (!verificationKey) {
            console.log(
                `No verification key was found for ${inputs} input(s), skip adding key...`,
            );
            continue;
        }

        const encodedVerificationKey = encodeVerificationKey(verificationKey);

        const salt = hre.ethers.utils.id(
            (await hre.ethers.provider.getBlock('latest')).timestamp.toString(),
        );
        const pointer = await deployContentDeterministically(
            hre,
            encodedVerificationKey,
            salt,
        );

        process.env[`${getContractEnvVariable(hre, envName)}`] = pointer;

        console.log(
            `Verification key is added for ${inputs} input(s) at pointer: `,
            pointer,
        );
    }
};
export default func;

func.tags = ['add-verification-key', 'forest', 'protocol'];
func.dependencies = ['check-params'];
