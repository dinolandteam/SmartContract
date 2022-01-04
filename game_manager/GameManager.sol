// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../core/interface/IDinolandNFT.sol";
 
interface IDinoMarketplace {
   function getEggDetail(uint256 _eggId) external view returns(uint256 genes, address owner, uint256 createdAt, uint256 readyHatchAt, uint256 readyAtBlock, bool isAvailable);
   function disableEgg(uint256 _eggId) external;
}

contract GameManager is Ownable, ReentrancyGuard {
     
    /*** CONSTRUCTOR ***/

    constructor (address _nftContractAddress, address _marketplaceContractAddress) {
        nftContractAddress = _nftContractAddress;
        marketplaceContractAddress = _marketplaceContractAddress;
        whitelistedAdmins[msg.sender] = true;
    }

    /*** EVENTS ***/
    
    event EggOpened(uint256 eggId, uint256 dinoId);


    /*** STORAGES ***/

    mapping(address => bool) public whitelistedAdmins;
    address public nftContractAddress;
    address public marketplaceContractAddress;
    //Hatching rate by percent from 1-10,000 stand for 1% to 100%
    //Normal Egg
    uint32 normalEggR1Rate = 6670;
    uint32 normalEggR2Rate = 2405;
    uint32 normalEggR3Rate = 515;
    uint32 normalEggR4Rate = 305;
    uint32 normalEggR5Rate = 105;
    //Lottery Egg
    uint32 lotteryEggR1Rate = 5120;
    uint32 lotteryEggR2Rate = 3535;
    uint32 lotteryEggR3Rate = 875;
    uint32 lotteryEggR4Rate = 325;
    uint32 lotteryEggR5Rate = 145;
    
    uint8 public constant NORMAL = 11;
    uint8 public constant RARE = 12;
    uint8 public constant SUPER_RARE = 13;
    uint8 public constant LEGENDARY = 14;
    uint8 public constant MYSTIC = 15;
    uint8 public constant LOTTERY_EGG = 14;
    
    /*** MODIFIERS ***/

    modifier onlyAdmin() {
        require(whitelistedAdmins[msg.sender] == true, "Permission denied");
        _;
    }
    
    modifier noContract(address _addr){
      uint32 size;
      assembly {
        size := extcodesize(_addr)
      }
      require (size == 0);
      require(msg.sender == tx.origin);
      _;
    }
    
    /*** METHODS ***/
    
    function setWhitelistedAdmin(address _whitelistedAdminAddress, bool _isAdmin) external onlyOwner {
        whitelistedAdmins[_whitelistedAdminAddress] = _isAdmin;
    }
    
    function setNftContractAddress(address _newNftContractAddress) external onlyOwner {
        nftContractAddress = _newNftContractAddress;
    }
    
    function setMarkeplaceContractAddress(address _newMarketContractAddress) external onlyOwner {
        marketplaceContractAddress = _newMarketContractAddress;
    }
    
    function setNormalEggRate(uint32 _normalEggR1Rate, uint32 _normalEggR2Rate, uint32 _normalEggR3Rate, uint32 _normalEggR4Rate, uint32 _normalEggR5Rate) external onlyOwner {
        require(_normalEggR1Rate + _normalEggR2Rate + _normalEggR3Rate + _normalEggR4Rate + _normalEggR5Rate == 10000, "Total rate not equal to 10000");
        normalEggR1Rate = _normalEggR1Rate;
        normalEggR2Rate = _normalEggR2Rate;
        normalEggR3Rate = _normalEggR3Rate;
        normalEggR4Rate = _normalEggR4Rate;
        normalEggR5Rate = _normalEggR5Rate;
    }
    
    function setLotteryEggRate(uint32 _lotteryEggR1Rate, uint32 _lotteryEggR2Rate, uint32 _lotteryEggR3Rate, uint32 _lotteryEggR4Rate, uint32 _lotteryEggR5Rate) external onlyOwner {
        require(_lotteryEggR1Rate + _lotteryEggR2Rate + _lotteryEggR3Rate + _lotteryEggR4Rate + _lotteryEggR5Rate == 10000, "Total rate not equal to 10000");
        lotteryEggR1Rate = _lotteryEggR1Rate;
        lotteryEggR2Rate = _lotteryEggR2Rate;
        lotteryEggR3Rate = _lotteryEggR3Rate;
        lotteryEggR4Rate = _lotteryEggR4Rate;
        lotteryEggR5Rate = _lotteryEggR5Rate;
    }
    
    function getDinoClassByEggGenes(uint256 _eggGenes) internal pure returns (uint256) {
        require(_eggGenes >= 1111, "Invalid egg");
        return _eggGenes/100;
    }
    
    
    function openEgg(uint256 _eggId) external noContract(msg.sender) nonReentrant {
        uint256 eggGenes;
        address eggOwner;
        uint256 eggCreatedAt;
        uint256 eggReadyHatchAt;
        bool eggIsAvailable;
        uint256 eggReadyAtBlock;
        (eggGenes, eggOwner, eggCreatedAt, eggReadyHatchAt, eggReadyAtBlock, eggIsAvailable) = IDinoMarketplace(marketplaceContractAddress).getEggDetail(_eggId);
        require(block.timestamp > eggReadyHatchAt, "Egg not ready");
        require(eggIsAvailable == true, "Egg not available");
        require(msg.sender == eggOwner, "Egg not owned by you");
        
        
        uint256 rand = (uint(keccak256(abi.encodePacked(blockhash(eggReadyAtBlock), _eggId))) + eggGenes) % 10000 + 1;
        uint256 classRand = uint(keccak256(abi.encodePacked(rand, block.coinbase))) % 10000 + 1;
        uint256 genderRand = uint(keccak256(abi.encodePacked(rand, block.timestamp))) % 10000 + 1;
        
        uint256 dinoGenes = 1111;
        uint128 dinoGender = 1;
        IDinoMarketplace(marketplaceContractAddress).disableEgg(_eggId);
        if(eggGenes / 100 == LOTTERY_EGG) {
            // Random Dino Class
            uint256 dinoClass = 11;
            if(classRand < 3333) {
                dinoClass = 11;
            } else if(classRand < 6666) {
                dinoClass = 12;
            } else {
                dinoClass = 13;
            }
            uint256 dinoRarity = 11;
            //Random Dino Rarity
            if(rand < lotteryEggR1Rate) {
                dinoRarity = NORMAL;
            } else if (rand < lotteryEggR1Rate + lotteryEggR2Rate) {
                dinoRarity = RARE;
            } else if (rand < lotteryEggR1Rate + lotteryEggR2Rate + lotteryEggR3Rate) {
                dinoRarity = SUPER_RARE;
            } else if (rand < lotteryEggR1Rate + lotteryEggR2Rate + lotteryEggR3Rate + lotteryEggR4Rate) {
                dinoRarity = LEGENDARY;
            } else {
                dinoRarity = MYSTIC;
            }
            //Random Gender
            if(genderRand < 5000) {
                dinoGender = 1;
            } else {
                dinoGender = 2;
            }
            //Generate genes
            dinoGenes = dinoClass*100 + dinoRarity;
        } else {
            uint256 dinoClass = getDinoClassByEggGenes(eggGenes);
              //Random Dino Rarity
            uint8 dinoRarity = 11;
            if(rand < normalEggR1Rate) {
                dinoRarity = NORMAL;
            } else if (rand < normalEggR1Rate + normalEggR2Rate) {
                dinoRarity = RARE;
            } else if (rand < normalEggR1Rate + normalEggR2Rate + normalEggR3Rate) {
                dinoRarity = SUPER_RARE;
            } else if (rand < normalEggR1Rate + normalEggR2Rate + normalEggR3Rate + normalEggR4Rate) {
                dinoRarity = LEGENDARY;
            } else {
                dinoRarity = MYSTIC;
            }
            //Random Gender
            if(genderRand < 5000) {
                dinoGender = 1;
            } else {
                dinoGender = 2;
            }
            //Generate genes
            dinoGenes = dinoClass*100 + dinoRarity;
        }
        uint256 dinoId = IDinolandNFT(nftContractAddress).createDino(dinoGenes, eggOwner, dinoGender, 1);
        emit EggOpened(_eggId, dinoId);
    }
}