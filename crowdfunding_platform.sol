// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {

    struct Project {
        address payable creator;  
        uint goal;                
        uint pledgedAmount;       
        uint deadline;            
        bool completed;           
        mapping(address => uint) pledges;  
    }

    Project[] public projects;

    uint public platformFee = 1;  
    address payable public owner;  

    uint public minPledge = 0.001 ether;  
    uint public maxPledge = 1000 ether;    
    uint public softCap = 10 ether;       
    uint public withdrawTimeout = 7 days;  

    mapping(uint => mapping(uint => string)) public rewards;

    mapping(uint => address[]) public projectCreators;
    mapping(address => uint) public creatorShares;

    event ProjectCreated(uint projectId, address creator, uint goal, uint deadline);
    event Pledged(uint projectId, address backer, uint amount);
    event FundsWithdrawn(uint projectId, uint amount);
    event Refunded(uint projectId, address backer, uint amount);

    constructor() {
        owner = payable(msg.sender);  
    }

    function createProject(uint _goal, uint _durationInDays, address[] memory _creators, uint[] memory _shares) public {
        require(_creators.length == _shares.length, "The number of creators and shares must match.");
        uint totalShare = 0;
        for (uint i = 0; i < _shares.length; i++) {
            totalShare += _shares[i];
        }
        require(totalShare == 100, "The total amount of shares should be equal to 100%.");

        Project storage newProject = projects.push();
        newProject.creator = payable(_creators[0]);  
        newProject.goal = _goal;
        newProject.deadline = block.timestamp + (_durationInDays * 1 days);
        newProject.completed = false;

        projectCreators[projects.length - 1] = _creators;
        for (uint i = 0; i < _creators.length; i++) {
            creatorShares[_creators[i]] = _shares[i];
        }

        emit ProjectCreated(projects.length - 1, _creators[0], _goal, newProject.deadline);
    }

    function setReward(uint _projectId, uint _amount, string memory _reward) public {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator, "Only the creator of the project can set rewards.");
        rewards[_projectId][_amount] = _reward;
    }

    function getReward(uint _projectId, uint _amount) public view returns (string memory) {
        return rewards[_projectId][_amount];
    }

    function pledge(uint _projectId) public payable {
        Project storage project = projects[_projectId];
        require(block.timestamp < project.deadline, "The project has expired.");
        require(!project.completed, "The project has already been completed.");
        require(msg.value >= minPledge, "The deposit amount is too small.");
        require(msg.value <= maxPledge, "The deposit amount is too large.");

        project.pledgedAmount += msg.value;
        project.pledges[msg.sender] += msg.value;

        emit Pledged(_projectId, msg.sender, msg.value);
    }

    function withdrawFunds(uint _projectId) public {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator, "Only the creator of the project can withdraw funds.");
        require(block.timestamp > project.deadline, "The project has not been completed yet.");
        require(block.timestamp <= project.deadline + withdrawTimeout, "The deadline for withdrawal of funds has expired.");
        require(project.pledgedAmount >= project.goal, "The fundraising goal has not been achieved.");
        require(!project.completed, "The funds have already been withdrawn.");

        project.completed = true;
        uint fee = (project.pledgedAmount * platformFee) / 100;
        uint amountAfterFee = project.pledgedAmount - fee;

        for (uint i = 0; i < projectCreators[_projectId].length; i++) {
            address creator = projectCreators[_projectId][i];
            uint share = creatorShares[creator];
            uint payout = (amountAfterFee * share) / 100;
            payable(creator).transfer(payout);
        }

        payable(owner).transfer(fee);  

        emit FundsWithdrawn(_projectId, amountAfterFee);
    }

    function refund(uint _projectId) public {
        Project storage project = projects[_projectId];
        require(block.timestamp > project.deadline, "The project has not been completed yet.");
        require(project.pledgedAmount < project.goal, "The goal has been achieved, no refund is possible.");
        require(project.pledges[msg.sender] > 0, "You did not contribute to this project.");

        uint amount = project.pledges[msg.sender];
        project.pledges[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit Refunded(_projectId, msg.sender, amount);
    }

    function partialWithdraw(uint _projectId, uint _amount) public {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator, "Only the creator of the project can withdraw funds.");
        require(block.timestamp > project.deadline, "The project has not been completed yet.");
        require(project.pledgedAmount >= _amount, "The requested amount exceeds the funds collected.");

        project.pledgedAmount -= _amount;
        payable(msg.sender).transfer(_amount);

        emit FundsWithdrawn(_projectId, _amount);
    }

    function getProjectCount() public view returns (uint) {
        return projects.length;
    }

    function getProject(uint _projectId) public view returns (
        address creator,
        uint goal,
        uint pledgedAmount,
        uint deadline,
        bool completed
    ) {
        Project storage project = projects[_projectId];
        return (
            project.creator,
            project.goal,
            project.pledgedAmount,
            project.deadline,
            project.completed
        );
    }
}
