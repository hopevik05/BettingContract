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
    address payable public owner;
    uint256 public ownerFee;
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
        require(msg.sender == owner, "UNAUTHORISED");
        _;
    }

    function transferOwnerhip(address payable newOwner_) external onlyOwner {
        owner = newOwner_;
    }

    function updateTrxBatchSize(uint256 trxBatchSize_) external onlyOwner {
        trxBatchSize = trxBatchSize_;
    }

    function updateFee(uint256 ownerFee_) external onlyOwner {
        ownerFee = ownerFee_;
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

    function getAllBets() public view returns (Bet[] memory) {
        return deployedBets;
    }
}
