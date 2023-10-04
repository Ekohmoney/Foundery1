// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

contract MarketPlace {
    event NFTSOLD(uint orderId);

    event NFTLISTED(uint orderId);

    struct Order {
        address owner;
        address tokenAddress;
        uint tokenId;
        uint nftPrice;
        uint deadline;
        bytes signature;
        bool active;
    }

    //mapping to check if nft is not already listed
    mapping(bytes32 => bool) public hashedToken;

    mapping(uint => Order) public allOrders;

    uint orderId;

    constructor() {}

    function getOrderHash(
        address _tokenAddress,
        uint _tokenId,
        uint _price,
        address _nftOwner,
        uint deadline
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _tokenAddress,
                    _tokenId,
                    _price,
                    _nftOwner,
                    deadline
                )
            );
    }

    function getEthSignedOrderHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
     
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function putNFTForSale(
        bytes memory _signature,
        uint _tokenId,
        address _tokenAddress,
        uint _price,
        uint _deadline
    ) public {
        //checks that the seller is the owner of the nft
        require(
            ERC721(_tokenAddress).ownerOf(_tokenId) == msg.sender,
            "Not Owner"
        );

        //checks that the seller has approves the marketplace to sell the nft
        require(
            ERC721(_tokenAddress).isApprovedForAll(msg.sender, address(this)),
            "Please approve NFT to be sold"
        );

        //checks that token address is not address zero
        require(_tokenAddress != address(0), "Zero address not allowed");

        //checks that token address is not an EOA
        require(isContract(), "Token address is an EOA");

        //require that price is greater tahn zero
        require(_price != 0, "Price must be greater than zero");

        //require that deadline is one hour later than present time
        require(
            _deadline > (block.timestamp + 3600),
            "Deadline must be one hour later than present time"
        );

        bytes32 hashedVal = hashedListing(_tokenAddress, _tokenId);

        //checks if the nft has not been listed before
        require(!hashedToken[hashedVal], "token has been listed");

        orderId++;
        Order storage newOrder = allOrders[orderId];
        newOrder.signature = _signature;
        newOrder.tokenId = _tokenId;
        newOrder.nftPrice = _price;
        newOrder.deadline = _deadline;
        newOrder.tokenAddress = _tokenAddress;
        newOrder.active = true;
        hashedToken[hashedVal] = true;

        emit NFTLISTED(orderId);
    }

    function buyNFT(uint _orderId) public payable {
        Order storage order = allOrders[orderId];
        address owner = order.owner;
        address tokenAddress = order.tokenAddress;
        uint tokenId = order.tokenId;
        uint nftPrice = order.nftPrice;
        uint deadline = order.deadline;
        bytes memory signature = order.signature;
        bool active = order.active;

        bool isVerified = verify(
            owner,
            tokenAddress,
            tokenId,
            nftPrice,
            deadline,
            signature
        );
        require(isVerified, "Invalid Signature");
        require(!active, "Listing not active");
        require(deadline < block.timestamp, "Deadline passed");
        require(
            ((msg.value == nftPrice) || (msg.value != 0)),
            "Incorrect Eth Value"
        );

        bytes32 hashedVal = hashedListing(tokenAddress, tokenId);

        //to avoid re-entrancy attack, we reset the active state to false
        active = false;
        hashedToken[hashedVal] = false;
        (bool callSuccess, ) = owner.call{value: msg.value}("");
        require(callSuccess, "NFT Purchased failed");
        ERC721(tokenAddress).safeTransferFrom(owner, msg.sender, tokenId);

        emit NFTSOLD(_orderId);
    }

    function verify(
        address _nftOwner,
        address _tokenAddress,
        uint _tokenId,
        uint _price,
        uint _deadline,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageHash = getOrderHash(
            _tokenAddress,
            _tokenId,
            _price,
            _nftOwner,
            _deadline
        );
        bytes32 ethSignedOrderHash = getEthSignedOrderHash(messageHash);

        return recoverSigner(ethSignedOrderHash, signature) == _nftOwner;
    }

    function recoverSigner(
        bytes32 ethSignedOrderHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(ethSignedOrderHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }

    //check if an account is a contract
    function isContract() private view returns (bool) {
        uint32 size;
        address a = msg.sender;
        assembly {
            size := extcodesize(a)
        }
        return (size > 0);
    }

    //function to hash token listing to avoind duplicate
    function hashedListing(
        address _tokenAddress,
        uint _tokenId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_tokenAddress, _tokenId));
    }
}
