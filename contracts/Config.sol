// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Config {
    enum BetStatus {
        active,
        completed,
        refunded,
        cancelled
    }

    struct Stake {
        bytes32 team;
        uint256 amount;
        uint256 prize;
    }

    address payable public admin;
    uint256 public status = uint256(BetStatus.active);
    address[] public stakers;
    uint256 public totalFundRaised;
    bytes32 public winner;
    mapping(address => Stake) public stakerInfo;

    uint256 _maxBetAmt;
    uint256 _closingTime;
    uint256 _fee;
    bool _is2FA;
    IERC20 _token;
    bytes32[] _teams;
    uint256 _trxBatchSize;
    uint256 _trxPointer;
    uint256 _leftApproval = 1;
    address payable _owner;
    uint256 _ownerFee;

    /* ========== MODIFIES ========== */

    modifier onlyOwnerOrAdmin() {
        require(msg.sender == admin || msg.sender == _owner, "UNAUTHORIZED");
        _;
    }

    modifier isStakingOpen() {
        require(_closingTime <= block.timestamp, "BET_CLOSED");
        _;
    }

    modifier isActive() {
        require(status == uint256(BetStatus.active), "BET_CONCLUDE");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "UNAUTHORIZED");
        _;
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event Refund(uint256 fromIndex, uint256 toIndex);
    event Cancelled();
    event WinnerDeclared(
        address indexed executor,
        bytes32 team,
        uint256 _leftApproval
    );
}
