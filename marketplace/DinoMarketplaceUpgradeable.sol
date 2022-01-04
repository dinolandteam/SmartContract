// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
/// @title Clock auction for non-fungible tokens.
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../core/interface/IDinolandNFT.sol";

contract DinoMarketplaceUpgradeable is Pausable, Initializable, ReentrancyGuard {
    /*** EVENTS ***/

    event DinoSpawned(uint256 _id, uint256 _genes);

    event AuctionCreated(
        uint256 indexed _tokenId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration,
        address _seller
    );

    event AuctionSuccessful(
        uint256 indexed _tokenId,
        uint256 _totalPrice,
        address _winner
    );

    event EggBought(
        uint256 indexed _eggGenes,
        uint256 indexed _eggAmount,
        address indexed _owner
    );

    event EggCreated(uint256 eggId, uint256 genes);

    event AuctionCancelled(uint256 indexed _tokenId);

    /*** DATA TYPES ***/
    using SafeMath for uint256;
    /// @dev Represents an egg
    struct Egg {
        /// The genes code of this egg
        uint256 genes;
        /// Current owner of this egg
        address owner;
        /// Egg borned at (unix timestamp)
        uint256 createdAt;
        /// Egg ready hatch at (unix timestamp)
        uint256 readyHatchAt;
        /// Egg ready hatch at block (block number)
        uint256 readyAtBlock;
        /// Egg is still available or not
        bool isAvailable;
    }

    // Represents an auction on an NFT
    struct Auction {
        // Current owner of NFT
        address seller;
        // Price (in wei) at beginning of auction
        uint128 startingPrice;
        // Price (in wei) at end of auction
        uint128 endingPrice;
        // Duration (in seconds) of auction
        uint64 duration;
        // Time when auction started
        // NOTE: 0 if this auction has been concluded
        uint64 startedAt;
    }

    /*** STORAGES ***/

    uint256 public blockTime;
    // Cut owner takes on each auction, measured in basis points (1/100 of a percent).
    // Values 0-10,000 map to 0%-100%
    uint256 public ownerCut;
    //DNL contract Address
    address public tokenAddress;
    //DINO contract address
    address public nftAddress;
    //MarketManager address
    address public marketManagerAddress;
    //Admins list
    mapping(address => bool) public admins;
    uint256 public defaultEggPrice;
    uint256 public incubationTime;
    uint256 public skipHatchCooldownPrice;
    mapping(uint256 => uint256) public totalSellingEggByGenes;
    mapping(uint256 => uint256) public eggPriceByGenes;
    mapping(address => uint256[]) public userOwnedEggs;

    Egg[] public eggs;

    // Map from token ID to their corresponding auction.
    mapping(address => mapping(uint256 => Auction)) public auctions;

    /*** METHODS***/

    /// @dev A method that be called by proxy to init storage value of the contract
    function initialize() public initializer {
        marketManagerAddress = msg.sender;
        admins[msg.sender] = true;
        ownerCut = 500;

        /// Set default egg price is 3000 DNL
        defaultEggPrice = 3000 * 1e18;
        /// Set default incubatin period is 6 hours
        incubationTime = 6 hours;
        /// Set default skip incubation time is 500 DNL
        skipHatchCooldownPrice = 500 * 1e18;
        // Set default block time is 3 seconds
        blockTime = 3;
    }

    /// @dev DON'T give me your money.
    receive() external payable {}

    // Modifiers to check that inputs can be safely stored with a certain
    // number of bits. We use constants and multiple modifiers to save gas.
    modifier canBeStoredWith64Bits(uint256 _value) {
        require(_value <= 18446744073709551615);
        _;
    }

    modifier canBeStoredWith128Bits(uint256 _value) {
        require(_value < 340282366920938463463374607431768211455);
        _;
    }
    /// @dev The modifier that restrict admin permission
    modifier onlyAdmin() {
        require(admins[msg.sender], "need_admin_permission");
        _;
    }

    /// @dev The modifier that restrict egg owner permission by egg id
    modifier onlyEggOwner(uint256 _eggId) {
        require(eggs[_eggId].owner == msg.sender, "need_egg_owner_permission");
        _;
    }

    /// @dev The modifier that restrict market manager permission
    modifier onlyMarketManger() {
        require(
            msg.sender == marketManagerAddress,
            "need_market_manager_permission"
        );
        _;
    }

    /// @dev Set new market manager address
    /// @param _newMarketManagerAddress - Address of new admin.
    function setMarketManagerAddress(address _newMarketManagerAddress)
        external
        onlyMarketManger
    {
        marketManagerAddress = _newMarketManagerAddress;
    }

    /// @dev Set new admin address
    /// @param _adminAddress - Address of admin.
    /// @param _isAdmin - Is admin or not.
    function setAdmin(address _adminAddress, bool _isAdmin)
        external
        onlyMarketManger
    {
        admins[_adminAddress] = _isAdmin;
    }

    /// @dev Set new token address
    /// @param _newTokenAddress - Address of new erc20 token.
    function setTokenAddress(address _newTokenAddress)
        external
        onlyMarketManger
    {
        tokenAddress = _newTokenAddress;
    }

    /// @dev Set new nft address
    /// @param _newNftAddress - Address of new erc721 token.
    function setNftAddress(address _newNftAddress) external onlyMarketManger {
        nftAddress = _newNftAddress;
    }

    /// @dev Set new egg price
    /// @param _newEggPrice - Set new value for egg price
    function setDefaultEggPrice(uint256 _newEggPrice) external onlyAdmin {
        defaultEggPrice = _newEggPrice;
    }

    /// @dev Set egg price by genes
    /// @param _eggGenes - Egg genes.
    /// @param _eggPrice - Price of this egg genes.
    function setEggPriceByGenes(uint256 _eggGenes, uint256 _eggPrice)
        external
        onlyAdmin
    {
        eggPriceByGenes[_eggGenes] = _eggPrice;
    }

    function setIncubationTime(uint256 _incubationTime) external onlyAdmin {
        incubationTime = _incubationTime;
    }

    function setBlockTime(uint256 _blockTime) external onlyAdmin {
        blockTime = _blockTime;
    }

    /// @dev Set total egg by genes of market
    /// @param _eggGenes - Dino egg genes
    /// @param _total - Total egg by genes
    function setTotalSellingEggByGenes(uint256 _eggGenes, uint256 _total)
        external
        onlyAdmin
    {
        totalSellingEggByGenes[_eggGenes] = _total;
    }

    /// @dev Set skip hatching price
    /// @param _newSkipHatchCooldownPrice - New skip cooldown price
    function setSkipHatchCooldownPrice(uint256 _newSkipHatchCooldownPrice)
        external
        onlyAdmin
    {
        skipHatchCooldownPrice = _newSkipHatchCooldownPrice;
    }

    /// @dev Get total selling egg by the input genes
    /// @param _eggGenes - Genes of the egg type that you want to get total egg
    function getTotalSellingEggByGenes(uint256 _eggGenes)
        external
        view
        returns (uint256)
    {
        return totalSellingEggByGenes[_eggGenes];
    }

    /// @dev Get egg price by egg genes
    /// @param _eggGenes - Genes of the egg type that you want to get price
    function getEggPriceByGenes(uint256 _eggGenes)
        external
        view
        returns (uint256)
    {
        uint256 eggPrice = eggPriceByGenes[_eggGenes] == 0
            ? defaultEggPrice
            : eggPriceByGenes[_eggGenes];
        return eggPrice;
    }

    /// @dev Get eggs list by owner address
    /// @param _owner Owner address

    function getEggsByOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        return userOwnedEggs[_owner];
    }

    ///@dev Get total existing egg on the market
    function getTotalEgg() external view returns (uint256) {
        return eggs.length;
    }

    ///@dev Get specific detail of an egg by egg id
    /// _eggId - The Egg Id
    function getEggDetail(uint256 _eggId)
        external
        view
        returns (
            uint256 genes,
            address owner,
            uint256 createdAt,
            uint256 readyHatchAt,
            uint256 readyAtBlock,
            bool isAvailable
        )
    {
        Egg storage egg = eggs[_eggId];
        return (
            egg.genes,
            egg.owner,
            egg.createdAt,
            egg.readyHatchAt,
            egg.readyAtBlock,
            egg.isAvailable
        );
    }

    ///@dev An external method that allow Admin to update the egg status
    /// @param _eggId - The Egg Id
    /// @param _isAvailable - Is Available or not, set to false if you want to disable this egg

    function updateEggStatus(uint256 _eggId, bool _isAvailable)
        external
        onlyAdmin
        returns (uint256)
    {
        require(_eggId <= eggs.length - 1, "egg_not_exist");
        eggs[_eggId].isAvailable = _isAvailable;
        return _eggId;
    }

    /// @dev An external method that allow admin to disable an egg
    /// @param _eggId - The id of the egg that you want to disable
    function disableEgg(uint256 _eggId) external onlyAdmin {
        Egg storage egg = eggs[_eggId];
        require(_eggId <= eggs.length - 1, "egg_not_exist");
        require(block.timestamp > egg.readyHatchAt, "Egg not ready");
        require(egg.isAvailable == true, "Egg not availble");
        eggs[_eggId].isAvailable = false;
    }

    /// @dev Get current balance holding in market
    function getMarketManagerBalance() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    /// @dev Skip egg cooldown by paying some DNL token
    /// @param _eggId - Id of the egg that you want to skip incubation
    function skipEggCooldown(uint256 _eggId) external onlyEggOwner(_eggId) {
        Egg storage egg = eggs[_eggId];
        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            skipHatchCooldownPrice
        );
        egg.readyHatchAt = block.timestamp;
        egg.readyAtBlock = block.number;
    }

    /// @dev Buy egg by genes logic, transfer DNL from buyer address to market
    /// @param _eggGenes - Current buying egg genes
    /// @param _eggAmount - Amount of egg to buy
    function buyEgg(uint256 _eggGenes, uint256 _eggAmount) external nonReentrant {
        require(
            totalSellingEggByGenes[_eggGenes] >= _eggAmount,
            "egg_sold_out"
        );
        if (eggPriceByGenes[_eggGenes] > 0) {
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _eggAmount.mul(eggPriceByGenes[_eggGenes])
            );
        } else {
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _eggAmount.mul(defaultEggPrice)
            );
        }

        totalSellingEggByGenes[_eggGenes] = totalSellingEggByGenes[_eggGenes]
            .sub(_eggAmount);
        //Create new egg
        uint256 readyHatchAt = block.timestamp + incubationTime;
        for (uint256 i = 0; i < _eggAmount; i++) {
            uint256 newEggId = _createEgg(_eggGenes, readyHatchAt);
            userOwnedEggs[msg.sender].push(newEggId);
            emit EggCreated(newEggId, _eggGenes);
        }

        emit EggBought(_eggGenes, _eggAmount, msg.sender);
    }

    /// @dev Create egg
    function _createEgg(uint256 _eggGenes, uint256 _readyHatchAt)
        private
        returns (uint256)
    {
        uint256 targetBlock = block.number +
            (_readyHatchAt - block.timestamp) /
            blockTime;
        Egg memory newEgg = Egg(
            _eggGenes,
            msg.sender,
            block.timestamp,
            _readyHatchAt,
            targetBlock,
            true
        );
        eggs.push(newEgg);
        uint256 _eggId = eggs.length - 1;
        return _eggId;
    }
    /// @dev Create egg and assign to an address
    function createEgg(uint256 _eggGenes, uint256 _readyHatchAt, address _owner)
        external
        onlyAdmin
        returns (uint256)
    {
        uint256 targetBlock = block.number +
            (_readyHatchAt - block.timestamp) /
            blockTime;
        Egg memory newEgg = Egg(
            _eggGenes,
            _owner,
            block.timestamp,
            _readyHatchAt,
            targetBlock,
            true
        );
        eggs.push(newEgg);
        uint256 _eggId = eggs.length - 1;
        return _eggId;
    }

    /// @dev Withdraw balance of market to specific address
    /// @param _to - Receiver address
    /// @param _amount - Token amount
    function withdrawBalance(address _to, uint256 _amount)
        external
        onlyMarketManger
        returns (bool)
    {
        IERC20(tokenAddress).transfer(_to, _amount);
        return true;
    }

    /// @dev Withdraw all balance of market to specific address
    /// @param _to - Receiver address
    function withdrawAllBalance(address _to)
        external
        onlyMarketManger
        returns (bool)
    {
        uint256 marketManagerBalance = getMarketManagerBalance();
        return IERC20(tokenAddress).transfer(_to, marketManagerBalance);
    }

    /// @dev Returns auction info for an NFT on auction.
    /// @param _tokenId - ID of NFT on auction.
    function getAuction(uint256 _tokenId)
        external
        view
        returns (
            address seller,
            uint256 startingPrice,
            uint256 endingPrice,
            uint256 duration,
            uint256 startedAt
        )
    {
        Auction storage _auction = auctions[nftAddress][_tokenId];
        require(_isOnAuction(_auction));
        return (
            _auction.seller,
            _auction.startingPrice,
            _auction.endingPrice,
            _auction.duration,
            _auction.startedAt
        );
    }

    /// @dev Returns the current price of an auction.
    /// @param _tokenId - ID of the token price we are checking.
    function getCurrentPrice(uint256 _tokenId) external view returns (uint256) {
        Auction storage _auction = auctions[nftAddress][_tokenId];
        require(_isOnAuction(_auction));
        return _getCurrentPrice(_auction);
    }

    /// @dev Creates and begins a new auction.
    ///  the Nonfungible Interface.
    /// @param _tokenId - ID of token to auction, sender must be owner.
    /// @param _startingPrice - Price of item (in wei) at beginning of auction.
    /// @param _endingPrice - Price of item (in wei) at end of auction.
    /// @param _duration - Length of time to move between starting
    ///  price and ending price (in seconds).
    function createAuction(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    )
        external
        whenNotPaused
        nonReentrant
        canBeStoredWith128Bits(_startingPrice)
        canBeStoredWith128Bits(_endingPrice)
        canBeStoredWith64Bits(_duration)
    {
        address _seller = msg.sender;
        require(_owns(_seller, _tokenId), "you_dont_have_permission");
        _escrow(nftAddress, _seller, _tokenId);
        Auction memory _auction = Auction(
            _seller,
            uint128(_startingPrice),
            uint128(_endingPrice),
            uint64(_duration),
            uint64(block.timestamp)
        );
        _addAuction(nftAddress, _tokenId, _auction, _seller);
    }

    /// @dev Bids on an open auction, completing the auction and transferring
    ///  ownership of the NFT if enough Ether is supplied.
    ///  the Nonfungible Interface.
    /// @param _tokenId - ID of token to bid on.
    function bid(uint256 _tokenId, uint256 _amount) external whenNotPaused nonReentrant {
        // _bid will throw if the bid or funds transfer fails
        _bid(_tokenId, _amount);
        _transfer(nftAddress, msg.sender, _tokenId);
    }

    /// @dev Cancels an auction that hasn't been won yet.
    ///  Returns the NFT to original owner.
    /// @notice This is a state-modifying function that can
    ///  be called while the contract is paused.
    /// @param _tokenId - ID of token on auction
    function cancelAuction(uint256 _tokenId) public {
        Auction storage _auction = auctions[nftAddress][_tokenId];
        require(_isOnAuction(_auction), "is_not_on_auction");
        require(
            msg.sender == _auction.seller || admins[msg.sender],
            "dont_have_pemission"
        );
        _cancelAuction(_tokenId, _auction.seller);
    }

    /// @dev Cancels all auctions that hasn't been won yet.
    ///  Returns the NFT to original owner.
    /// @notice This is a state-modifying function that can
    ///  be called while the contract is paused.
    /// For emergency purposes only
    function cancelAllAuction() external onlyAdmin {
        uint256[] memory dinosOwnedByMarket = IDinolandNFT(nftAddress)
            .getDinosByOwner(address(this));
        for (uint256 i = 0; i < dinosOwnedByMarket.length; i++) {
            if (dinosOwnedByMarket[i] != 0) {
                cancelAuction(dinosOwnedByMarket[i]);
            }
        }
    }

    /// @dev Cancels an auction when the contract is paused.
    ///  Only the owner may do this, and NFTs are returned to
    ///  the seller. This should only be used in emergencies.
    /// @param _nftAddress - Address of the NFT.
    /// @param _tokenId - ID of the NFT on auction to cancel.
    function cancelAuctionWhenPaused(address _nftAddress, uint256 _tokenId)
        external
        whenPaused
        onlyAdmin
    {
        Auction storage _auction = auctions[_nftAddress][_tokenId];
        require(_isOnAuction(_auction));
        _cancelAuction(_tokenId, _auction.seller);
    }

    /// @dev Returns true if the NFT is on auction.
    /// @param _auction - Auction to check.
    function _isOnAuction(Auction storage _auction)
        internal
        view
        returns (bool)
    {
        return (_auction.startedAt > 0);
    }

    /// @dev Gets the NFT object from an address, validating that implementsERC721 is true.
    /// @param _nftAddress - Address of the NFT.
    function _getNftContract(address _nftAddress)
        internal
        pure
        returns (IERC721)
    {
        IERC721 candidateContract = IERC721(_nftAddress);
        // require(candidateContract.implementsERC721());
        return candidateContract;
    }

    /// @dev Returns current price of an NFT on auction. Broken into two
    ///  functions (this one, that computes the duration from the auction
    ///  structure, and the other that does the price computation) so we
    ///  can easily test that the price computation works correctly.
    function _getCurrentPrice(Auction storage _auction)
        internal
        view
        returns (uint256)
    {
        uint256 _secondsPassed = 0;

        // A bit of insurance against negative values (or wraparound).
        // Probably not necessary (since Ethereum guarantees that the
        // now variable doesn't ever go backwards).
        if (block.timestamp > _auction.startedAt) {
            _secondsPassed = block.timestamp - _auction.startedAt;
        }

        return
            _computeCurrentPrice(
                _auction.startingPrice,
                _auction.endingPrice,
                _auction.duration,
                _secondsPassed
            );
    }

    /// @dev Computes the current price of an auction. Factored out
    ///  from _currentPrice so we can run extensive unit tests.
    ///  When testing, make this function external and turn on
    ///  `Current price computation` test suite.
    function _computeCurrentPrice(
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration,
        uint256 _secondsPassed
    ) internal pure returns (uint256) {
        // NOTE: We don't use SafeMath (or similar) in this function because
        //  all of our external functions carefully cap the maximum values for
        //  time (at 64-bits) and currency (at 128-bits). _duration is
        //  also known to be non-zero (see the require() statement in
        //  _addAuction())
        if (_secondsPassed >= _duration) {
            // We've reached the end of the dynamic pricing portion
            // of the auction, just return the end price.
            return _endingPrice;
        } else {
            // Starting price can be higher than ending price (and often is!), so
            // this delta can be negative.
            int256 _totalPriceChange = int256(_endingPrice) -
                int256(_startingPrice);

            // This multiplication can't overflow, _secondsPassed will easily fit within
            // 64-bits, and _totalPriceChange will easily fit within 128-bits, their product
            // will always fit within 256-bits.
            int256 _currentPriceChange = (_totalPriceChange *
                int256(_secondsPassed)) / int256(_duration);

            // _currentPriceChange can be negative, but if so, will have a magnitude
            // less that _startingPrice. Thus, this result will always end up positive.
            int256 _currentPrice = int256(_startingPrice) + _currentPriceChange;

            return uint256(_currentPrice);
        }
    }

    /// @dev Returns true if the claimant owns the token.
    /// @param _claimant - Address claiming to own the token.
    /// @param _tokenId - ID of token whose ownership to verify.
    function _owns(address _claimant, uint256 _tokenId)
        private
        view
        returns (bool)
    {
        IERC721 _nftContract = _getNftContract(nftAddress);
        return (_nftContract.ownerOf(_tokenId) == _claimant);
    }

    /// @dev Adds an auction to the list of open auctions. Also fires the
    ///  AuctionCreated event.
    /// @param _tokenId The ID of the token to be put on auction.
    /// @param _auction Auction to add.
    function _addAuction(
        address _nftAddress,
        uint256 _tokenId,
        Auction memory _auction,
        address _seller
    ) internal {
        // Require that all auctions have a duration of
        // at least one minute. (Keeps our math from getting hairy!)
        require(_auction.duration >= 1 minutes, "duration_need_at_least_1min");

        auctions[_nftAddress][_tokenId] = _auction;

        emit AuctionCreated(
            _tokenId,
            uint256(_auction.startingPrice),
            uint256(_auction.endingPrice),
            uint256(_auction.duration),
            _seller
        );
    }

    /// @dev Removes an auction from the list of open auctions.
    /// @param _tokenId - ID of NFT on auction.
    function _removeAuction(uint256 _tokenId) internal {
        delete auctions[nftAddress][_tokenId];
    }

    /// @dev Cancels an auction unconditionally.
    function _cancelAuction(uint256 _tokenId, address _seller) internal {
        _removeAuction(_tokenId);
        _transfer(nftAddress, _seller, _tokenId);
        emit AuctionCancelled(_tokenId);
    }

    /// @dev Escrows the NFT, assigning ownership to this contract.
    /// Throws if the escrow fails.
    /// @param _nftAddress - The address of the NFT.
    /// @param _owner - Current owner address of token to escrow.
    /// @param _tokenId - ID of token whose approval to verify.
    function _escrow(
        address _nftAddress,
        address _owner,
        uint256 _tokenId
    ) internal {
        IERC721 _nftContract = IERC721(_nftAddress);

        // It will throw if transfer fails
        _nftContract.transferFrom(_owner, address(this), _tokenId);
    }

    /// @dev Transfers an NFT owned by this contract to another address.
    /// Returns true if the transfer succeeds.
    /// @param _nftAddress - The address of the NFT.
    /// @param _receiver - Address to transfer NFT to.
    /// @param _tokenId - ID of token to transfer.
    function _transfer(
        address _nftAddress,
        address _receiver,
        uint256 _tokenId
    ) internal {
        IERC721 _nftContract = IERC721(_nftAddress);

        // It will throw if transfer fails
        _nftContract.transferFrom(address(this), _receiver, _tokenId);
    }

    /// @dev Computes owner's cut of a sale.
    /// @param _price - Sale price of NFT.
    function _computeCut(uint256 _price) internal view returns (uint256) {
        // NOTE: We don't use SafeMath (or similar) in this function because
        //  all of our entry functions carefully cap the maximum values for
        //  currency (at 128-bits), and ownerCut <= 10000 (see the require()
        //  statement in the ClockAuction constructor). The result of this
        //  function is always guaranteed to be <= _price.
        return (_price * ownerCut) / 10000;
    }

    /// @dev Computes the price and transfers winnings.
    /// Does NOT transfer ownership of token.
    function _bid(uint256 _tokenId, uint256 _bidAmount)
        internal
        returns (uint256)
    {
        // Get a reference to the auction struct
        Auction storage _auction = auctions[nftAddress][_tokenId];

        // Explicitly check that this auction is currently live.
        // (Because of how Ethereum mappings work, we can't just count
        // on the lookup above failing. An invalid _tokenId will just
        // return an auction object that is all zeros.)
        // require(_isOnAuction(_auction), "Is not on auction");
        require(_auction.startedAt > 0, "is_not_on_auction");

        // Check that the incoming bid is higher than the current
        // price
        uint256 _price = _getCurrentPrice(_auction);
        require(_bidAmount >= _price, "bid_amount_is_not_enough");

        // Grab a reference to the seller before the auction struct
        // gets deleted.
        address _seller = _auction.seller;

        // The bid is good! Remove the auction before sending the fees
        // to the sender so we can't have a reentrancy attack.
        _removeAuction(_tokenId);

        // Transfer proceeds to seller (if there are any!)
        if (_price > 0) {
            //  Calculate the auctioneer's cut.
            // (NOTE: _computeCut() is guaranteed to return a
            //  value <= price, so this subtraction can't go negative.)
            uint256 _auctioneerCut = _computeCut(_price);
            uint256 _sellerProceeds = _price - _auctioneerCut;

            // Keep ownerCut percent
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _auctioneerCut
            );
            // Transfer the remaining token to seller
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                _seller,
                _sellerProceeds
            );
        }
        // Tell the world!
        emit AuctionSuccessful(_tokenId, _price, msg.sender);

        return _price;
    }
}
