jest.setTimeout(90000)
const Koa = require('koa')
import * as path from 'path'
import * as fs from 'fs'
import * as childProcess from 'child_process'
const ff = require('ffjavascript')
const stringifyBigInts = ff.utils.stringifyBigInts
const PORT = 9000
const HOST = 'http://localhost:' + PORT

import {
    genWitness,
    getSignalByName,
} from './utils'

describe('Witness generation', () => {

    test('the gen_witness method should return a valid witness', async () => {
        const circuit = 'poseidon'
        const inputs = stringifyBigInts({
            in: [BigInt(1), BigInt(2)],
            expectedHash: BigInt('0x115cc0f5e7d690413df64c6b9662e9cf2a3617f2743245519e19607a4417189a'),
        })

        const witness = await genWitness(circuit, inputs, HOST)
        const expectedOut = BigInt(await getSignalByName(circuit, witness, 'main.out', HOST)).toString(16)
        expect(expectedOut).toEqual('115cc0f5e7d690413df64c6b9662e9cf2a3617f2743245519e19607a4417189a')
    })

    test('the gen_witness method should return an error if the inputs are wrong', async () => {
        expect.assertions(1)
        const circuit = 'poseidon'
        const inputs = stringifyBigInts({
            in: [BigInt(1), BigInt(2)],
            expectedHash: BigInt(1234), // incorrect hash value
        })

        try {
            const witness = await genWitness(circuit, inputs, HOST)
        } catch {
            expect(true).toBeTruthy()
        }
    })

    test('the gen_witness method should return an error if an input is missing', async () => {
        expect.assertions(1)
        const circuit = 'poseidon'
        const inputs = stringifyBigInts({
            in: [BigInt(1), BigInt(2)],
        })

        try {
            const witness = await genWitness(circuit, inputs, HOST)
        } catch {
            expect(true).toBeTruthy()
        }
    })
})
