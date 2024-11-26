import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

class SubgraphSetupError extends Error {
    constructor(
        message: string,
        public code: string,
    ) {
        super(message);
        this.name = 'SubgraphSetupError';
    }
}

type NetworkType = 'matic' | 'polygon-amoy';
type Address = `0x${string}`;
type BlockNumber = string;

interface ContractAddresses extends Record<string, string> {
    NETWORK: NetworkType;
    PANTHER_POOL_ADDRESS: Address;
    PANTHER_POOL_START_BLOCK: BlockNumber;
    PANTHER_FOREST_ADDRESS: Address;
    PANTHER_FOREST_START_BLOCK: BlockNumber;
    ZKP_RESERVE_CONTROLLER_ADDRESS: Address;
    ZKP_RESERVE_CONTROLLER_START_BLOCK: BlockNumber;
    VAULT_V1_ADDRESS: Address;
    VAULT_V1_START_BLOCK: BlockNumber;
    FEE_MASTER_ADDRESS: Address;
    FEE_MASTER_START_BLOCK: BlockNumber;
}

type RequiredField = keyof ContractAddresses;
const requiredFields: readonly RequiredField[] = [
    'NETWORK',
    'PANTHER_POOL_ADDRESS',
    'PANTHER_POOL_START_BLOCK',
    'PANTHER_FOREST_ADDRESS',
    'PANTHER_FOREST_START_BLOCK',
    'ZKP_RESERVE_CONTROLLER_ADDRESS',
    'ZKP_RESERVE_CONTROLLER_START_BLOCK',
    'VAULT_V1_ADDRESS',
    'VAULT_V1_START_BLOCK',
    'FEE_MASTER_ADDRESS',
    'FEE_MASTER_START_BLOCK',
] as const;

function validateAddress(
    address: string,
    fieldName: string,
): asserts address is Address {
    if (!/^0x[a-fA-F0-9]{40}$/.test(address)) {
        throw new SubgraphSetupError(
            `Invalid Ethereum address for ${fieldName}: ${address}`,
            'INVALID_ADDRESS',
        );
    }
}

function validateBlockNumber(block: string, fieldName: string): void {
    if (!/^\d+$/.test(block)) {
        throw new SubgraphSetupError(
            `Invalid block number for ${fieldName}: ${block}`,
            'INVALID_BLOCK',
        );
    }
}

function validateNetwork(network: string): asserts network is NetworkType {
    if (!['matic', 'polygon-amoy'].includes(network)) {
        throw new SubgraphSetupError(
            `Invalid network: ${network}. Must be one of: matic, polygon-amoy`,
            'INVALID_NETWORK',
        );
    }
}

function validateEnvFile(
    env: Record<string, string | undefined>,
): asserts env is ContractAddresses {
    // Check required fields
    const missingFields = requiredFields.filter(function (field) {
        return !env[field];
    });

    if (missingFields.length > 0) {
        throw new SubgraphSetupError(
            `Missing required fields in env file:\n${missingFields
                .map(f => `- ${f}`)
                .join('\n')}`,
            'MISSING_FIELDS',
        );
    }

    // Validate network
    validateNetwork(env.NETWORK!);

    // Validate addresses
    [
        'PANTHER_POOL_ADDRESS',
        'PANTHER_FOREST_ADDRESS',
        'ZKP_RESERVE_CONTROLLER_ADDRESS',
        'VAULT_V1_ADDRESS',
        'FEE_MASTER_ADDRESS',
    ].forEach(function (field) {
        validateAddress(env[field]!, field);
    });

    // Validate block numbers
    [
        'PANTHER_POOL_START_BLOCK',
        'PANTHER_FOREST_START_BLOCK',
        'ZKP_RESERVE_CONTROLLER_START_BLOCK',
        'VAULT_V1_START_BLOCK',
        'FEE_MASTER_START_BLOCK',
    ].forEach(function (field) {
        validateBlockNumber(env[field]!, field);
    });
}

function parseEnvArg(args: string[]): string {
    const envArg: string | undefined = args.find(function (arg: string) {
        return arg.startsWith('--env=');
    });

    if (!envArg) {
        throw new SubgraphSetupError(
            'Missing required argument: --env\n' +
                'Usage: ts-node setupSubgraph.ts --env=<env-file>\n' +
                'Example: ts-node setupSubgraph.ts --env=.env.staging.internal',
            'MISSING_ARG',
        );
    }

    const envFile: string = envArg.split('=')[1];
    if (!envFile) {
        throw new SubgraphSetupError(
            'Empty env file path provided\n' +
                'Usage: ts-node setupSubgraph.ts --env=<env-file>\n' +
                'Example: ts-node setupSubgraph.ts --env=.env.staging.internal',
            'INVALID_ARG',
        );
    }

    return envFile;
}

function loadEnvFile(envPath: string): ContractAddresses {
    if (!fs.existsSync(envPath)) {
        throw new SubgraphSetupError(
            `Environment file not found: ${envPath}`,
            'FILE_NOT_FOUND',
        );
    }
    const env = dotenv.parse(fs.readFileSync(envPath));
    validateEnvFile(env);
    return env;
}

function generateSubgraphConfig(
    env: ContractAddresses,
    templatePath: string,
): string {
    if (!fs.existsSync(templatePath)) {
        throw new SubgraphSetupError(
            'Template file not found: subgraph.template.yaml',
            'TEMPLATE_NOT_FOUND',
        );
    }

    let template: string = fs.readFileSync(templatePath, 'utf8');

    Object.entries(env).forEach(function ([key, value]) {
        const placeholder = `{{${key}}}`;
        while (template.includes(placeholder)) {
            template = template.replace(placeholder, value);
        }
    });

    return template;
}

function cleanup(outputPath: string): void {
    if (fs.existsSync(outputPath)) {
        fs.unlinkSync(outputPath);
    }
}

function main(): void {
    const outputPath = 'subgraph.yaml';
    try {
        const envFile = parseEnvArg(process.argv.slice(2));
        const envPath = path.resolve(process.cwd(), envFile);
        const env = loadEnvFile(envPath);
        const templatePath = path.resolve(
            process.cwd(),
            'subgraph.template.yaml',
        );
        const config = generateSubgraphConfig(env, templatePath);

        fs.writeFileSync(outputPath, config);
        console.log(`Generated subgraph.yaml for network: ${env.NETWORK}`);
    } catch (error) {
        cleanup(outputPath);
        if (error instanceof SubgraphSetupError) {
            console.error(`Setup failed: ${error.message} (${error.code})`);
        } else {
            console.error('Unexpected error:', error);
        }
        process.exit(1);
    }
}

main();
