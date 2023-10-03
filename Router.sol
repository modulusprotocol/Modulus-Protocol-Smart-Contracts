pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "Library/IMutualPool.sol";
import "Library/IRoleRegistry.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Router{

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
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
        //uint256 totalParticipant;
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
    


    event OwnershipTransferred(address oldOwner, address newOwner);
    event ControllerRoleTransferred(address oldController, address newController);
    event deposited(address who, address poolAddress, uint256 amount);
    event withdrawn(address who, address poolAddress, uint256 amount);
    event EpochRewardClaimed(address who, address poolAddress, address Token, uint256 amount);

    uint256 status;
    struct _PoolDetails{
        address PoolAddress;
        address PoolTokenToUse;
    }
    _PoolDetails[] PoolDetail; 
    address registryContract;
    bool initialized;
    address KyberAggregator;
    mapping(address => bool) public allowedPool;


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

    modifier nonReentrant(){
        require(status == 0, "Illegal call");
        status = 1;
        _;
        status = 0;
    }
    modifier validPoolID(uint256 poolID){
        uint256 poolLength = PoolDetail.length;
        require(poolID <= poolLength.sub(1), "Pool doesn't exist");
        _;
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



    /*View functions*/
    function getRewardClaimable(address user, uint256 poolID) external validPoolID(poolID) view returns(uint256){
        address poolAddress = getPoolDetails(poolID).PoolAddress;
        uint256 result = IMutualPool(poolAddress).getClaimable(user);
        return result;
    }

    /*function getMinToDeposit(uint256 poolID) public validPoolID(poolID) view returns(uint256){
        address poolAddress = getPoolDetails(poolID).PoolAddress;
        uint256 result = IMutualPool(poolAddress).getMinAmountToDeposit();
        return result;
    }*/
    function getPoolLength() external view returns(uint256){
        uint256 poolLength = PoolDetail.length;
        return poolLength;
    }

    function getPoolDetails(uint256 poolID) public validPoolID(poolID) view returns(_PoolDetails memory){
        _PoolDetails memory getDetails = PoolDetail[poolID];
        return getDetails;
    }

    function getPoolTVL(uint256 poolID) public validPoolID(poolID) view returns(uint256){
        address poolAddress = getPoolDetails(poolID).PoolAddress;
        uint256 result = IMutualPool(poolAddress).getPoolTVL();
        return result;
    }
    function getPoolCurrentYield(uint256 poolID) external validPoolID(poolID) view returns(uint256){
        address poolAddress = getPoolDetails(poolID).PoolAddress;
        uint256 result = IMutualPool(poolAddress).getCurrentEpochReward();
        return result;
    }
    function getUserDepositInfo(uint256 poolID, address user) external validPoolID(poolID) view returns(userInfo memory){
        address poolAddress = getPoolDetails(poolID).PoolAddress;
        userInfo memory result = userInfo({
        userAddress: user,
        DepositAmount: IMutualPool(poolAddress).getUserDepositInfo(user).DepositAmount,
        registeredDate: IMutualPool(poolAddress).getUserDepositInfo(user).registeredDate,
        Lastupdated: IMutualPool(poolAddress).getUserDepositInfo(user).Lastupdated
        });
        return result;
    }


    function getPoolLatestEpoch(uint256 poolID) public validPoolID(poolID) view returns(uint256){
        address poolAddress = getPoolDetails(poolID).PoolAddress;
        uint256 result = IMutualPool(poolAddress).getLatestEpoch();
        return result;
    }
    function getUserTicketAmountByPoolID(uint256 epochNumber, uint256 poolID, address user) external validPoolID(poolID) view returns(uint256){
        address poolAddress = getPoolDetails(poolID).PoolAddress;
        uint256 result = IMutualPool(poolAddress).getTicketAmount(epochNumber,user);
        return result;
        
    }

    function getPoolDrawInfo(uint256 epochNumber,uint256 poolID) external validPoolID(poolID) view returns(EpochResult memory){
        address poolAddress = getPoolDetails(poolID).PoolAddress;

        PrizeDetails memory firstDetails = PrizeDetails({
            winner: IMutualPool(poolAddress).getEpochInfo(epochNumber).first.winner,
            prizeAmount : IMutualPool(poolAddress).getEpochInfo(epochNumber).first.prizeAmount,
            claimed : IMutualPool(poolAddress).getEpochInfo(epochNumber).first.claimed
        });
        PrizeDetails memory secondDetails = PrizeDetails({
            winner: IMutualPool(poolAddress).getEpochInfo(epochNumber).second.winner,
            prizeAmount : IMutualPool(poolAddress).getEpochInfo(epochNumber).second.prizeAmount,
            claimed : IMutualPool(poolAddress).getEpochInfo(epochNumber).second.claimed
        });
        PrizeDetails memory thirdDetails = PrizeDetails({
            winner: IMutualPool(poolAddress).getEpochInfo(epochNumber).third.winner,
            prizeAmount : IMutualPool(poolAddress).getEpochInfo(epochNumber).third.prizeAmount,
            claimed : IMutualPool(poolAddress).getEpochInfo(epochNumber).third.claimed
        });

        EpochResult memory result = EpochResult({
            first: firstDetails,
            second: secondDetails,
            third: thirdDetails,
            finalized: IMutualPool(poolAddress).getEpochInfo(epochNumber).finalized,
            totalPrize: IMutualPool(poolAddress).getEpochInfo(epochNumber).totalPrize,
            duration: IMutualPool(poolAddress).getEpochInfo(epochNumber).duration,
            createdTimeStamp: IMutualPool(poolAddress).getEpochInfo(epochNumber).createdTimeStamp
            //totalParticipant: IMutualPool(poolAddress).getEpochInfo(epochNumber).totalParticipant
        });
        return result;
        
    }


    /*View functions to get info from pool*/


    /*View functions*/

    /* ***** Public functions **** */
    
    function deposit(uint256 poolID, uint256 amount) external validPoolID(poolID) nonReentrant{
        _PoolDetails memory getDetails = PoolDetail[poolID];
        address poolAddress = getDetails.PoolAddress;
        address tokenToUseNow = getDetails.PoolTokenToUse;
        uint256 amountToDeposit = getTokenFromUser(tokenToUseNow, amount);
        depositToPool(msg.sender, poolAddress, tokenToUseNow, amountToDeposit);
        emit deposited(msg.sender, poolAddress, amountToDeposit);
    }

    function depositToPool(address user, address pool, address token, uint256 amount) internal{
        _approveToPool(pool,token,amount);
        _processDeposit(user, pool, amount);
    }

    function _processDeposit(address user, address pool, uint256 amount) internal{
        IMutualPool(pool).depositFor(user, amount);
    }

    function _approveToPool(address pool, address token, uint256 amount) internal{
        IERC20(token).safeApprove(pool, 0);
        IERC20(token).safeApprove(pool, amount);
    }
    function getTokenFromUser(address token, uint256 amount) internal returns(uint256){
        require(amount > 0);
        uint256 balanceBeforeTransferFrom = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfterTransferFrom = IERC20(token).balanceOf(address(this));
        uint256 amountDeposisted = balanceAfterTransferFrom.sub(balanceBeforeTransferFrom);
        //require(amountDeposisted >= amount, "Deposit failed, couldn't transfer tokens from user");
        return amountDeposisted;
    }

    function withdraw(uint256 poolID, uint256 amount) external validPoolID(poolID) nonReentrant{
        _PoolDetails memory getDetails = PoolDetail[poolID];
        address poolAddress = getDetails.PoolAddress;
        address tokenToUseNow = getDetails.PoolTokenToUse;
        withdrawFromPool(msg.sender, poolAddress,tokenToUseNow,amount);
        emit withdrawn(msg.sender, poolAddress, amount);

    }

    function withdrawFromPool(address user, address pool,address token, uint256 amount) internal{
        uint256 balanceBeforeWithdraw = IERC20(token).balanceOf(address(this));
        _processWithdraw(user, pool, amount);

        uint256 balanceAfterWithdraw = IERC20(token).balanceOf(address(this));

        uint256 withdrawnAmount = balanceAfterWithdraw.sub(balanceBeforeWithdraw);

        _processTransferBacktoUser(user, token, withdrawnAmount);
    }

    function _processTransferBacktoUser(address receiver, address token, uint256 amount) internal{
        IERC20(token).safeTransfer(receiver, amount);
    }
    function _processWithdraw(address user, address pool, uint256 amount) internal{
        require(amount > 0);
        IMutualPool(pool).withdrawFor(user, amount);
    }

    function claimReward(uint256 poolID) external validPoolID(poolID) nonReentrant{

        _PoolDetails memory getDetails = PoolDetail[poolID];
        address poolAddress = getDetails.PoolAddress;
        address tokenToUseNow = getDetails.PoolTokenToUse;

        uint256 balanceBeforeClaim = IERC20(tokenToUseNow).balanceOf(address(this));
        uint256 rewardClaimed = _processClaimReward(msg.sender, poolAddress);
        uint256 balanceAfterClaim = IERC20(tokenToUseNow).balanceOf(address(this));
        uint256 balanceChange = balanceAfterClaim.sub(balanceBeforeClaim);
        //require(balanceChange >= rewardClaimed);

        _processTransferBacktoUser(msg.sender, tokenToUseNow, balanceChange);

        emit EpochRewardClaimed(msg.sender,poolAddress,tokenToUseNow,rewardClaimed);
    }

    function _processClaimReward(address user, address pool) internal returns(uint256) {
        uint256 amount = IMutualPool(pool).claimRewardsFor(user);
        require(amount > 0, "No rewards to claim");
        return amount;
    }

    /* ***** Public functions **** */



    /* *****Controller Role Function******* */
    function addPool(address _poolAddress) external onlyController{
        address PoolToken = IMutualPool(_poolAddress).getTokenUsing();
        PoolDetail.push(_PoolDetails({
            PoolAddress: _poolAddress,
            PoolTokenToUse: PoolToken
        }));

        allowedPool[_poolAddress] = true;
    }

    function removePool(uint256 poolID) external onlyController{
        uint256 poolLength = PoolDetail.length;
        require(poolID <= poolLength-1, "Pool doesn't exist");
        address poolAddress = PoolDetail[poolID].PoolAddress;
        delete PoolDetail[poolID];
        allowedPool[poolAddress] = false;
    }

    function changeAggregatorAddress(address router) external onlyController{ 
        KyberAggregator = router;
    }



    function isPoolAllowed(address _poolAddress) public view returns(bool){
        bool result = allowedPool[_poolAddress];
        return result;
    }
    //Add function to remove/edit pool

    /* *****Controller Role Function******* */

    /* *****Owner Role Function******* */

    function zap(uint256 poolID, address tokenIn, uint256 amount, bytes calldata swapData) external validPoolID(poolID) nonReentrant payable{
        //That's fine to let the router approve any tokens to Kyber's aggregator. However, the amount and the token predefined may not match those in the swapData. However, if it's mismatch, it would revert btw. Please be careful for callback via Kyber
        _PoolDetails memory getDetails = PoolDetail[poolID];
        address poolAddress = getDetails.PoolAddress;
        address tokenToUseNow = getDetails.PoolTokenToUse;
        _checkSwapData(swapData);
        uint256 toDeposit = performSwap(tokenToUseNow, tokenIn,amount,swapData);
        depositToPool(msg.sender, poolAddress, tokenToUseNow, toDeposit);
    }

    function _checkSwapData(bytes calldata swapData) internal pure{
        bytes4 selector;
            assembly {
            selector := calldataload(swapData.offset)
            }

        if(selector == 0x23b872dd || selector == 0xa9059cbb || selector == 0x095ea7b3){
            revert();
        }
    }

    function performSwap(address tokenNeeded, address tokenToSwap, uint256 amountIn, bytes calldata swapData) internal returns(uint256){
        uint256 beforeSwap = IERC20(tokenNeeded).balanceOf(address(this));
        _performSwap(tokenToSwap,amountIn,swapData);
        uint256 afterSwap = IERC20(tokenNeeded).balanceOf(address(this));
        uint256 changeAfterSwap = afterSwap.sub(beforeSwap);
        require(changeAfterSwap>0);
        return changeAfterSwap;
    }

    function _performSwap(address tokenToSwap, uint256 amountIn, bytes calldata swapData) internal{

        

        if(tokenToSwap == 0x0000000000000000000000000000000000000000){
            require(msg.value>= amountIn);
            (bool success, ) = KyberAggregator.call{value: amountIn}(swapData);
            require(success,"Couldn't swap");
        }
        else{
            require(msg.value == 0);
            uint256 toApprove = getTokenFromUser(tokenToSwap, amountIn);
            IERC20(tokenToSwap).safeApprove(KyberAggregator,0);
            IERC20(tokenToSwap).safeApprove(KyberAggregator,toApprove);
            (bool success, ) = KyberAggregator.call{value: 0}(swapData);
            IERC20(tokenToSwap).safeApprove(KyberAggregator,0);
            require(success,"Couldn't swap");
        }
    }

    receive() external payable{
        //do nothing
    }

}
