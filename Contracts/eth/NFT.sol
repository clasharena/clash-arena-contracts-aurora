// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./../Ownable.sol";
import "./../erc-721/ERC721Enum.sol";
import "./SharedData.sol";

contract NFT is ERC721Enumerable {
    uint256 public commissions = 0;

    mapping(uint256 => SharedData.Stats) public nftStats;

    event TokenCreated(
        address owner,
        bytes hash,
        uint256 hp,
        uint256 energy,
        uint256 attack,
        uint256 defence,
        uint256 timestamp
    );

    constructor() NFTToken("Battler", "BTL"){
    }

    /**
     * @dev See {IERC721-safeMint}.
     */
    function safeMint(
        address to,
        bytes memory hash,
        uint256 hp,
        uint256 energy,
        uint256 attack,
        uint256 defence
    ) public onlyOwner {
        uint256 tokenId = totalSupply() + 1;

        internalMint(to, tokenId);

        metaHash[tokenId] = hash;
        nftStats[tokenId] = SharedData.Stats(
            hp,
            energy,
            attack,
            defence
        );

        emit TokenCreated(
            to,
            hash,
            hp,
            energy,
            attack,
            defence,
            block.timestamp
        );
    }

    /**
     * @dev See {IERC721-safeMint}.
     */
    function safeBurn(uint256 tokenId) public {
        address owner = NFTToken.ownerOf(tokenId);

        require(msg.sender == owner, "Only owner can burn");

        delete metaHash[tokenId];
        internalBurn(owner, tokenId);
    }
}
