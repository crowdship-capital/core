// contracts/Campaign.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PullPaymentUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./utils/AccessControl.sol";
import "./utils/FactoryInterface.sol";

contract Campaign is
    Initializable,
    AccessControl,
    PullPaymentUpgradeable,
    PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    enum GOALTYPE {
        FIXED,
        FLEXIBLE
    }
    GOALTYPE public goalType;

    event ContributionMade(address approver, uint256 value);

    CampaignFactoryInterface campaignFactoryContract;

    address public root;

    /// @dev `Vote`
    struct Vote {
        bool approved;
        string comment;
        uint256 created;
    }

    /// @dev `Request`
    struct Request {
        string description;
        address payable recepient;
        bool complete;
        uint256 value;
        uint256 approvalCount;
        mapping(address => Vote) approvals;
    }
    Request[] public requests;

    /// @dev `Reward`
    struct Reward {
        uint256 value;
        uint256 deliveryDate;
        bytes32[] inclusions;
        uint256 stock;
        bool exists;
        bool active;
        mapping(address => bool) rewardee; // address being rewarded
        mapping(address => bool) rewarded; // address is rewarded
    }
    Reward[] public rewards;
    mapping(address => uint256[]) userRewardIds;
    mapping(uint256 => uint256) rewardeeCount;

    uint256 public totalCampaignContribution;
    uint256 public minimumContribution;
    uint256 public approversCount;
    uint256 public target;
    uint256 public deadline;
    uint256 public deadlineSetTimes;
    bool public requestOngoing;
    mapping(address => bool) public approvers;
    mapping(address => uint256) public userTotalContribution;
    mapping(address => uint256) public userBalance;

    modifier onlyFactory() {
        require(campaignFactoryContract.canManageCampaigns(msg.sender));
        _;
    }

    modifier adminOrFactory() {
        require(
            campaignFactoryContract.canManageCampaigns(msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        );
        _;
    }

    modifier campaignIsActive() {
        bool campaignIsEnabled;
        bool campaignIsApproved;

        (, , campaignIsEnabled, campaignIsApproved) = campaignFactoryContract
        .deployedCampaigns(campaignFactoryContract.campaignToID(address(this)));

        require(
            campaignIsApproved &&
                campaignIsEnabled &&
                msg.value >= minimumContribution
        );
        _;
    }

    modifier userIsVerified(address _user) {
        bool userVerified;

        (, , , , , userVerified, ) = campaignFactoryContract.users(
            campaignFactoryContract.userID(_user)
        );
        require(userVerified);
        _;
    }

    modifier canApproveRequest(uint256 _requestId) {
        require(
            approvers[msg.sender] &&
                !requests[_requestId].approvals[msg.sender].approved
        );
        _;
    }

    modifier deadlineIsUp() {
        if (goalType == GOALTYPE.FIXED) {
            require(block.timestamp <= deadline);
        }
        _;
    }

    modifier targetIsMet() {
        if (goalType == GOALTYPE.FIXED) {
            require(totalCampaignContribution == target);
        }
        _;
    }

    /// @dev constructor
    function __Campaign_init(
        address _campaignFactory,
        address _root,
        uint256 _minimum
    ) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _root);

        campaignFactoryContract = CampaignFactoryInterface(_campaignFactory);

        root = _root;
        minimumContribution = _minimum;
        goalType = GOALTYPE.FIXED;

        _pause();
    }

    function setCampaignDetails(uint256 _target, uint256 _minimumContribution)
        external
        adminOrFactory
        whenNotPaused
    {
        target = _target;
        minimumContribution = _minimumContribution;
    }

    function setGoalType(uint256 _type) external adminOrFactory whenNotPaused {
        // check that deadline is expired
        require(block.timestamp > deadline);

        goalType = GOALTYPE(_type);
    }

    function extendDeadline(uint256 _time)
        external
        adminOrFactory
        whenNotPaused
    {
        require(
            block.timestamp > deadline &&
                deadlineSetTimes <=
                campaignFactoryContract.deadlineStrikesAllowed()
        );

        // check if time exceeds 7 days and less than a day
        if (
            _time < campaignFactoryContract.maxDeadline() ||
            _time > campaignFactoryContract.minDeadline()
        ) {
            deadline = _time;

            // limit ability to increase deadlines
            deadlineSetTimes = deadlineSetTimes.add(1);
        }
    }

    function revertDeadlineSetTimes() external adminOrFactory whenNotPaused {
        deadlineSetTimes = 0;
        _pause();
    }

    function createRequest(
        string memory _description,
        address payable _recipient,
        uint256 _value
    ) external adminOrFactory targetIsMet whenNotPaused {
        // before creating a new request all previous request should be complete
        require(!requestOngoing);

        Request storage request = requests[requests.length.add(1)];
        request.description = _description;
        request.recepient = _recipient;
        request.complete = false;
        request.value = _value;
        request.approvalCount = 0;

        requestOngoing = true;
    }

    function createReward(
        uint256 _value,
        uint256 _deliveryDate,
        uint256 _stock,
        bytes32[] memory _inclusions,
        bool _active
    ) external adminOrFactory whenNotPaused {
        Reward storage newReward = rewards[rewards.length.add(1)];
        newReward.value = _value;
        newReward.deliveryDate = _deliveryDate;
        newReward.stock = _stock;
        newReward.exists = true;
        newReward.active = _active;
        newReward.inclusions = _inclusions;
    }

    function editReward(
        uint256 _id,
        uint256 _value,
        uint256 _deliveryDate,
        uint256 _stock,
        bytes32[] memory _inclusions,
        bool _active
    ) external adminOrFactory whenNotPaused {
        require(rewards[_id].exists);
        rewards[_id].value = _value;
        rewards[_id].deliveryDate = _deliveryDate;
        rewards[_id].stock = _stock;
        rewards[_id].active = _active;
        rewards[_id].inclusions = _inclusions;
    }

    function destroyReward(uint256 _rewardId)
        public
        adminOrFactory
        whenNotPaused
    {
        require(rewards[_rewardId].exists);

        // set rewardee count to 0
        rewardeeCount[_rewardId] = 0;

        delete rewards[_rewardId];
    }

    function contribute(uint256 _rewardId, bool _withReward)
        public
        payable
        campaignIsActive
        userIsVerified(msg.sender)
        deadlineIsUp
        whenNotPaused
    {
        if (_withReward) {
            require(
                rewards[_rewardId].value == msg.value &&
                    rewards[_rewardId].stock > 0 &&
                    rewards[_rewardId].exists &&
                    rewards[_rewardId].active
            );

            rewards[_rewardId].rewardee[msg.sender] = true;
            rewardeeCount[_rewardId] = rewardeeCount[_rewardId].add(1);
            userRewardIds[msg.sender].push(_rewardId);
        }
        _contribute();
    }

    function _contribute() private {
        approvers[msg.sender] = true;

        if (!approvers[msg.sender]) {
            approversCount.add(1);
        }
        totalCampaignContribution = totalCampaignContribution.add(msg.value);
        userTotalContribution[msg.sender] = userTotalContribution[msg.sender]
        .add(msg.value);
        userBalance[msg.sender] = userBalance[msg.sender].add(msg.value);

        emit ContributionMade(msg.sender, msg.value);
    }

    function pullOwnContribution(address payable _addr)
        external
        userIsVerified(msg.sender)
        whenNotPaused
    {
        // check if person is a contributor
        require(approvers[msg.sender]);

        uint256 balance = userBalance[msg.sender];

        // transfer to msg.sender
        _asyncTransfer(_addr, balance);

        // check if user has reward
        // remove member from persons meant to receive rewards
        // decrement rewardeeCount
        for (
            uint256 index = 0;
            index < userRewardIds[msg.sender].length;
            index++
        ) {
            rewards[userRewardIds[msg.sender][index]].rewardee[
                msg.sender
            ] = false;
            rewardeeCount[userRewardIds[msg.sender][index]].sub(1);
        }

        // set userrewardIds mapping to empty
        uint256[] memory empty;
        userRewardIds[msg.sender] = empty;

        // mark user as a none contributor
        approvers[msg.sender] = false;

        // reduce approvers count
        approversCount.sub(1);

        // decrement total contributions to campaign
        totalCampaignContribution = totalCampaignContribution.sub(balance);
    }

    function voteOnRequest(
        uint256 _requestId,
        bool _vote,
        string memory _comment
    )
        public
        canApproveRequest(_requestId)
        userIsVerified(msg.sender)
        whenNotPaused
    {
        requests[_requestId].approvals[msg.sender].approved = _vote;
        requests[_requestId].approvals[msg.sender].comment = _comment;
        requests[_requestId].approvals[msg.sender].created = block.timestamp;

        // determine user % holdings in the pool
        uint256 percentageHolding = userTotalContribution[msg.sender]
        .div(address(this).balance)
        .mul(100);

        // subtract % holding * request value from user total balance
        userBalance[msg.sender] = userTotalContribution[msg.sender].sub(
            percentageHolding.div(100).mul(requests[_requestId].value)
        );

        if (_vote) {
            requests[_requestId].approvalCount.add(1);
        }
    }

    function finalizeRequest(uint256 _id) public adminOrFactory whenNotPaused {
        Request storage request = requests[_id];
        require(
            request.approvalCount > (approversCount.div(2)) && !request.complete
        );
        // get factory cut
        _asyncTransfer(request.recepient, request.value);
        request.complete = true;
        requestOngoing = false;
    }

    function unPauseCampaign() external whenPaused onlyFactory {
        _unpause();
    }

    function pauseCampaign() external whenNotPaused onlyFactory {
        _pause();
    }
}
