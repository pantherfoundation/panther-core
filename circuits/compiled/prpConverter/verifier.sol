// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract Groth16Verifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 20491192805390485299153009773594534940189261866228447918068658471970481763042;
    uint256 constant alphay  = 9383485363053290200918347156157836566562967994039712273449902621266178545958;
    uint256 constant betax1  = 4252822878758300859123897981450591353533073413197771768651442665752259397132;
    uint256 constant betax2  = 6375614351688725206403948262868962793625744043794305715222011528459656738731;
    uint256 constant betay1  = 21847035105528745403288232691147584728191162732299865338377159692350059136679;
    uint256 constant betay2  = 10505242626370262277552901082094356697409835680220590971873171140371331206856;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 3129014089571726435638192008189529879967130524838655336058618086484541728152;
    uint256 constant deltax2 = 13737252632429980472655685257075818161399722075251202009675819136764684131464;
    uint256 constant deltay1 = 4999242194464295254789369670895401661035907709099948143158630427266311260972;
    uint256 constant deltay2 = 15699979578116947368514725384054810828212752439970792646768781905283235896050;

    
    uint256 constant IC0x = 9950185298578929189984634080112347293147381252114584952665802968829509307314;
    uint256 constant IC0y = 10701284081317458879149450080294483169675359319744834942568856004392633634939;
    
    uint256 constant IC1x = 17243090994861809928576135367513489670098518406242216328244218789435206687064;
    uint256 constant IC1y = 7687504650408648418870853350190858611642887840097421731425578589368994054609;
    
    uint256 constant IC2x = 14003586363260033371994949986365571619680573399969057616904926063062054362964;
    uint256 constant IC2y = 13772600794001469572866588737949491930401252999749830852620499696662069042663;
    
    uint256 constant IC3x = 14354325514125395241200930525674564940189494115989825523000500513489470818074;
    uint256 constant IC3y = 4751038180765403749918849254109034538270062911564514976732690552943524580137;
    
    uint256 constant IC4x = 19003086709688453764073213977750298778327669471939394402085986085885679331915;
    uint256 constant IC4y = 8617443426570995034881919413163174780899228885656842362157970127889341758673;
    
    uint256 constant IC5x = 19068733400963615252568526210804891208462909283007100456084618329657810164823;
    uint256 constant IC5y = 4541601935075781586222713743926003806195841234582780453368735557966324584440;
    
    uint256 constant IC6x = 19038619234913073229640010569507390930221040483175349379892984470220254687343;
    uint256 constant IC6y = 4377715022410437190850522123175831191033693929274759397235847560378232364521;
    
    uint256 constant IC7x = 4741233323923780009228680648707314898865600620648500205221566057507345156940;
    uint256 constant IC7y = 9064691562785874076103665245879904662988869433067370726947142829100302422943;
    
    uint256 constant IC8x = 19444853748260403429671605655623662251676108569560739673846378196506086791719;
    uint256 constant IC8y = 9778178302069777091137002228418225398564500856902077842572274704484371963470;
    
    uint256 constant IC9x = 12320116323323521031327103531077349389271905306184201071334988679805519984017;
    uint256 constant IC9y = 2948764081411164285048910692469979641983069257609465452931282773055231108599;
    
    uint256 constant IC10x = 11599451628993879638794681240641735664613211599634622913041930008126596013582;
    uint256 constant IC10y = 6887425958647657093005820579211510238811710423143318443379910892942019387144;
    
    uint256 constant IC11x = 4479443529355722772812282426850106620185055717101063752101714021535644445200;
    uint256 constant IC11y = 12921564823444050656870321358643358445164562195236059414342350607942846975814;
    
    uint256 constant IC12x = 8884944501243827785268138969161905345358746031824333365805116301179526009970;
    uint256 constant IC12y = 5704090182683780070243890540369971250202252985094873491842244841926990821950;
    
    uint256 constant IC13x = 289796054360110538079632223798426323351753630243417381113818027375367128249;
    uint256 constant IC13y = 16984370703830836107882742406549929316579784024184823623952629884983483750191;
    
    uint256 constant IC14x = 13694127408187191157592679466974352344029572171149104555385545692772475213302;
    uint256 constant IC14y = 8391722961489200575167143734279654246164212246047494635324044199133582957298;
    
    uint256 constant IC15x = 1217045909090216403997837258120903457292872897999262191911356935886124159988;
    uint256 constant IC15y = 19657937887754795677803765952659378896498761110266045600539067004264036078793;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[15] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                
                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))
                
                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))
                
                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))
                
                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))
                
                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))
                
                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))
                
                g1_mulAccC(_pVk, IC10x, IC10y, calldataload(add(pubSignals, 288)))
                
                g1_mulAccC(_pVk, IC11x, IC11y, calldataload(add(pubSignals, 320)))
                
                g1_mulAccC(_pVk, IC12x, IC12y, calldataload(add(pubSignals, 352)))
                
                g1_mulAccC(_pVk, IC13x, IC13y, calldataload(add(pubSignals, 384)))
                
                g1_mulAccC(_pVk, IC14x, IC14y, calldataload(add(pubSignals, 416)))
                
                g1_mulAccC(_pVk, IC15x, IC15y, calldataload(add(pubSignals, 448)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            
            checkField(calldataload(add(_pubSignals, 32)))
            
            checkField(calldataload(add(_pubSignals, 64)))
            
            checkField(calldataload(add(_pubSignals, 96)))
            
            checkField(calldataload(add(_pubSignals, 128)))
            
            checkField(calldataload(add(_pubSignals, 160)))
            
            checkField(calldataload(add(_pubSignals, 192)))
            
            checkField(calldataload(add(_pubSignals, 224)))
            
            checkField(calldataload(add(_pubSignals, 256)))
            
            checkField(calldataload(add(_pubSignals, 288)))
            
            checkField(calldataload(add(_pubSignals, 320)))
            
            checkField(calldataload(add(_pubSignals, 352)))
            
            checkField(calldataload(add(_pubSignals, 384)))
            
            checkField(calldataload(add(_pubSignals, 416)))
            
            checkField(calldataload(add(_pubSignals, 448)))
            
            checkField(calldataload(add(_pubSignals, 480)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
