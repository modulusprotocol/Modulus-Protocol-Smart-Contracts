pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "Library/IMutualPool.sol";
import "Library/IRoleRegistry.sol";

interface IRouter{


    struct PrizeDetails{
        address winner;
        uint256 prizeAmount;
        bool claimed;
    }
    struct EpochResult{
        PrizeDetails first;
        PrizeDetails second;
        PrizeDetails third;
        bool finalized;
        uint256 totalPrize;
        uint256 duration;
        uint256 createdTimeStamp;
        uint256 totalParticipant;
    }

    struct rewardAllocation{
        uint256 first;
        uint256 second;
        uint256 third;
    }
    struct userInfo{
        address userAddress;
        uint256 DepositAmount;
        uint256 registeredDate;
        uint256 Lastupdated;
        //uint256 depositTimeStamp;
    }
    struct ChangeArray{
        uint256 oldAmount;
        uint256 newAmount;
        uint256 updatedBlock;
    }
    struct userChangeHistory{
        bool changedwithinEpoch;
        ChangeArray[] historyArray;
    }
    struct rewardHistory{
        uint256 EpochNumber;
        uint256 position;
        uint256 PrizeAmount;
    }
    struct claimableRewardInfo{
        uint256 claimable;
        rewardHistory[] rewardHistoryArray;
    }
    struct _PoolDetails{
        address PoolAddress;
        address PoolTokenToUse;
    }

    event OwnershipTransferred(address oldOwner, address newOwner);
    event ControllerRoleTransferred(address oldController, address newController);
    event deposited(address who, address poolAddress, uint256 amount);
    event withdrawn(address who, address poolAddress, uint256 amount);
    event EpochRewardClaimed(address who, address poolAddress, address Token, uint256 amount);
    /*
    Need to initialize
    */


    



    /*View functions*/

    function getPoolLength() external view returns(uint256);

    function getPoolDetails(uint256 poolID) external view returns(_PoolDetails memory);

    function getPoolTVL(uint256 poolID) external view returns(uint256);
    function getPoolCurrentYield(uint256 poolID) external view returns(uint256);
    function getUserDepositInfo(uint256 poolID, address user) external view returns(userInfo memory);

    function getMinToDeposit(uint256 poolID) external view returns(uint256);
    function getPoolLatestEpoch(uint256 poolID) external view returns(uint256);
    function getUserTicketAmountByPoolID(uint256 epochNumber, uint256 poolID, address user) external view returns(uint256);

    function getPoolDrawInfo(uint256 epochNumber,uint256 poolID) external view returns(EpochResult memory);
    function getRewardClaimable(address user, uint256 poolID) external view returns(uint256);
    function isPoolAllowed(address _poolAddress) external view returns(bool);


    /*View functions to get info from pool*/


    /*View functions*/

    /* ***** Public functions **** */
    function initialize(address registryAddress) external;
    function changeRegistryContractAddr(address registryAddress) external;
    function deposit(uint256 poolID, uint256 amount) external;
    function withdraw(uint256 poolID, uint256 amount) external;
    function claimReward(uint256 poolID) external;
    function addPool(address _poolAddress) external;
    function removePool(uint256 poolID) external;

}