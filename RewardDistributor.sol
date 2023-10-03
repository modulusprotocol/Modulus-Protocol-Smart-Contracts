pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "Library/IMutualPool.sol";
import "Library/IRoleRegistry.sol";
import "Library/IVRFv2DirectFundingConsumer.sol";

contract RewardDistributor{

    struct RandomnessRequest{
        address poolAddress;
        uint256 epochNumber;
        uint256 DrawRequestID;
        uint256 thisDrawTicketAmount;
        uint32 randomWordsAmount;
        bool fulfilled;
        uint256[] results;
    }
    //function genesisBlockInitialize() external;
    address registryContract;
    bool initialized;
    uint256 currentDrawRequestID;
    uint256 thisDrawTicketAmount;
    RandomnessRequest[] randomnessHistory;
    modifier onlyOwner(){
        address role = IRoleRegistry(registryContract).getOwner();
        require(msg.sender == role, "Invalid caller");
        _;
    }

    

    modifier onlyOperator(){
        address role = IRoleRegistry(registryContract).getOperator();
        require(msg.sender == role, "Invalid caller");
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

    function genesisEpochInitialize(address poolAddress) external onlyOperator{
        IMutualPool(poolAddress).createNewEpoch();
    }

    function ClaimPrizeEpoch(address poolAddress, uint256 epochNumber, bool manualClaimreward) external onlyOperator returns(uint256){
        uint256 rewardclaimed;
        //IMutualPool(poolAddress).finalizeEpochTicketandParticipantInfo(epochNumber);
        if(manualClaimreward){
            rewardclaimed = IMutualPool(poolAddress).claimRewardFromPool();
        }
        else{
            rewardclaimed = IMutualPool(poolAddress).getCurrentEpochReward();
        }
        return rewardclaimed;
        //Sum up total participant and ticket amount
        //Claim prize
        //Request randomness based on the ticket amount got
        //Receive randomness
        //Opt lucky users based on the randomness
        //Set lucky users and finalize epoch
        //Create a new epoch

    }

    function requestRandomness(address poolAddress,uint256 epochNumber, uint256 TotalTicketAmount) external onlyOperator returns(uint256){

        address VRFAddress = IRoleRegistry(registryContract).getVRF();
        uint256 requestID = IVRFv2DirectFundingConsumer(VRFAddress).requestRandomWords(3);

        randomnessHistory.push(RandomnessRequest({
            poolAddress: poolAddress,
            epochNumber: epochNumber,
            DrawRequestID: requestID,
            thisDrawTicketAmount: TotalTicketAmount,
            randomWordsAmount: 3,
            fulfilled: false,
            results: new uint256[](3)
        }));


        uint256 result = randomnessHistory.length - 1;
        return result;
    }


    
    function comeupwithThisDrawLuckyUsers(uint256 requestHistoryID) external onlyOperator returns(uint256[] memory){
        
        //Get the latest draw request
        uint256 requestID = randomnessHistory[requestHistoryID].DrawRequestID;
        uint256 totalTicketAmount = randomnessHistory[requestHistoryID].thisDrawTicketAmount;
        //Call to VRF to get the request info
        address VRFAddress = IRoleRegistry(registryContract).getVRF();
        (, bool fulfilled, uint256[] memory randomWords) = IVRFv2DirectFundingConsumer(VRFAddress).getRequestStatus(requestID);
        require(fulfilled,"The randomness request is not fulfilled, please wait a bit more");
        //uint256[] memory result = new uint256[](randomWords.length);
        for(uint i = 0;i<randomWords.length;i++){
            randomnessHistory[requestHistoryID].results[i] = randomWords[i] % totalTicketAmount;
        }
        randomnessHistory[requestHistoryID].fulfilled = true;

        return randomnessHistory[requestHistoryID].results;
    }
    

    function FinalizeAndCreateNewEpoch(address poolAddress, uint256 epochNumber, address firstWinner, address secondWinner, address thirdWinner, uint256 totalPrize)  external onlyOperator{
        IMutualPool(poolAddress).finalizeEpoch(epochNumber,firstWinner,secondWinner,thirdWinner,totalPrize);
        IMutualPool(poolAddress).createNewEpoch();
    }

    function getRandomnessHistory(uint256 requestHistoryID) public view returns(RandomnessRequest memory) {
        RandomnessRequest memory result = randomnessHistory[requestHistoryID];
        return result;
    }
    


}
