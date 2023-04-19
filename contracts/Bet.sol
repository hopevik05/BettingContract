// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./Config.sol";

contract Bet is Initializable, Config {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    function init(
        address payable admin_,
        address payable owner_,
        uint256 maxBetAmt_,
        uint256 closingTime_,
        uint256 fee_,
        uint256 ownerFee_,
        uint256 trxBatchSize_,
        bool is2FA_,
        address token_,
        bytes32[] memory teams_
    ) external payable initializer {
        if (_is2FA) {
            _leftApproval = 2;
        }
        admin = admin_;
        _owner = owner_;
        _maxBetAmt = maxBetAmt_;
        _closingTime = closingTime_;
        _fee = fee_;
        _ownerFee = ownerFee_;
        _is2FA = is2FA_;
        _token = IERC20(token_);
        _teams = teams_;
        _trxBatchSize = trxBatchSize_;
    }

    function getBetDetails()
        external
        view
        returns (
            address admin,
            uint256 maxBetAmt,
            uint256 closingTime,
            uint256 fee,
            bool is2FA,
            address token,
            bytes32[] memory teams,
            uint256 status
        )
    {
        return (
            admin,
            _maxBetAmt,
            _closingTime,
            _fee,
            _is2FA,
            address(_token),
            _teams,
            status
        );
    }

    function stake(uint256 teamId_, uint256 amount_) external isStakingOpen isActive {
        require(_teams[teamId_] == "", "TEAM_NOT_FOUND");

        if (stakerInfo[msg.sender].amount == 0) {
            stakers.push(msg.sender);
        }

        stakerInfo[msg.sender].team = _teams[teamId_];
        stakerInfo[msg.sender].amount = stakerInfo[msg.sender].amount.add(
            amount_
        );
        _token.transferFrom(msg.sender, address(this), amount_);
        totalFundRaised = totalFundRaised.add(amount_);

        emit Staked(msg.sender, amount_);
    }

    function withdraw(uint256 amount) external payable isStakingOpen isActive {
        uint256 balance = stakerInfo[msg.sender].amount;
        require(amount <= balance, "INSUFFICIENT_FUNDS");
        uint256 availableBalance = balance.sub(amount);
        stakerInfo[msg.sender].amount = availableBalance;
        _token.safeTransfer(msg.sender, amount);
        totalFundRaised = totalFundRaised.sub(amount);
        if (availableBalance == 0) {
            for (uint256 index = 0; index < stakers.length; index++) {
                if (msg.sender == stakers[index]) {
                    delete stakers[index];
                }
            }
        }
        emit Withdrawn(msg.sender, amount);
    }

    function getBatchDetails()
        public
        view
        returns (uint256 trxPointer, uint256 trxBatchSize)
    {
        return (_trxPointer, _trxBatchSize);
    }

    function refund() external payable onlyAdmin isActive {
        uint256 toIndex = _trxPointer.add(_trxBatchSize);
        uint256 fromIndex = _trxPointer;
        for (uint256 index = fromIndex; index < toIndex; index++) {
            address staker = stakers[index];
            _token.safeTransfer(staker, stakerInfo[staker].amount);
            stakerInfo[staker].amount = 0;
        }
        _trxPointer = toIndex;
        if (toIndex == stakers.length) {
            status = uint256(BetStatus.refunded);
        }
        emit Refund(fromIndex, toIndex);
    }

    function cancelBet() external payable onlyAdmin isActive {
        require(totalFundRaised == 0, "BET_HAS_STAKINGS");
        status = uint256(BetStatus.cancelled);
        emit Cancelled();
    }

    function settleFee() internal {
        uint256 onwerFee = totalFundRaised.mul(_ownerFee).div(10000);
        uint256 adminFee = totalFundRaised.mul(_fee).div(10000);
        _token.safeTransfer(_owner, onwerFee);
        _token.safeTransfer(admin, adminFee);
        totalFundRaised.sub(onwerFee.add(adminFee));
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

    function declareWinner(uint256 teamId_) external isActive {
        require(_teams[teamId_] != "", "TEAM_NOT_FOUND");

        if (winner == "") {
            require(msg.sender == admin, "ONLY_ADMIN_ALLOWED");
            winner = _teams[teamId_];
        } else {
            require(msg.sender == admin, "ONLY_OWNER_ALLOWED");
            require(winner == _teams[teamId_], "INVALID_WINNER");
        }
        _leftApproval = _leftApproval.sub(1);
        if (_leftApproval == 0) {
            status = uint256(BetStatus.completed);
            allocate();
        }
        emit WinnerDeclared(msg.sender, _teams[teamId_], _leftApproval);
    }
}
