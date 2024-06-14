// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

export async function processPairs<T extends any[]>(
    array: string[],
    fn: (pair: [string, string], ...args: T) => void,
    ...args: T
) {
    for (let i = 0; i < array.length; i++) {
        for (let j = i + 1; j < array.length; j++) {
            const pair: [string, string] = [array[i], array[j]];
            await fn(pair, ...args);
            const reversePair: [string, string] = [array[j], array[i]];
            fn(reversePair, ...args);
        }
    }
}

export async function processPairsWithParams<T extends any[]>(
    array: string[],
    paramsArray: string[],
    fn: (
        pair: [string, string],
        pairParams: [string, string],
        ...args: T
    ) => void,
    ...args: T
) {
    if (array.length !== paramsArray.length) {
        throw new Error('Array and paramsArray must be of the same length');
    }

    for (let i = 0; i < array.length; i++) {
        for (let j = i + 1; j < array.length; j++) {
            const pair: [string, string] = [array[i], array[j]];
            const pairParams: [string, string] = [
                paramsArray[i],
                paramsArray[j],
            ];
            await fn(pair, pairParams, ...args);
        }
    }
}
