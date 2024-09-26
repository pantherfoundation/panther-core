# Panther Protocol V1 Circuits

This repository includes the circuits that drive Panther Protocol's V1 release. Below is a brief overview of the key circuits and their functions within the protocol.

## ZAccount Registration Circuit

Files: 
* Entry Point(Driver) - circuits/mainZAccountRegistrationV1.circom
* Range Check logic - circuits/zAccountRegistrationV1Top.circom
* Core logic - circuits/zAccountRegistrationV1.circom

The ZAccount Registration Circuit is utilized during the user registration process. This circuit verifies all the details presented as part of ZAccount registration phase are valid.

## AMM - Automated Market Maker Circuit

Files: 
* Entry Point(Driver) - circuits/mainAmmV1.circom
* Range Check logic - circuits/ammV1Top.circom
* Core logic - circuits/ammV1.circom

AMM is a phase where user converts PRP(Panther Reward Points) into zZKP(shielded ZKP).
AMM circuit supports both Voucher Exchange and the Actual AMM Exchange.

Voucher Exchange - The user will exchange the voucher which has some PRP value and will get added to the user’s ZAccount’s PRP balance. This process is just the claiming of a voucher.

AMM Exchange - This is the step where the PRP gets converted into zZKP.


## Unified Z-Transaction and Z-Swap Circuit

Files for Z-Transaction: 
* Entry Point(Driver) - circuits/mainZTransactionV1.circom
* Range Check logic - circuits/zTransactionV1.circom
* Core logic - circuits/zSwapV1.circom

Files for Z-Swap:
* Entry Point(Driver) - circuits/mainZSwapV1.circom
* Range Check logic - circuits/zSwapV1Top.circom
* Core logic - circuits/zSwapV1.circom

(Note: Core logic is same for both the circuits)

This single circuit handles all core transactions(zTransaction) and it also handles swapping of tokens(zSwap).

All core protocol transactions are verified via this circuit. Those core transactions includes - deposit of assets, withdraw of assets, internal transfer of assets(within the protocol). 

Same circuit is used for verification during the swapping of the tokens.


## ZAccount Renewal Circuit

Files: 
* Entry Point(Driver) - circuits/mainZAccountRenewalV1.circom
* Range Check logic - circuits/zAccountRenewalV1Top.circom
* Core logic - circuits/zAccountRenewalV1.circom

This circuit is used when user needs to renew the zAccount.
