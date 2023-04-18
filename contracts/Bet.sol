// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Bet is Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Staked(address indexed staker, uint256 amount);
    event Withdraw(address indexed staker, uint256 amount);

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

    address payable private factoryOwner;
    address payable admin;
    uint256 maxBetAmt;
    uint256 closingTime;
    uint256 fee;
    uint256 factoryFee;
    bool is2FA;
    IERC20 token;
    bytes32[] teams;
    bytes32 public winner;
    uint256 public totalFundRaised;
    uint256 status = uint256(BetStatus.active);
    mapping(address => Stake) private stakerInfo;
    address[] internal stakers;
    uint256 internal trxBatchSize;
    uint256 internal trxPointer;
    uint256 internal requiredApproval = 1;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not an Admin!");
        _;
    }

    function init(
        address payable _admin,
        address payable _factoryOwner,
        uint256 _maxBetAmt,
        uint256 _closingTime,
        uint256 _fee,
        uint256 _factoryFee,
        uint256 _trxBatchSize,
        bool _is2FA,
        address _token,
        bytes32[] memory _teams
    ) external payable initializer {
        if (_is2FA) {
            requiredApproval = 2;
        }
        admin = _admin;
        factoryOwner = _factoryOwner;
        maxBetAmt = _maxBetAmt;
        closingTime = _closingTime;
        fee = _fee;
        factoryFee = _factoryFee;
        is2FA = _is2FA;
        token = IERC20(_token);
        teams = _teams;
        trxBatchSize = _trxBatchSize;
    }

    function getBetDetails()
        external
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            bool,
            address,
            bytes32[] memory,
            uint256
        )
    {
        return (
            admin,
            maxBetAmt,
            closingTime,
            fee,
            is2FA,
            address(token),
            teams,
            status
        );
    }

    function stake(uint256 teamId, uint256 amount) external payable {
        bool isSuccess = false;
        if (teams[teamId] != "") {
            if (stakerInfo[msg.sender].amount == 0) {
                stakers.push(msg.sender);
            }
            stakerInfo[msg.sender].team = teams[teamId];
            stakerInfo[msg.sender].amount = stakerInfo[msg.sender].amount.add(
                amount
            );
            isSuccess = token.transferFrom(msg.sender, address(this), amount);
            totalFundRaised = totalFundRaised.add(amount);
            emit Staked(msg.sender, amount);
        } else {
            revert("InvalidTeam");
        }
    }

    function withdraw(uint256 amount) external payable {
        uint256 balance = stakerInfo[msg.sender].amount;
        require(amount <= balance, "Invalid amount");
        uint256 availableBalance = balance.sub(amount);
        stakerInfo[msg.sender].amount = availableBalance;
        token.transferFrom(address(this), msg.sender, amount);
        totalFundRaised = totalFundRaised.sub(amount);
        if (availableBalance == 0) {
            for (uint256 index = 0; index < stakers.length; index++) {
                if (msg.sender == stakers[index]) {
                    delete stakers[index];
                }
            }
        }
        emit Withdraw(msg.sender, amount);
    }

    function getBatchDetails() public view returns (uint256, uint256) {
        return (trxPointer, trxBatchSize);
    }

    function refund() external payable {
        uint256 toIndex = trxPointer.add(trxBatchSize);
        for (uint256 index = trxPointer; index < toIndex; index++) {
            address staker = stakers[index];
            token.transferFrom(
                address(this),
                staker,
                stakerInfo[staker].amount
            );
            stakerInfo[staker].amount = 0;
        }
        trxPointer = toIndex;
        if (toIndex == stakers.length) {
            status = uint256(BetStatus.refunded);
        }
    }

    function settleFee() internal {
        uint256 factoryOnwerFee = totalFundRaised.mul(factoryFee).div(10000);
        uint256 adminFee = totalFundRaised.mul(fee).div(10000);
        token.transferFrom(address(this), factoryOwner, factoryOnwerFee);
        token.transferFrom(address(this), admin, adminFee);
        totalFundRaised.sub(factoryOnwerFee.add(adminFee));
    }

    function allocate() internal {
        settleFee();
        for (uint256 index = 0; index < stakers.length; index++) {
            Stake storage staker = stakerInfo[stakers[index]];
            if (winner == staker.team) {
                uint256 prizeInPercent = staker.amount.mul(10000).div(
                    totalFundRaised
                );
                staker.prize = totalFundRaised.mul(prizeInPercent).div(1000);
            }
        }
        status = uint256(BetStatus.completed);
    }

    function declareWinner(uint256 teamId) external {
        if (winner != "") {
            winner = teams[teamId];
        } else {
            require(winner != teams[teamId], "InvalidWinner");
        }
        requiredApproval = requiredApproval.sub(1);
        if (requiredApproval == 0) {
            status = uint256(BetStatus.completed);
            allocate();
        }
    }

    function getStakingInfo(
        address account
    ) public view returns (Stake memory) {
        return stakerInfo[account];
    }
}
