'use strict';

function validateFirstLine(firstLine, context, node) {
    const isValidFirstLine = [
        '// SPDX-License-Identifier: BUSL-1.1',
        '// SPDX-License-Identifier: MIT',
    ].some(header => firstLine.includes(header));

    if (!isValidFirstLine) {
        context.report({
            node,
            message:
                'The first line should be "// SPDX-License-Identifier: BUSL-1.1" or "// SPDX-License-Identifier: MIT"',
            loc: {line: 1, column: 0},
            fix(fixer) {
                const correctFirstLine = '// SPDX-License-Identifier: BUSL-1.1';
                if (firstLine.startsWith('// SPDX')) {
                    return fixer.replaceTextRange(
                        [0, firstLine.length],
                        correctFirstLine,
                    );
                } else {
                    return fixer.insertTextBeforeRange(
                        [0, 0],
                        correctFirstLine + '\n',
                    );
                }
            },
        });
    }
}

const fileCopyRightTextRegExp = new RegExp(
    /SPDX-FileCopyrightText: Copyright 2021-\d+ Panther Ventures Limited Gibraltar/,
);

function validateSecondLine(secondLine, context, node) {
    const isValidSecondLine = fileCopyRightTextRegExp.test(secondLine);

    const year = new Date().getFullYear() - 2000;
    const correctSecondLine = `// SPDX-FileCopyrightText: Copyright 2021-${year} Panther Ventures Limited Gibraltar`;

    if (!isValidSecondLine) {
        context.report({
            node,
            message: `The second line should be "${correctSecondLine}"`,
            loc: {line: 2, column: 0},
            fix(fixer) {
                const sourceCode = context.getSourceCode();
                const lines = sourceCode.lines;

                if (secondLine.startsWith('// SPDX-FileCopyrightText:')) {
                    const modifiedLines = [
                        ...lines.slice(0, 1),
                        correctSecondLine,
                        ...lines.slice(2),
                    ];
                    const modifiedCode = modifiedLines.join('\n');

                    return fixer.replaceTextRange(
                        [0, sourceCode.text.length],
                        modifiedCode,
                    );
                } else {
                    const sourceCode = context.getSourceCode();
                    const lines = sourceCode.lines;

                    const modifiedLines = [
                        ...lines.slice(0, 1),
                        correctSecondLine,
                        ...lines.slice(1),
                    ];
                    const modifiedCode = modifiedLines.join('\n');

                    return fixer.replaceTextRange(
                        [0, sourceCode.text.length],
                        modifiedCode,
                    );
                }
            },
        });
    }
}

function validateThirdLine(thirdLine, context, node) {
    const isValidThirdLine = thirdLine.trim().length === 0;

    if (!isValidThirdLine) {
        context.report({
            node,
            message: `The third line should be empty`,
            loc: {line: 3, column: 0},
            fix(fixer) {
                const sourceCode = context.getSourceCode();
                const lines = sourceCode.lines;

                const modifiedLines = [
                    ...lines.slice(0, 2),
                    '',
                    ...lines.slice(2),
                ];
                const modifiedCode = modifiedLines.join('\n');

                return fixer.replaceTextRange(
                    [0, sourceCode.text.length],
                    modifiedCode,
                );
            },
        });
    }
}

module.exports = {
    'license-header': {
        meta: {
            type: 'problem',
            docs: {
                description: 'enforce header comments',
                category: 'Possible Errors',
            },
            fixable: 'code',
        },
        create: function (context) {
            const options = context.options[0] ?? {};
            const ignorePaths = options.ignorePaths || [];
            const filePath = context.getFilename();

            if (ignorePaths.some(path => filePath.includes(path))) {
                return {};
            }

            return {
                Program: function (node) {
                    const lines = context.getSourceCode().lines;
                    const firstLine = lines[0] ?? '';
                    const secondLine = lines[1] ?? '';
                    const thirdLine = lines[2] ?? '';

                    if (firstLine.startsWith('#!/usr/bin/env')) {
                        return;
                    }

                    validateFirstLine(firstLine, context, node);
                    validateSecondLine(secondLine, context, node);
                    validateThirdLine(thirdLine, context, node);
                },
            };
        },
    },
};
