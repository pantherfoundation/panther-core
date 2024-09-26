import * as path from 'path';
import {expect} from 'chai';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './../helpers/circomTester';
// TODO: Import the necessary packages here...

describe('KycKytMerkleTreeLeafIDAndRuleInclusionProver circuit', async function (this: any) {
    let kycKytMerkleTreeLeafIDAndRuleInclusionProver: any;
    // TODO: Declare all variables and their types here...

    // Use timeout if needed
    this.timeout(10000000);

    // Info: Executed once before all the test cases
    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/kycKytMerkleTreeLeafIDAndRuleInclusionProver.circom',
        );
        kycKytMerkleTreeLeafIDAndRuleInclusionProver = await wasm_tester(
            input,
            opts,
        );
    });

    // Info: Executed before each test cases
    beforeEach(async function () {
        // TODO: Declare all the variables that needs to be initialised for each test cases
    });

    // Example test case flow is below -
    /* 
    describe('Valid input signals',(){
            it(...){}
            it(...){}
            ....
    })

    describe('Invalid input signals',(){
            it(...){}
            it(...){}
            ....
    })
    */
    describe('Valid input signals', async function () {
        xit('should ...', async () => {
            // TODO: ...
        });

        xit('should ...', async () => {
            // TODO: ...
        });

        // TODO: - Add more it(...) as needed.
    });

    describe('Invalid input signals', async function () {
        xit('should ...', async () => {
            // TODO: ...
        });

        xit('should ...', async () => {
            // TODO: ...
        });

        // TODO: - Add more it(...) as needed.
    });
});
