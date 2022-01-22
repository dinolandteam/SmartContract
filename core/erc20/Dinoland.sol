// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import './TokenTimelock.sol';

contract Dinoland is ERC20, Ownable {
    uint256 private _maxTotalSupply;
    address public constant SEED_ADDRESS  = 0xC3EC726459F7FC28E849058696757d831f7c6e71;
    address public constant PRIVATE_SALE_ADDRESS = 0x9308C7c9Ac6C5D060D68aD5f50259EaBf510A2d3;
    address public constant IDO_ADDRESS = 0x81339e979644CE6ef5394B6bee2Cc6128EfdDC4D;
    address public constant GAME_INCENTIVES_AND_FARMING_ADDRESS = 0x6853eaB72E79fA4C616bC21ef9DE7b7E39344c18;
    address public constant RESERVE_AND_LIQUIDITY_ADDRESS = 0x840116385be055452886e96f9b9D78Fc6243bC74;
    address public constant MARKETING_ADDRESS = 0x306F3d5dfE4eA1907A5f086F0B6d7244F5827a85;
    address public constant TEAM_ADDRESS = 0xA5153ba330c61275eCb9E4F1cfD7c3A7423b3489;
    address public constant ADVISOR_ADDRESS = 0xF8544F4a6aFDD24C40fDad3fCBdd720e5ce74e81;
    
    constructor() ERC20("Dinoland Metaverse", "DNL") {
        _maxTotalSupply = 1e9 ether;
        TimelockFactory timelockFactory = new TimelockFactory();

        mint(SEED_ADDRESS, 2100000 ether);
        address seedERC20Lock = timelockFactory.createTimelock(this, SEED_ADDRESS, block.timestamp + 60 days, 2325000 ether, 30 days);
        mint(seedERC20Lock, 27900000 ether);
        
        mint(PRIVATE_SALE_ADDRESS, 9000000 ether);
        address privateERC20Lock = timelockFactory.createTimelock(this, PRIVATE_SALE_ADDRESS, block.timestamp + 60 days, 9100000 ether, 30 days);
        mint(privateERC20Lock, 91000000 ether);
        
        mint(IDO_ADDRESS, 30000000 ether);
        
        address gameIncentiveAndFarmingERC20Lock = timelockFactory.createTimelock(this, GAME_INCENTIVES_AND_FARMING_ADDRESS, block.timestamp + 14 days, 8888889 ether, 30 days);
        mint(gameIncentiveAndFarmingERC20Lock, 320000000 ether);

        address reserveAndLiquidityERC20Lock = timelockFactory.createTimelock(this, RESERVE_AND_LIQUIDITY_ADDRESS, block.timestamp, 0, 0);
        mint(reserveAndLiquidityERC20Lock, 270000000 ether);

        address marketingERC20Lock = timelockFactory.createTimelock(this, MARKETING_ADDRESS, block.timestamp, 0, 0);
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