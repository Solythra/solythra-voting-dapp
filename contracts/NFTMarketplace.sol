// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

interface IMultiSigTreasury {
    function approveTransaction(address recipient, uint256 amount) external;
}

contract NFTMarketplace is ERC721, Ownable, Pausable, IERC2981 {
    uint256 public nextTokenId;
    address public mintiumToken;
    address public treasury;
    uint256 public mintPrice = 100 * 10**18; // Default 100 MNTM
    uint256 public tradingFee = 250; // 2.5% fee on sales (in basis points)
    uint256 public listingDuration = 30 days; // Default listing expiration
    uint256 public royaltyFee = 500; // 5% creator royalty (in basis points)

    struct Listing {
        address seller;
        uint256 price;
        uint256 expiration;
        bool isListed;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => address) public creators;
    IMultiSigTreasury public treasuryContract;

    event NFTMinted(address indexed owner, uint256 tokenId);
    event NFTListed(uint256 tokenId, uint256 price, uint256 expiration);
    event NFTPurchased(uint256 tokenId, address buyer);
    event NFTListingCancelled(uint256 tokenId);
    event MintPriceUpdated(uint256 newPrice);
    event TradingFeeUpdated(uint256 newFee);
    event RoyaltyFeeUpdated(uint256 newFee);

    /** ✅ Constructor */
    constructor(address initialOwner, address _mintiumToken, address _treasury) 
        ERC721("SolythraNFT", "SNFT") 
        Ownable(initialOwner) 
    {
        mintiumToken = _mintiumToken;
        treasury = _treasury;
        treasuryContract = IMultiSigTreasury(_treasury);
    }

    /** ✅ Update Minting & Trading Fees */
    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceUpdated(_mintPrice);
    }

    function setTradingFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 500, "Fee too high"); // Max 5%
        tradingFee = _newFee;
        emit TradingFeeUpdated(_newFee);
    }

    function setRoyaltyFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Royalty too high"); // Max 10%
        royaltyFee = _newFee;
        emit RoyaltyFeeUpdated(_newFee);
    }

    /** ✅ Mint NFT */
    function mintNFT() external whenNotPaused {
        require(IERC20(mintiumToken).balanceOf(msg.sender) >= mintPrice, "Insufficient MNTM");
        require(IERC20(mintiumToken).transferFrom(msg.sender, treasury, mintPrice), "MNTM transfer failed");
        
        creators[nextTokenId] = msg.sender; // Store creator
        _mint(msg.sender, nextTokenId);
        emit NFTMinted(msg.sender, nextTokenId);
        nextTokenId++;
    }

    /** ✅ Batch Minting */
    function batchMintNFT(uint256 amount) external whenNotPaused {
        require(amount > 0, "Must mint at least 1 NFT");
        uint256 totalCost = mintPrice * amount;
        require(IERC20(mintiumToken).balanceOf(msg.sender) >= totalCost, "Insufficient MNTM");
        require(IERC20(mintiumToken).transferFrom(msg.sender, treasury, totalCost), "MNTM transfer failed");

        for (uint256 i = 0; i < amount; i++) {
            creators[nextTokenId] = msg.sender;
            _mint(msg.sender, nextTokenId);
            emit NFTMinted(msg.sender, nextTokenId);
            nextTokenId++;
        }
    }

    /** ✅ List NFT */
    function listNFT(uint256 tokenId, uint256 price) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not NFT owner");
        listings[tokenId] = Listing(msg.sender, price, block.timestamp + listingDuration, true);
        emit NFTListed(tokenId, price, listings[tokenId].expiration);
    }

    /** ✅ Cancel Listing */
    function cancelListing(uint256 tokenId) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not NFT owner");
        require(listings[tokenId].isListed, "NFT not listed");
        
        listings[tokenId].isListed = false;
        emit NFTListingCancelled(tokenId);
    }

    /** ✅ Buy NFT */
    function buyNFT(uint256 tokenId) external whenNotPaused {
        require(listings[tokenId].isListed, "NFT not listed");
        require(block.timestamp <= listings[tokenId].expiration, "Listing expired");

        uint256 feeAmount = (listings[tokenId].price * tradingFee) / 10000;
        uint256 royaltyAmount = (listings[tokenId].price * royaltyFee) / 10000;
        uint256 sellerAmount = listings[tokenId].price - feeAmount - royaltyAmount;

        require(IERC20(mintiumToken).transferFrom(msg.sender, listings[tokenId].seller, sellerAmount), "Payment failed");
        require(IERC20(mintiumToken).transferFrom(msg.sender, creators[tokenId], royaltyAmount), "Royalty payment failed");
        require(IERC20(mintiumToken).transferFrom(msg.sender, treasury, feeAmount), "Fee transfer failed");

        _transfer(listings[tokenId].seller, msg.sender, tokenId);
        listings[tokenId].isListed = false;
        emit NFTPurchased(tokenId, msg.sender);
    }

    /** ✅ ERC2981 Royalty Info */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address, uint256) {
        uint256 royaltyAmount = (salePrice * royaltyFee) / 10000;
        return (creators[tokenId], royaltyAmount);
    }

    /** ✅ Pause Marketplace */
    function pauseMarketplace() external onlyOwner {
        _pause();
    }

    function unpauseMarketplace() external onlyOwner {
        _unpause();
    }
}
