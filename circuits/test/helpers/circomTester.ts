import * as path from 'path';

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
    if (!process.env.CIRCOM_DOCKER) {
        const compiler = path.join(basedir, './scripts/circom-docker.sh');
        const tmpdir = path.join(basedir, './compiled/tmp/');
        options = {...options, compiler, tmpdir};
    }
    return options;
};
