pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "Library/IRoleRegistry.sol";
import "Library/IRewardReserve.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract stETHPool{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
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
        uint256[] temporaryNotClaimedEpochArray;
    }


    
    address registryContract;
    bool initialized;
    uint256 amountOfUser;
    mapping(uint256 => userInfo) internal userDepositInfo;
    mapping(address => uint256) internal userID;
    //mapping(address => userInfo) public userDepositInfo;
    mapping(uint256 => mapping(uint256 => uint256)) internal accumulatedTicket;
    mapping(uint256 => mapping(uint256 => userChangeHistory)) internal changeHistory;
    mapping(address => claimableRewardInfo) internal claimableRewardData;
    uint256 status;
    uint256 poolTVL;
    rewardAllocation AllocationPortion;
    uint256 PercentageDecimal;
    EpochResult[] EpochResults;
    uint256 epochDuration;
    address TokentoDeposit;
    //address StakePoolAddress;
    uint256 minToDeposit;
    uint256 TICKET_DECIMAL;
    

    modifier validEpoch(uint256 epochNumber){
        uint256 latestEpoch = getLatestEpoch();
        require(epochNumber <= latestEpoch,"Invalid epoch number");
        _;
    }

    modifier contractStarted(){
        uint256 epochLength = getEpochLength();
        require(epochLength > 0, "Contract not started");
        _;
    }
    modifier onlyRewardDistributor(){
        address role = IRoleRegistry(registryContract).getRewardDistributor();
        require(msg.sender == role, "Invalid caller");
        _;
    }
    modifier onlyOwner(){
        address role = IRoleRegistry(registryContract).getOwner();
        require(msg.sender == role, "Invalid caller");
        _;
    }

    modifier onlyController(){
        address role = IRoleRegistry(registryContract).getController();
        require(msg.sender == role, "Invalid caller");
        _;
    }

    modifier onlyRouter(){
        address role = IRoleRegistry(registryContract).getRouter();
        require(msg.sender == role, "Invalid caller");
        _;
    }
    modifier nonReentrant(){
        require(status == 0, "Illegal call");
        status = 1;
        _;
        status = 0;
    }
    function initialize(address registryAddress) external{
        require(initialized == false, "Contract is initialized already");
        _transferRegistryAddr(registryAddress);
        initialized = true;
    }
    function _transferRegistryAddr(address registryAddress) internal{
        registryContract = registryAddress;
    }
    function changeRegistryContractAddr(address registryAddress) external onlyOwner{
        _transferRegistryAddr(registryAddress);
    }
    function getMinAmountToDeposit() public view returns(uint256){
        uint256 result = minToDeposit;
        return result;
    }
    function depositFor(address user, uint256 amount) external onlyRouter nonReentrant contractStarted{
        //require(amount >= minToDeposit,"The minimum amount is not met");
        uint256 realDepositAmount = getTokenFromMsgsender(amount);
        updateUserInfo(user, realDepositAmount,true);
    }
    function withdrawFor(address user, uint256 amount) external onlyRouter nonReentrant contractStarted{
        require(amount > 0, "Invalid amount");
        updateUserInfo(user, amount, false);
        sendTokenToMsgsender(amount);
    }
    function updateUserInfo(address user, uint256 amount, bool isDeposit) internal {
        if(isDeposit){
            //get UserID. If userID = 0, set userID + user
            uint256 userIDnow = userID[user];
            bool addNewUser = false;
            //get current amount of user
            if(userIDnow == 0){
                registerNewUser(user);
                addNewUser = true;
            }

            if(addNewUser){
                userIDnow = userID[user];
            }

            _proceedUpdate(userIDnow, amount, isDeposit);
        }
        else if(isDeposit == false){
            uint256 userIDnow = userID[user];
            require(userIDnow != 0, "User not registered");
            _proceedUpdate(userIDnow, amount, isDeposit);
        }
    }
    function _proceedUpdate(uint256 userIDnow, uint256 amount, bool isDeposit) internal{
        uint256 beforeUpdateBalance = userDepositInfo[userIDnow].DepositAmount;
        if(isDeposit){
            userDepositInfo[userIDnow].DepositAmount += amount;
            poolTVL += amount;
        }
        else if(isDeposit == false){
        require(amount<= userDepositInfo[userIDnow].DepositAmount, "Invalid amount");
        userDepositInfo[userIDnow].DepositAmount -= amount;
        poolTVL -= amount;
        }
        uint256 latestUpdatedBlock = userDepositInfo[userIDnow].Lastupdated;
        userDepositInfo[userIDnow].Lastupdated = block.timestamp;
        uint256 afterUpdateBalance = userDepositInfo[userIDnow].DepositAmount;
        uint256 currentEpoch = getLatestEpoch();
        EpochResult storage getEpochDetails = EpochResults[currentEpoch];
        uint256 endBlock = getEpochDetails.createdTimeStamp.add(getEpochDetails.duration);
        require(block.timestamp <= endBlock, "Contract is in the process of updating. Please wait for a while and try again");
        _updateBalanceChange(userIDnow,beforeUpdateBalance,afterUpdateBalance, currentEpoch);
        _updateAccumulatedTicket(userIDnow, beforeUpdateBalance, latestUpdatedBlock, currentEpoch);
        
    }
    function _updateAccumulatedTicket(uint256 userIDnow, uint256 beforeUpdateBalance, uint256 latestUpdatedBlock, uint256 currentEpoch) internal{
        //Get current Epoch info
        EpochResult memory epochInfo = EpochResults[currentEpoch];
        //nếu latestUpdatedBlock nằm trong range currentEpoch -> lấy từ latestUpdatedBlock
        //Nếu latestUpdatedBlock nằm dưới start date -> Lấy từ startBlock
        uint256 epochStartBlock = epochInfo.createdTimeStamp;
        //uint256 epochDuration = epochInfo.duration;
        uint256 epochEndBlock = epochInfo.duration.add(epochStartBlock);
        
        uint256 range;
        if(latestUpdatedBlock<epochStartBlock){
            range = block.timestamp.sub(epochStartBlock);
        }
        else if(latestUpdatedBlock >= epochStartBlock && latestUpdatedBlock<= epochEndBlock){
            range = block.timestamp.sub(latestUpdatedBlock);
        }
        uint256 accumulatedAmount = range.mul(beforeUpdateBalance);
        accumulatedTicket[currentEpoch][userIDnow] += accumulatedAmount;
    }
    function _updateBalanceChange(uint256 userIDnow, uint256 beforeUpdateBalance, uint256 afterUpdateBalance, uint256 currentEpoch) internal{
        changeHistory[currentEpoch][userIDnow].changedwithinEpoch = true;
        changeHistory[currentEpoch][userIDnow].historyArray.push(
        ChangeArray(
        {
            oldAmount: beforeUpdateBalance,
            newAmount: afterUpdateBalance,
            updatedBlock: block.timestamp
        })
        );
        //accumulatedTicket[currentEpoch][userID] = beforeUpdateBalance * ;
    }
    function registerNewUser(address user) internal{
        amountOfUser += 1;
        userID[user] = amountOfUser;
        uint256 newUserID = getUserID(user);
        userDepositInfo[newUserID].userAddress = user;
        userDepositInfo[newUserID].DepositAmount = 0;
        userDepositInfo[newUserID].registeredDate = block.timestamp;
        userDepositInfo[newUserID].Lastupdated = block.timestamp;

    }

    function getTokenFromMsgsender(uint256 amount) internal returns(uint256) {
        uint256 balanceBeforeDeposit = IERC20(TokentoDeposit).balanceOf(address(this));
        IERC20(TokentoDeposit).safeTransferFrom(msg.sender,address(this),amount);
        uint256 balanceAfterDeposit = IERC20(TokentoDeposit).balanceOf(address(this));
        uint256 changeAfterDeposit = balanceAfterDeposit.sub(balanceBeforeDeposit);
        return changeAfterDeposit;
    }
    function sendTokenToMsgsender(uint256 amount) internal{
        IERC20(TokentoDeposit).safeTransfer(msg.sender, amount);
    }
    function claimRewardsFor(address user) external onlyRouter nonReentrant contractStarted returns(uint256){
        uint256 rewardClaimable = claimableRewardData[user].claimable;
        require(rewardClaimable > 0, "No rewards to claim");
        claimableRewardData[user].claimable = 0;
        uint256 notclaimedLength = claimableRewardData[user].temporaryNotClaimedEpochArray.length;
        //claimableRewardData[winners[i]].temporaryNotClaimedEpochArray.push(epochNumber);
        for(uint i=0; i <notclaimedLength;i++){
            uint256 epochNumber = claimableRewardData[user].temporaryNotClaimedEpochArray[i];
            uint256 position = claimableRewardData[user].rewardHistoryArray[i].position;
            //bool epochClaimed;
            EpochResult storage result = EpochResults[epochNumber];
            if(position == 1){
                if(result.first.claimed == false){
                result.first.claimed = true;
                }
            }
            else if(position == 2){
                if(result.second.claimed == false){
                result.second.claimed = true;
                }
            }
            else if(position == 3){
                if(result.third.claimed == false){
                result.third.claimed = true;
                }
            }
        }

        delete claimableRewardData[user].temporaryNotClaimedEpochArray; //Reset array
        uint256 realizedRewardClaimable = sendRewardToRouter(rewardClaimable);        
        return realizedRewardClaimable;
        
    }


    function sendRewardToRouter(uint256 amount) internal returns(uint256){
        address router = IRoleRegistry(registryContract).getRouter();
        uint256 beforeTransfer = IERC20(TokentoDeposit).balanceOf(router);
        address reserve = IRoleRegistry(registryContract).getReserveAddress();
        IRewardReserve(reserve).transferReward(TokentoDeposit,amount,router);
        uint256 afterTransfer = IERC20(TokentoDeposit).balanceOf(router);
        uint256 changeAfterTransfer = afterTransfer.sub(beforeTransfer);
        return changeAfterTransfer;
    }
    
    function getPoolTVL() public view returns(uint256){
        uint256 result = poolTVL;
        return result;
    }
    function getCurrentEpochReward() public view returns(uint256){
        uint256 currentBalance = IERC20(TokentoDeposit).balanceOf(address(this));
        uint256 result = currentBalance.sub(poolTVL);
        return result;
    }
    function getClaimable(address user) public view returns(uint256){
        uint256 result = claimableRewardData[user].claimable;
        return result;
    }
    function getWinningHistory(address user) public view returns(rewardHistory[] memory){
        rewardHistory[] memory result = claimableRewardData[user].rewardHistoryArray;
        return result;
    }
    function getBalanceChangeHistory(address user, uint256 epochNumber) public view contractStarted validEpoch(epochNumber) returns(userChangeHistory memory) {
        uint256 userIDnow = userID[user];
        require(userIDnow != 0, "User hasn't registered");
        userChangeHistory memory result = changeHistory[epochNumber][userIDnow];
        return result;
        
    }
    function getUserID(address user) public view returns(uint256){
        uint256 result = userID[user];
        return result;
    }
    function getUserAmount() public view returns(uint256){
        uint256 result = amountOfUser;
        return result;
    }
    function getuserByID(uint256 userIDnow) public view returns(address){
        address result = userDepositInfo[userIDnow].userAddress;
        return result;
    }
    function getUserDepositInfo(address user) public view returns(userInfo memory){
        uint256 userIDnow = userID[user];
        userInfo memory result = userDepositInfo[userIDnow];
        return result;
    }
    function getAccumulatedTicketwithoutDecimal(uint256 epochNumber, address user) public view contractStarted validEpoch(epochNumber)returns(uint256){
        uint256 userIDnow = userID[user];
        require(userIDnow !=0, "User hasn't registered");
        uint256 result = accumulatedTicket[epochNumber][userIDnow];
        return result;
    }
    function getTicketAmount(uint256 epochNumber, address user) public view returns(uint256){
        uint256 result;
        uint256 PeriodTicketofUser;
        uint256 accumulatedTicketnow = accumulatedTicket[epochNumber][userID[user]];
        //uint256 accumulatedTicket = getAccumulatedTicketwithoutDecimal(epochNumber, user);
        EpochResult memory epochInfo = EpochResults[epochNumber];
        uint256 epochEndBlock = epochInfo.duration.add(epochInfo.createdTimeStamp);
        uint256 userIDnow = userID[user];
        require(userIDnow !=0, "User hasn't registered");
        uint256 userLatestUpdateTimeStamp = userDepositInfo[userIDnow].Lastupdated;
        uint256 userDepositAmount = userDepositInfo[userIDnow].DepositAmount;
        require(userDepositInfo[userIDnow].registeredDate < epochEndBlock, "User has not participated in the epoch");
        userChangeHistory memory getUserBalanceChangeHistory = getBalanceChangeHistory(user, epochNumber);
        if(block.timestamp >= epochInfo.createdTimeStamp && block.timestamp <= epochEndBlock){
            if(userLatestUpdateTimeStamp >= epochInfo.createdTimeStamp && userLatestUpdateTimeStamp <= epochEndBlock){
                PeriodTicketofUser =  (block.timestamp.sub(userLatestUpdateTimeStamp)).mul(userDepositAmount);
            }
            else if(userLatestUpdateTimeStamp < epochInfo.createdTimeStamp){
                PeriodTicketofUser =  (block.timestamp.sub(epochInfo.createdTimeStamp)).mul(userDepositAmount);
            }
            result = (accumulatedTicketnow.add(PeriodTicketofUser)).div((10**TICKET_DECIMAL));
            return result;
        }
        else if(block.timestamp > epochEndBlock){ 
            if(userLatestUpdateTimeStamp<epochInfo.createdTimeStamp){
                result = (epochDuration.mul(userDepositAmount)).div((10**TICKET_DECIMAL));
                return result;
            }
            else{
                if(getUserBalanceChangeHistory.changedwithinEpoch){ 
                uint256 historyLatest = getUserBalanceChangeHistory.historyArray.length.sub(1);
                uint256 latestBlockupdated = getUserBalanceChangeHistory.historyArray[historyLatest].updatedBlock;
                uint256 notAccumulated = (epochEndBlock.sub(latestBlockupdated)).mul(getUserBalanceChangeHistory.historyArray[historyLatest].newAmount);
                result = (accumulatedTicketnow.add(notAccumulated)).div((10**TICKET_DECIMAL));
                return result;
            }
            else if(getUserBalanceChangeHistory.changedwithinEpoch == false){ 
                uint256 epochvar = epochNumber.sub(1);
                for(uint i=0;i<epochNumber;i++){
                    userChangeHistory memory getUserBalanceChangeHistoryVar = getBalanceChangeHistory(user, epochvar);
                    if(getUserBalanceChangeHistoryVar.changedwithinEpoch){
                        uint256 historyLatest = getUserBalanceChangeHistoryVar.historyArray.length.sub(1);
                        uint256 notAccumulated = epochInfo.duration.mul(getUserBalanceChangeHistoryVar.historyArray[historyLatest].newAmount);
                        result = notAccumulated.div((10**TICKET_DECIMAL));
                        break;
                    }
                    epochvar -= 1;
                }
                return result;
            }
            }     
        }
            result = 0;
            return result;
    }
    function getTokenUsing() external view returns(address){
        return TokentoDeposit;
    }
    function getLatestEpoch() public view returns(uint256){
        uint256 length = getEpochLength();
        require(length > 0,"Contract not started");
        uint256 result = length.sub(1);
        return result;
    }
    function getEpochLength() public view returns(uint256){
        uint256 length = EpochResults.length;
        return length;
    }
    function getEpochInfo(uint256 epochNumber) external view returns(EpochResult memory){
        EpochResult memory result = EpochResults[epochNumber];
        return result;
    }
    function getRewardAllocationPercentage() external view returns(rewardAllocation memory){
        return AllocationPortion;
    } 
    function config(address token, uint256 decimal,uint256 minAmount, uint256 duration) external onlyController{
        TokentoDeposit = token;
        TICKET_DECIMAL = decimal;
        epochDuration = duration;
        minToDeposit = minAmount;
    }

    function setRewardRatio(uint256 firstP, uint256 secondP, uint256 thirdP, uint256 percentageSUM) external onlyController{
        require(firstP.add(secondP).add(thirdP) == percentageSUM);
        AllocationPortion.first = firstP;
        AllocationPortion.second = secondP;
        AllocationPortion.third = thirdP;
        PercentageDecimal = percentageSUM;
        emit rewardPortionUpdated(firstP, secondP, thirdP);
    }
    function finalizeEpochTicketandParticipantInfo(uint256 epochNumber) external onlyRewardDistributor{
        EpochResult storage getEpochDetails = EpochResults[epochNumber];
        uint256 endBlock = getEpochDetails.createdTimeStamp.add(getEpochDetails.duration);
        getEpochDetails.totalParticipant = sumUptotalParticipant(epochNumber, endBlock);
    }
    function finalizeEpoch(uint256 epochNumber, address firstWinner, address secondWinner, address thirdWinner, uint256 totalPrize) external onlyRewardDistributor{
        require(getUserID(firstWinner) != 0, "User doesn't exist");
        require(getUserID(secondWinner) != 0, "User doesn't exist");
        require(getUserID(thirdWinner) != 0, "User doesn't exist");
        EpochResult storage getEpochDetails = EpochResults[epochNumber];
        bool isEpochFinalized = getEpochDetails.finalized;
        require(isEpochFinalized == false, "Epoch is done");
        uint256 endBlock = getEpochDetails.createdTimeStamp.add(getEpochDetails.duration);
        require(block.timestamp > endBlock, "Epoch isn't done");
        getEpochDetails.finalized = true;

        uint256 realizedReward = transferRewardToReserve(totalPrize);
        getEpochDetails.totalPrize = realizedReward;
        getEpochDetails.first.winner = firstWinner;
        getEpochDetails.first.prizeAmount = (realizedReward.mul(AllocationPortion.first)).div(PercentageDecimal);
        getEpochDetails.first.claimed = false;
        getEpochDetails.second.winner = secondWinner;
        getEpochDetails.second.prizeAmount = (realizedReward.mul(AllocationPortion.second)).div(PercentageDecimal);
        getEpochDetails.second.claimed = false;
        getEpochDetails.third.winner = thirdWinner;
        getEpochDetails.third.prizeAmount = (realizedReward.mul(AllocationPortion.third)).div(PercentageDecimal);
        getEpochDetails.third.claimed = false;
        address[] memory winners = new address[](3);
        winners[0] = firstWinner;
        winners[1] = secondWinner;
        winners[2] = thirdWinner;
        uint256[] memory PrizeinOrder = new uint256[](3);
        PrizeinOrder[0] = getEpochDetails.first.prizeAmount;
        PrizeinOrder[1] = getEpochDetails.second.prizeAmount;
        PrizeinOrder[2] = getEpochDetails.third.prizeAmount;
        setClaimableRewards(epochNumber,winners,PrizeinOrder);
    }

    function transferRewardToReserve(uint256 totalPrize) internal returns(uint256){
        address reserveAddress = IRoleRegistry(registryContract).getReserveAddress();
        uint256 beforeUpdateBalance = IERC20(TokentoDeposit).balanceOf(reserveAddress);
        IERC20(TokentoDeposit).safeTransfer(reserveAddress,totalPrize);
        uint256 afterUpdateBalance = IERC20(TokentoDeposit).balanceOf(reserveAddress);
        uint256 changeAfterUpdate = afterUpdateBalance.sub(beforeUpdateBalance);
        return changeAfterUpdate;
    }
    function sumUptotalParticipant(uint256 epochNumber, uint256 endBlock) internal view returns(uint256){
        uint256 amountofParticipant;
        for(uint i = 1; i<amountOfUser; i++){ 
            uint256 registeredBlock = userDepositInfo[i].registeredDate;
            address userAddress = userDepositInfo[i].userAddress;
            if(registeredBlock <= endBlock){
                uint256 userTicketAmount = getTicketAmount(epochNumber,userAddress);
                if(userTicketAmount>0){
                    amountofParticipant += 1;
                }
            }
        }
        return amountofParticipant;
    }
    function setClaimableRewards(uint256 epochNumber,address[] memory winners, uint256[] memory PrizeInOrder) internal{
        uint256 winnersLength = winners.length;
        for(uint i=0; i <winnersLength;i++){
            claimableRewardData[winners[i]].claimable += PrizeInOrder[i];
            claimableRewardData[winners[i]].rewardHistoryArray.push(
            rewardHistory(
                {
                EpochNumber: epochNumber,
                position: i.add(1),
                PrizeAmount: PrizeInOrder[i]
                })
            );
            claimableRewardData[winners[i]].temporaryNotClaimedEpochArray.push(epochNumber);
        }
    }
    function createNewEpoch() external onlyRewardDistributor{
        uint256 epochLength = getEpochLength();
        if(epochLength > 0){
            uint256 latestEpochNumber =  epochLength.sub(1);
            EpochResult memory getLastEpochDetails = EpochResults[latestEpochNumber];
            bool lastEpochFinalized = getLastEpochDetails.finalized;
            require(lastEpochFinalized);
        }
        PrizeDetails memory empty;
        empty.winner = 0x0000000000000000000000000000000000000000;
        empty.claimed = false;
        empty.prizeAmount = 0;
        EpochResults.push(
        EpochResult(
        {
            first: empty,
            second: empty,
            third: empty,
            finalized: false,
            totalPrize: 0,
            duration: epochDuration,
            createdTimeStamp: block.timestamp,
            totalParticipant: 0
        })
        );
    }
    }