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
    uint256 constant deltax1 = 19319169288847232791293550503797121572649380712555577121415867739714655834597;
    uint256 constant deltax2 = 13860308735406292710616414021140398857816500497106689518185409332375519109730;
    uint256 constant deltay1 = 5343431382541658089194610030331161016806717477707157053204008221785600281762;
    uint256 constant deltay2 = 21838857531527918667457680342938988576724200473864806342998382354895162696377;

    
    uint256 constant IC0x = 19260289431654654115509880428660401215727649119219206519851383152420275511467;
    uint256 constant IC0y = 13133550605507966449905112772913829999980941805505684932532665235551528959577;
    
    uint256 constant IC1x = 21031403297151041949517663652681690862119682981813938458299650293509286564270;
    uint256 constant IC1y = 15841039629686635971989226817939724918967858147745155913561878674172014501146;
    
    uint256 constant IC2x = 21558179337713887189974613343552349072202304370423615129175681980491657757888;
    uint256 constant IC2y = 13196386648555609217914195074728260280289595376048494218598457023211247410356;
    
    uint256 constant IC3x = 3467687043328171406442802438392806588116601337814415997896285744268582197862;
    uint256 constant IC3y = 2741974074547742948950936650360150355102461076892218017625635510082287249126;
    
    uint256 constant IC4x = 15711827997574485984147986588304993758330826810076190228990259207065380260762;
    uint256 constant IC4y = 18393113505913296131528026604832759435640047751916280523548195599964012492541;
    
    uint256 constant IC5x = 20500985058806035403954261419177095099527726125888276411525629510935003790466;
    uint256 constant IC5y = 12653377426642041031025997467663731539227095957026041563711917153005567520172;
    
    uint256 constant IC6x = 9325548552029053305566719394561318329627888069266609189367053253053946660978;
    uint256 constant IC6y = 18466727369212881917769870058588709990730744436012332393088215700289898222152;
    
    uint256 constant IC7x = 579608944712137558016455845765653896745474174298724948768924595482700871023;
    uint256 constant IC7y = 9316150848814620822277967176491110316068038448825611942337264328258792942494;
    
    uint256 constant IC8x = 20688962159495260605403981354154629892923418510677496438802554522370134960586;
    uint256 constant IC8y = 20931422173351702848002151291659099710471447646157866964552635427530999863815;
    
    uint256 constant IC9x = 3587898599025775590306394835176546644940798877712782481749108554742305107931;
    uint256 constant IC9y = 15410973278871301222101084250832726663548847288778587940513650556149546351678;
    
    uint256 constant IC10x = 8409492958767113737603003736726618719139719499603414912056626548058198923131;
    uint256 constant IC10y = 21507422881265913014190835848285349818257608065497939236314799954434718772918;
    
    uint256 constant IC11x = 10156000673902212928382175173658863531931807963181674514501614475140207370111;
    uint256 constant IC11y = 20383441187911766734080231918031022540329215309790307998767409715578726271490;
    
    uint256 constant IC12x = 13488984979181461255131784341439986415932938599346773576435581933342752914051;
    uint256 constant IC12y = 5913851959338487099818519329143533976362145646041535621529444815784747914061;
    
    uint256 constant IC13x = 16395415576566041926164366415076177269340274499555782130066116765846447907292;
    uint256 constant IC13y = 21576114811111559582101449730164994774108899427271854007246394720534788118701;
    
    uint256 constant IC14x = 9811569942868488427284512611814406949251629398727784986306569452259013063152;
    uint256 constant IC14y = 16232512081389832201508186204660228572197947538992786108516557095226945218137;
    
    uint256 constant IC15x = 9621654920195340354659300446006367568088787503299184409807614252142203762994;
    uint256 constant IC15y = 18464259987394037808418639371145713560516812447919122951815174463753983641855;
    
    uint256 constant IC16x = 1866216306010264354299400542291376873121999996475213061246750411507390868413;
    uint256 constant IC16y = 10757175057199533345847824248472603626487135143992193093526434218711348272668;
    
    uint256 constant IC17x = 18750724291055122806231289986504479558246522094841130910369549399326389117652;
    uint256 constant IC17y = 11986410228431835249347277271618627841439242205941889740540248631607819750065;
    
    uint256 constant IC18x = 4655854673298265644331343822625167571576090673070256066222449759024251610537;
    uint256 constant IC18y = 16688103908263287490102569418730006623937519440912825464518317635847590413918;
    
    uint256 constant IC19x = 3325040288439866754990514551913462676796879555121015975491504777844219877624;
    uint256 constant IC19y = 12845900849316091378537210452844994957067091364354185417092417235883791932720;
    
    uint256 constant IC20x = 6396151431380698500430491216417865875685499399294540438084134979218110565505;
    uint256 constant IC20y = 11633875940445146708311670405909998880546695273189598515169164904438537190553;
    
    uint256 constant IC21x = 11349003126107881803713936156446624619206942647694364607660381504574793291273;
    uint256 constant IC21y = 19304425771339317595575753718362509795645095342623437891360280228827363897247;
    
    uint256 constant IC22x = 5006727186916243094041269550337701055938590021832970814237061555752469093506;
    uint256 constant IC22y = 12135735637547591351988901660125745475679595895092236515313835399139668811449;
    
    uint256 constant IC23x = 15990057159833382960232630288306650346501082306886069314914374600158097636948;
    uint256 constant IC23y = 18146153296092233900237883692386232475492716078189096141199729377456566567926;
    
    uint256 constant IC24x = 16887081242992101962451755202820512663334151584459348800823041159453507134957;
    uint256 constant IC24y = 2215514794852649135575092136475653021376168762236693470442152359119560395742;
    
    uint256 constant IC25x = 17429165424661705397477285219268034725835646842749475056180389974279758522666;
    uint256 constant IC25y = 13411987508894657064527387353974927855817795368369771491733298446185189616269;
    
    uint256 constant IC26x = 10078764083773553111927974356816680533407653495927695958635808547522695686924;
    uint256 constant IC26y = 9805481453719977792060695950987513061080472128038771359775067860112362588441;
    
    uint256 constant IC27x = 6225071736217050059658347986668991745567030640540222336230678603938702094358;
    uint256 constant IC27y = 2656681506594502934562591539915082801822358643784708900633417832712394881401;
    
    uint256 constant IC28x = 1144581597260713867714170749926748904887788913465332873481739283069506400061;
    uint256 constant IC28y = 9993885715439162425744669054614287024668694186436952485422013021562498734708;
    
    uint256 constant IC29x = 2906047830878476967990270022213918544215451476560474263445713251297804608985;
    uint256 constant IC29y = 5999480411446333404847511634766874687662669919366091643082098173932396315707;
    
    uint256 constant IC30x = 16966833731075945134462899326169016150713323314245469641396914105936484740658;
    uint256 constant IC30y = 1363872385320056366656490715435037832125177001608956493538826220136725888474;
    
    uint256 constant IC31x = 15508366854295490965505597177014488070154098043788831768248523836777413101714;
    uint256 constant IC31y = 2326521122012356122167706591532129349236502898812618735521108842535772652893;
    
    uint256 constant IC32x = 15588001382677395765193815565935173253744579367738010164882636875774739905644;
    uint256 constant IC32y = 9771801587015232052691967167910644614939999202412958725230807165539612116184;
    
    uint256 constant IC33x = 13941438942900728201871394286159858121915441524077339746405134520539700974100;
    uint256 constant IC33y = 18471419454557809799687325479079616730620497299519317915900031954479084285700;
    
    uint256 constant IC34x = 5964492722809711922248394994169779560700831267713048304082705658853927576654;
    uint256 constant IC34y = 5616922493525675364629217022283950746316627912289403974416193450455329296773;
    
    uint256 constant IC35x = 5247801120442955608615450444760441171202268582988225136889026027857165536956;
    uint256 constant IC35y = 16728537756963336657026755628471349037323694661400891804494515897001674127365;
    
    uint256 constant IC36x = 5722160496740180449268134917049451976378272945614111879862613532054215002172;
    uint256 constant IC36y = 5985363253891729232300958313654289780168208171070469352136521857287777259684;
    
    uint256 constant IC37x = 10513520944640988398366796560523429177448408230892151628710275284874216047070;
    uint256 constant IC37y = 3181458651061162463430307111826373333674251386770904314809875866426925497055;
    
    uint256 constant IC38x = 13444093404493282719617266751629220930326940838599018383816460944095903201910;
    uint256 constant IC38y = 10499990418421886185718300161925362932925098674238927374591574069240348231621;
    
    uint256 constant IC39x = 8509229210373799042411874991714997628589251106245686811014341410664879262977;
    uint256 constant IC39y = 8328774538638249435909223612654726745698649195105721736518304526812413234782;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[39] calldata _pubSignals) public view returns (bool) {
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
                
                g1_mulAccC(_pVk, IC20x, IC20y, calldataload(add(pubSignals, 608)))
                
                g1_mulAccC(_pVk, IC21x, IC21y, calldataload(add(pubSignals, 640)))
                
                g1_mulAccC(_pVk, IC22x, IC22y, calldataload(add(pubSignals, 672)))
                
                g1_mulAccC(_pVk, IC23x, IC23y, calldataload(add(pubSignals, 704)))
                
                g1_mulAccC(_pVk, IC24x, IC24y, calldataload(add(pubSignals, 736)))
                
                g1_mulAccC(_pVk, IC25x, IC25y, calldataload(add(pubSignals, 768)))
                
                g1_mulAccC(_pVk, IC26x, IC26y, calldataload(add(pubSignals, 800)))
                
                g1_mulAccC(_pVk, IC27x, IC27y, calldataload(add(pubSignals, 832)))
                
                g1_mulAccC(_pVk, IC28x, IC28y, calldataload(add(pubSignals, 864)))
                
                g1_mulAccC(_pVk, IC29x, IC29y, calldataload(add(pubSignals, 896)))
                
                g1_mulAccC(_pVk, IC30x, IC30y, calldataload(add(pubSignals, 928)))
                
                g1_mulAccC(_pVk, IC31x, IC31y, calldataload(add(pubSignals, 960)))
                
                g1_mulAccC(_pVk, IC32x, IC32y, calldataload(add(pubSignals, 992)))
                
                g1_mulAccC(_pVk, IC33x, IC33y, calldataload(add(pubSignals, 1024)))
                
                g1_mulAccC(_pVk, IC34x, IC34y, calldataload(add(pubSignals, 1056)))
                
                g1_mulAccC(_pVk, IC35x, IC35y, calldataload(add(pubSignals, 1088)))
                
                g1_mulAccC(_pVk, IC36x, IC36y, calldataload(add(pubSignals, 1120)))
                
                g1_mulAccC(_pVk, IC37x, IC37y, calldataload(add(pubSignals, 1152)))
                
                g1_mulAccC(_pVk, IC38x, IC38y, calldataload(add(pubSignals, 1184)))
                
                g1_mulAccC(_pVk, IC39x, IC39y, calldataload(add(pubSignals, 1216)))
                

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
            
            checkField(calldataload(add(_pubSignals, 640)))
            
            checkField(calldataload(add(_pubSignals, 672)))
            
            checkField(calldataload(add(_pubSignals, 704)))
            
            checkField(calldataload(add(_pubSignals, 736)))
            
            checkField(calldataload(add(_pubSignals, 768)))
            
            checkField(calldataload(add(_pubSignals, 800)))
            
            checkField(calldataload(add(_pubSignals, 832)))
            
            checkField(calldataload(add(_pubSignals, 864)))
            
            checkField(calldataload(add(_pubSignals, 896)))
            
            checkField(calldataload(add(_pubSignals, 928)))
            
            checkField(calldataload(add(_pubSignals, 960)))
            
            checkField(calldataload(add(_pubSignals, 992)))
            
            checkField(calldataload(add(_pubSignals, 1024)))
            
            checkField(calldataload(add(_pubSignals, 1056)))
            
            checkField(calldataload(add(_pubSignals, 1088)))
            
            checkField(calldataload(add(_pubSignals, 1120)))
            
            checkField(calldataload(add(_pubSignals, 1152)))
            
            checkField(calldataload(add(_pubSignals, 1184)))
            
            checkField(calldataload(add(_pubSignals, 1216)))
            
            checkField(calldataload(add(_pubSignals, 1248)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
