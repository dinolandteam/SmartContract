// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import './TokenTimelock.sol';

contract Dinoland is ERC20, Ownable {
    uint256 private _maxTotalSupply;
    address public constant SEED_ADDRESS  = 0xb40eA1DA6A55bDf2b5BFbd054cC7dDB53F8ac615;
    address public constant PRIVATE_SALE_ADDRESS = 0xb40eA1DA6A55bDf2b5BFbd054cC7dDB53F8ac615;
    address public constant IDO_ADDRESS = 0xb40eA1DA6A55bDf2b5BFbd054cC7dDB53F8ac615;
    address public constant GAME_INCENTIVES_AND_FARMING_ADDRESS = 0xb40eA1DA6A55bDf2b5BFbd054cC7dDB53F8ac615;
    address public constant RESERVE_AND_LIQUIDITY_ADDRESS = 0xb40eA1DA6A55bDf2b5BFbd054cC7dDB53F8ac615;
    address public constant MARKETING_ADDRESS = 0xb40eA1DA6A55bDf2b5BFbd054cC7dDB53F8ac615;
    address public constant TEAM_ADDRESS = 0xb40eA1DA6A55bDf2b5BFbd054cC7dDB53F8ac615;
    address public constant ADVISOR_ADDRESS = 0xb40eA1DA6A55bDf2b5BFbd054cC7dDB53F8ac615;
    
    constructor() ERC20("Dinoland Metaverse", "DNL") {
        _maxTotalSupply = 1e9 ether;
        TimelockFactory timelockFactory = new TimelockFactory();

        mint(SEED_ADDRESS, 2100000 ether);
        address seedERC20Lock = timelockFactory.createTimelock(this, SEED_ADDRESS, block.timestamp + 60 days, 2325000 ether, 30 days);
        mint(seedERC20Lock, 27900000 ether);
        
        mint(PRIVATE_SALE_ADDRESS, 9000000 ether);
        address privateERC20Lock = timelockFactory.createTimelock(this, PRIVATE_SALE_ADDRESS, block.timestamp + 60 days, 9100000 ether, 30 days);
        mint(privateERC20Lock, 91000000 ether);
        
        mint(IDO_ADDRESS, 6000000 ether);
        address idoERC20Lock = timelockFactory.createTimelock(this, IDO_ADDRESS, block.timestamp + 60 days, 6000000 ether, 30 days);
        mint(idoERC20Lock, 24000000 ether);
        
        address gameIncentiveAndFarmingERC20Lock = timelockFactory.createTimelock(this, GAME_INCENTIVES_AND_FARMING_ADDRESS, block.timestamp + 14 days, 8888889 ether, 30 days);
        mint(gameIncentiveAndFarmingERC20Lock, 320000000 ether);

        address reserveAndLiquidityERC20Lock = timelockFactory.createTimelock(this, RESERVE_AND_LIQUIDITY_ADDRESS, block.timestamp + 14 days, 0, 0);
        mint(reserveAndLiquidityERC20Lock, 270000000 ether);

        address marketingERC20Lock = timelockFactory.createTimelock(this, MARKETING_ADDRESS, block.timestamp + 14 days, 0, 0);
        mint(marketingERC20Lock, 80000000 ether);

        address teamERC20Lock = timelockFactory.createTimelock(this, TEAM_ADDRESS, block.timestamp + 180 days, 4000000 ether, 30 days);
        mint(teamERC20Lock, 120000000 ether);
        
        mint(ADVISOR_ADDRESS, 1000000 ether);
        address advisorERC20Lock = timelockFactory.createTimelock(this, ADVISOR_ADDRESS, block.timestamp + 180 days, 2041667 ether, 30 days);
        mint(advisorERC20Lock, 49000000 ether);
        
    }

    function mint(address account, uint256 amount) public onlyOwner returns (bool) {
        require(totalSupply() + amount <= _maxTotalSupply, "Mint more than the max total supply");
        _mint(account, amount);
        return true;
    }

    function burn(uint256 amount) public returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }
}