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
    uint256 constant deltax1 = 20027533911484740106930570979329599335084894371265145163100730465224062787709;
    uint256 constant deltax2 = 3608957881765405720202724257894998836964757500249363655779848261038036934006;
    uint256 constant deltay1 = 8570427395822737731639551363969585760585210572012928227267327583539694869730;
    uint256 constant deltay2 = 858047839749007273497330000654027573164795328454635052012578622300432306467;

    
    uint256 constant IC0x = 16055757734288690485810689101973655169936273072030631317744069603620990200912;
    uint256 constant IC0y = 15835214572713871503185413834493989784792942084935759227683248298699342717519;
    
    uint256 constant IC1x = 9524958355033551099462007776467407391351797773479961939150998442457902975916;
    uint256 constant IC1y = 18324009168165271937896311788583035399384299456409248055116448181510136928418;
    
    uint256 constant IC2x = 10992878002041641494578847208876716595543310807848803557126218399928663027163;
    uint256 constant IC2y = 9966756603842976632492307774951207290402274669879120438488324877504785442138;
    
    uint256 constant IC3x = 15202344846884216382862800779152328719644807815853164235835036900065701575773;
    uint256 constant IC3y = 2977690673275883187210849444557139752561675353589706601431235430318393177615;
    
    uint256 constant IC4x = 17103002461456872454956056727265433549014374280451975549958873735993790752299;
    uint256 constant IC4y = 16293447592248572755411519737057210426432768702137510779355096503508635621224;
    
    uint256 constant IC5x = 14027695719820188433822603421330694252039999074979677070107998919094286626261;
    uint256 constant IC5y = 19574526916826535683648138881538257336998585115227438967879952273214176704696;
    
    uint256 constant IC6x = 19409167232862436915504251286518272172524188427502160104580716559017097766704;
    uint256 constant IC6y = 9141072229957910039057033891072990771709880333398087697228393015719073910611;
    
    uint256 constant IC7x = 20605983233181313656683300049473979903891909300420541187446001377447670311053;
    uint256 constant IC7y = 12998701316280390522890721883709212163596725867461098933336563385253975130560;
    
    uint256 constant IC8x = 4010688967029523968953377524261251615043940162551474554605875543181753219505;
    uint256 constant IC8y = 12008649899945384619203040343881245902462390418769164561048111693052318160193;
    
    uint256 constant IC9x = 18345413858835357983915771295072984984233361999545250406436348788667523689667;
    uint256 constant IC9y = 8359547578752053166823712242311247792168166326787117094855758053255307447391;
    
    uint256 constant IC10x = 3774551398381017715616761191930887353232241802545991699085309883765267669333;
    uint256 constant IC10y = 10007311770523699850815687572939901843074512535964468368081400121760269413741;
    
    uint256 constant IC11x = 5623462663282382734930812396769589018871258551023756115855256373868449494340;
    uint256 constant IC11y = 12947404835778076304686717194874398120221220834472529880194178222081241137728;
    
    uint256 constant IC12x = 6100898315397682039697806192437720389120221215234797601107924486011143658983;
    uint256 constant IC12y = 9440781193189085099363006702454147688695338316677458559775112302324074536167;
    
    uint256 constant IC13x = 2376212608164001218736333905605578879556546076356858297898481389769501203088;
    uint256 constant IC13y = 2655445121939178138685179883471022596118006757579720843167223916241276978055;
    
    uint256 constant IC14x = 5081558145644341301749900273044432904743786139955930496731837729108670135704;
    uint256 constant IC14y = 18435604863126077026308291065980751218947731303292758648818591622508892240488;
    
    uint256 constant IC15x = 19170506331799931831402403525545596121217360262510540049656351125120520731485;
    uint256 constant IC15y = 14876232580683717087413683745485102482372550616888010779282705840919186142502;
    
    uint256 constant IC16x = 13282458418404091299233448026811866286781948666699338936169628586298806305539;
    uint256 constant IC16y = 8547869490594836153046237793078428696080917436855963395724150475369352518072;
    
    uint256 constant IC17x = 21483410573940245942561151494265696732386383046437083773361551808742055535191;
    uint256 constant IC17y = 13734373928753832826642163517069210126729904683079879526457236428445258758647;
    
    uint256 constant IC18x = 15240854781465454628343704689831316873821269035168047819462151087781381761921;
    uint256 constant IC18y = 6687803364745292800311479533873697829414294272332756098292710016564709758306;
    
    uint256 constant IC19x = 5578709861189776272056552124610894366208847861004264187017424587307607635812;
    uint256 constant IC19y = 3733736442742089148003239354902695021246237299214186710725916532571445246212;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[19] calldata _pubSignals) public view returns (bool) {
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
                
                g1_mulAccC(_pVk, IC16x, IC16y, calldataload(add(pubSignals, 480)))
                
                g1_mulAccC(_pVk, IC17x, IC17y, calldataload(add(pubSignals, 512)))
                
                g1_mulAccC(_pVk, IC18x, IC18y, calldataload(add(pubSignals, 544)))
                
                g1_mulAccC(_pVk, IC19x, IC19y, calldataload(add(pubSignals, 576)))
                

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
            
            checkField(calldataload(add(_pubSignals, 512)))
            
            checkField(calldataload(add(_pubSignals, 544)))
            
            checkField(calldataload(add(_pubSignals, 576)))
            
            checkField(calldataload(add(_pubSignals, 608)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
