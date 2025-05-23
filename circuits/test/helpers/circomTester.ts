// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import * as path from 'path';

import dotenv from 'dotenv';

dotenv.config({});

type Options = {
    basedir: string;
    compiler?: string;
    tmpdir?: string;
};

export const getOptions = (): Options => {
    const basedir = path.join(__dirname, '../../');
    let options: Options = {
        basedir,
    };
    if (!!process.env.CIRCOM_DOCKER) {
        const compiler = path.join(basedir, './scripts/circomDocker.sh');
        const tmpdir = path.join(basedir, './compiled/tmp/');
        options = {...options, compiler, tmpdir};
    }
    return options;
};
