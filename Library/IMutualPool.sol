

pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0



interface IMutualPool{
    event rewardPortionUpdated(uint256 first, uint256 second, uint256 third);
    event OwnershipTransferred(address oldOwner, address newOwner);
    event ControllerRoleTransferred(address oldController, address newController);
    event changedRouter(address oldRouter, address newRouter);


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


    function initialize(address registryAddress) external;
    function changeRegistryContractAddr(address registryAddress) external;

    /*Only Router functions */
    function depositFor(address user, uint256 amount) external;
    function withdrawFor(address user, uint256 amount) external;
    function claimRewardsFor(address user) external returns(uint256);


    /*View Area*/
    function getPoolTVL() external view returns(uint256);
    function getCurrentEpochReward() external view returns(uint256);
    function getClaimable(address user) external view returns(uint256);
    
    function getWinningHistory(address user) external view returns(rewardHistory[] memory);
    function getBalanceChangeHistory(address user, uint256 epochNumber) external view returns(userChangeHistory memory);
    function getUserID(address user) external view returns(uint256);

    function getUserAmount() external view returns(uint256);
    function getuserByID(uint256 userID) external view returns(address);
    function getUserDepositInfo(address user) external view returns(userInfo memory);
    function getAccumulatedTicketwithoutDecimal(uint256 epochNumber, address user) external view returns(uint256);
    function getTicketAmount(uint256 epochNumber, address user) external view returns(uint256);
    function getTokenUsing() external view returns(address);
    function getLatestEpoch() external view returns(uint256);
    function getEpochLength() external view returns(uint256);
    function getEpochInfo(uint256 epochNumber) external view returns(EpochResult memory);
    function getRewardAllocationPercentage() external view returns(rewardAllocation memory);
    function getMinAmountToDeposit() external view returns(uint256);

    
    function setToken(address token) external;
    function setTicketDecimal(uint256 decimal) external;
    function setStakePoolAddress(address StakePoolAdd) external;
    function setEpochDuration(uint256 duration) external;
    function setMinAmounttoDeposit(uint256 amount) external;
    function setRewardRatio(uint256 firstP, uint256 secondP, uint256 thirdP, uint256 percentageSUM) external;
    
    function finalizeEpochTicketandParticipantInfo(uint256 epochNumber) external;
    function finalizeEpoch(uint256 epochNumber, address firstWinner, address secondWinner, address thirdWinner, uint256 totalPrize) external;

    function createNewEpoch() external;
    function claimRewardFromPool() external returns(uint256);
    

}


