// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

export const TokenType = {
    Erc20: ethers.BigNumber.from('0x00'),
    Erc721: ethers.BigNumber.from('0x10'),
    Erc1155: ethers.BigNumber.from('0x11'),
    Native: ethers.BigNumber.from('0xFF'),
    Erc2612: ethers.BigNumber.from('0x13'),
    unknown: ethers.BigNumber.from('0x99'),
};
