// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Bet.sol";

contract BetFactory {
    using SafeERC20 for IERC20;

    enum BetStatus {
        active,
        closed,
        completed,
        refunded,
        cancelled
    }
    address payable owner;
    uint256 ownerFee;
    uint256 public trxBatchSize = 50;
    Bet[] public deployedBets;

    address public immutable implementation;

    event BetCreated(address indexed creator, address betAddress);

    constructor(uint256 _ownerFee) {
        owner = payable(msg.sender);
        ownerFee = _ownerFee;
        implementation = address(new Bet());
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not an owner!");
        _;
    }

    function transferOwnerhip(address payable newOwner) external {
        owner = newOwner;
    }

    function updateTrxBatchSize(uint256 _trxBatchSize) external {
        trxBatchSize = _trxBatchSize;
    }

    function updateFee(uint256 newOwnerFee) external {
        ownerFee = newOwnerFee;
    }

    function createBet(
        uint256 maxBetAmt,
        uint256 closingTime,
        uint256 fee,
        bool is2FA,
        address token,
        bytes32[] memory teams
    ) external {
        address newBetAddress = payable(Clones.clone(implementation));
        Bet bet = Bet(newBetAddress);
        bet.init(
            payable(msg.sender),
            owner,
            maxBetAmt,
            closingTime,
            fee,
            ownerFee,
            trxBatchSize,
            is2FA,
            token,
            teams
        );
        deployedBets.push(bet);
        emit BetCreated(msg.sender, newBetAddress);
    }
}
