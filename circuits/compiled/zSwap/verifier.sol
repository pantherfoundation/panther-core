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
    uint256 constant deltax1 = 16028006390081587602835567462064908825977535352583317239389074433042971446330;
    uint256 constant deltax2 = 1074409233559597419177695451355616999171686635298049850468282906110742390657;
    uint256 constant deltay1 = 3863553234801748370727131744704038790498526004223172525574310424316164637595;
    uint256 constant deltay2 = 4170430919210761901583273707232423276139410230997367765915106195026433606394;

    
    uint256 constant IC0x = 12864142539498379294647991813299502853589744025816655129884874212720067882477;
    uint256 constant IC0y = 5481872885854122027806477443430038402376910375939851880097764897148127031871;
    
    uint256 constant IC1x = 13896853288926063776529721880753226311978042782695407345986062466871760419171;
    uint256 constant IC1y = 9662551449612499763775843232078671887151755049060738545490736058012100473138;
    
    uint256 constant IC2x = 18542260516653278931525839621249568006839725495417472639490920947857843685702;
    uint256 constant IC2y = 15266995503381663625792059087214339818878995976254901331699754830653910261392;
    
    uint256 constant IC3x = 1576886858416523555346134404536128527896290068921003902115301816774326096676;
    uint256 constant IC3y = 8629963625620912275220433521702728023625462399281379248489460730875014411401;
    
    uint256 constant IC4x = 13200732297000185963806014839245691112656641665113276936900931314612773684402;
    uint256 constant IC4y = 11639134576241594085904511229504381835882585454338118007424591496431402822992;
    
    uint256 constant IC5x = 10578837136267018593647053222153507449353584413036923121932323563834577777413;
    uint256 constant IC5y = 4865885746092881007553907923714861654363290699598128605160045880639245730672;
    
    uint256 constant IC6x = 15139217893314840381001824694093521548766766593076807608249105355325268547362;
    uint256 constant IC6y = 12551107507045672350606552218293595739095865935727507872643867535361177178100;
    
    uint256 constant IC7x = 7863345008425939649204892568836218404820831942373321491347465365659285353656;
    uint256 constant IC7y = 15553751412337101196098090327628928784785393768545862864079255298770857740833;
    
    uint256 constant IC8x = 189629606680975584367089854418877577189566626285506028782759658116924125177;
    uint256 constant IC8y = 7371061856796085934940483094334187907582016737063948724858748822842368857798;
    
    uint256 constant IC9x = 5706473969684094627327518518170160368450687572526586923218338908494963759252;
    uint256 constant IC9y = 11643458625586389576404752013127946388453803407159953468461657812762900690157;
    
    uint256 constant IC10x = 13865787231466906347780104527106620490501681006572941062408944291004677863801;
    uint256 constant IC10y = 21573838166009472764811864343431430877568640406380619381352121188860803887952;
    
    uint256 constant IC11x = 9893621056431060329434618225781711996405598299977666549166109745816534731261;
    uint256 constant IC11y = 21263542377341355693624692269862388245070388308185974544871425768820742908191;
    
    uint256 constant IC12x = 11332945928946084835514764693077524334910926998045544960181599548932762959628;
    uint256 constant IC12y = 19365521619007943295457796487777991842868569684187793153004464036324963637372;
    
    uint256 constant IC13x = 1008242911519445285007520808150476364114690113183809472087456218699276753224;
    uint256 constant IC13y = 5610659500227522824543179517268624147203902947903472782207179988645507335756;
    
    uint256 constant IC14x = 19441573254405131839066199128495506256125919157591210465245587225336694456176;
    uint256 constant IC14y = 8669168782620571078294234131188971007928875058900535083275846892459550917976;
    
    uint256 constant IC15x = 6597971394173916986015289638525280921144793314497486059399512828502593624375;
    uint256 constant IC15y = 11177289614004685550932115635995599218019689556219396087868075462054930892456;
    
    uint256 constant IC16x = 18615431364132474769193419729833831681611736013642173381736044359916516154422;
    uint256 constant IC16y = 17005892613863279654859934651743769658703913822264168661507635206720351824544;
    
    uint256 constant IC17x = 16588647007165790438683020026700374539594638691393333405341192424730733468376;
    uint256 constant IC17y = 2165785199226485718737397767887365939007870689849092795316640001260912094308;
    
    uint256 constant IC18x = 4914439139828100234204187734571663055405772914812972844720293669460167299685;
    uint256 constant IC18y = 8456287181238523721105622075466038967808740540443694093031693029724714610767;
    
    uint256 constant IC19x = 689371579065239674000992968321613213806208144408074968159998163569892152464;
    uint256 constant IC19y = 432728983004039090593559022862814482690377322935088887671480272632664685396;
    
    uint256 constant IC20x = 4119235718489908882553334514605871577004614925181071973242445992991654275089;
    uint256 constant IC20y = 11393476582320111091746483175454449274644134353833603749874542558838025710134;
    
    uint256 constant IC21x = 12194736855184319353109916394776419264501806347921442858529764949808244792219;
    uint256 constant IC21y = 2556620858005223218400830981305779788617561466325737470594651012537999678184;
    
    uint256 constant IC22x = 609367081601852172479622837080021599596216160696333064959502887327164980261;
    uint256 constant IC22y = 10368624861346818933972293090754333840960911641297427644025818721220460557901;
    
    uint256 constant IC23x = 9328699359783108576536890675646822876702050650725797642846739816612065917970;
    uint256 constant IC23y = 16791976455370177229346206187286842863118255117763859903187206630992322963204;
    
    uint256 constant IC24x = 13776003125532715572696626713544454433818334507704960136029480008165953641200;
    uint256 constant IC24y = 4738414605536457117801240157476030505410866488618847689754794806064475232564;
    
    uint256 constant IC25x = 7124132950707642951863006481118727118218231894076479739617316264447235415944;
    uint256 constant IC25y = 21369948570392928116741079341325077831218178081726511587027088710884079901624;
    
    uint256 constant IC26x = 18673340359113111275484147299355879219942564083055027150073232124908986193719;
    uint256 constant IC26y = 2736446144116068677884661398171792044529766515637876128485941334399744413083;
    
    uint256 constant IC27x = 15748112764659502764405368343383007370587863376996627392338423136010940100886;
    uint256 constant IC27y = 14165668247750978631682352186734800858523673204212330479731348454252596934398;
    
    uint256 constant IC28x = 5059417123497939551191689936983626910680852350352486437780455891144455922270;
    uint256 constant IC28y = 21866863303331903703086886045290421166712829607508037189395210129224095055587;
    
    uint256 constant IC29x = 15455237053940395433068392489513812763941476024443334020444363109075407308801;
    uint256 constant IC29y = 10299416614614155405157746425319956048631251085901741050903784214328807523038;
    
    uint256 constant IC30x = 21452746366302635521107770655264332828375031552847879308279735423253873771329;
    uint256 constant IC30y = 71489521032265657795025848894088109594704408366651285880795662838689427142;
    
    uint256 constant IC31x = 16371516699982158234531084502653838375621327500091923971598226508557850753915;
    uint256 constant IC31y = 13265767918986171434420695383198550110796802493907367658070694463414691558697;
    
    uint256 constant IC32x = 4253644987099630028312324901682556849273669893010053078362692691520220703108;
    uint256 constant IC32y = 16365896565776453990602308025221687060066633291038141927258057126147552626680;
    
    uint256 constant IC33x = 21777003144042876043797106431079450667432297293943180842611221990419646360787;
    uint256 constant IC33y = 2286915696345794034007390043008390041313983360949611576113846346826185193352;
    
    uint256 constant IC34x = 11271586701407074357738308624958106486729264126760927441314326688956205007158;
    uint256 constant IC34y = 21779159883336265951279932953935261885242993325971573842838975153040480456638;
    
    uint256 constant IC35x = 11753419859350504218445093927522999685038139670002333032758235579443984134887;
    uint256 constant IC35y = 1426113320472446303306661493392660470641503000195378449636245808712564973635;
    
    uint256 constant IC36x = 12043131315956122879645197710376497323166668921812177106879376280731631233348;
    uint256 constant IC36y = 18008351655390844152209658452320287540959979781798824110051543561712871308405;
    
    uint256 constant IC37x = 4964027256821975810925596262190773402506158440534218819187548699740467089846;
    uint256 constant IC37y = 7227804850571003884350250787749110395950853953326013515027259712794905934664;
    
    uint256 constant IC38x = 8329264149229815642268722106467042448902828593891787737580156113397461199191;
    uint256 constant IC38y = 12795914267696476105105286995531572117564735560833308376783680516621244640896;
    
    uint256 constant IC39x = 6657833401657157991495946698352943664393308025253920222350059577450734625657;
    uint256 constant IC39y = 5891667309054664382976157318374317118792633545238417314231625443509847352444;
    
    uint256 constant IC40x = 13406858134584782121859797118079957971599026695245117678398707731649990718667;
    uint256 constant IC40y = 14593875870159494187639898125647743388106470766271221297982573462569029350152;
    
    uint256 constant IC41x = 17360448222455363564157709650698194335938659718515612731118530290315565470524;
    uint256 constant IC41y = 14288786011862538720044941849055027132835613734995670056776608315868923419891;
    
    uint256 constant IC42x = 20635691868314174971181825611611025477738389063578483469401644304049663465038;
    uint256 constant IC42y = 18800727605028098828760810511765085106213553909501015693027181786164088124264;
    
    uint256 constant IC43x = 15094176817491683437073514278541003424698842481451522648206294951206274312158;
    uint256 constant IC43y = 14823153223741943245547261304814454092275289388951390397115997240435131804413;
    
    uint256 constant IC44x = 2940166331369646589293536012444290665574052890221785166111539422902632424661;
    uint256 constant IC44y = 1400429555760958159367815347057827625890583077702413277235253427182874905304;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[44] calldata _pubSignals) public view returns (bool) {
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
                
                g1_mulAccC(_pVk, IC40x, IC40y, calldataload(add(pubSignals, 1248)))
                
                g1_mulAccC(_pVk, IC41x, IC41y, calldataload(add(pubSignals, 1280)))
                
                g1_mulAccC(_pVk, IC42x, IC42y, calldataload(add(pubSignals, 1312)))
                
                g1_mulAccC(_pVk, IC43x, IC43y, calldataload(add(pubSignals, 1344)))
                
                g1_mulAccC(_pVk, IC44x, IC44y, calldataload(add(pubSignals, 1376)))
                

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
            
            checkField(calldataload(add(_pubSignals, 1280)))
            
            checkField(calldataload(add(_pubSignals, 1312)))
            
            checkField(calldataload(add(_pubSignals, 1344)))
            
            checkField(calldataload(add(_pubSignals, 1376)))
            
            checkField(calldataload(add(_pubSignals, 1408)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
