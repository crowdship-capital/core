// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./CampaignFactory.sol";
import "./Campaign.sol";
import "../utils/Roles.sol";

import "../interfaces/ICampaignFactory.sol";
import "../interfaces/ICampaign.sol";

import "../utils/AccessControl.sol";

import "../libraries/contracts/CampaignFactoryLib.sol";
import "../libraries/contracts/CampaignLib.sol";

contract CampaignReward is Initializable, Roles, PausableUpgradeable {
    using SafeMathUpgradeable for uint256;

    /// @dev `Initializer Event`
    event CampaignRewardOwnerSet(address owner);

    /// @dev `Reward Events`
    event RewardCreated(
        uint256 indexed rewardId,
        uint256 value,
        uint256 deliveryDate,
        uint256 stock,
        string hashedReward,
        bool active
    );
    event RewardModified(
        uint256 indexed rewardId,
        uint256 value,
        uint256 deliveryDate,
        uint256 stock,
        bool active
    );
    event RewardStockIncreased(uint256 indexed rewardId, uint256 count);
    event RewardDestroyed(uint256 indexed rewardId);

    /// @dev `Rward Recipient Events`
    event RewardRecipientAdded(
        uint256 indexed rewardRecipientId,
        uint256 indexed rewardId,
        uint256 amount,
        address indexed user
    );
    event RewarderApproval(uint256 indexed rewardRecipientId, bool status);
    event RewardRecipientApproval(uint256 indexed rewardRecipientId);

    ICampaignFactory public campaignFactoryInterface;
    ICampaign public campaignInterface;

    address public campaignRewardAddress;
    Campaign public campaign;

    /// @dev `Reward`
    struct Reward {
        uint256 value;
        uint256 deliveryDate;
        uint256 stock;
        string hashedReward;
        bool exists;
        bool active;
    }
    Reward[] public rewards;
    mapping(uint256 => uint256) public rewardToRewardRecipientCount; // number of users eligible per reward

    /// @dev `RewardRecipient`
    struct RewardRecipient {
        uint256 rewardId;
        address user;
        bool deliveryConfirmedByCampaign;
        bool deliveryConfirmedByUser;
    }
    RewardRecipient[] public rewardRecipients;
    mapping(address => uint256) public userRewardCount; // number of rewards owned by a user

    /// @dev Ensures a user is verified
    modifier userIsVerified(address _user) {
        bool verified;
        (, , verified) = CampaignFactoryLib.userInfo(
            campaignFactoryInterface,
            _user
        );
        require(verified, "user not verified");
        _;
    }

    /// @dev Ensures caller is a registered campaign contract from factory
    modifier onlyRegisteredCampaigns() {
        require(address(campaign) == msg.sender, "forbidden");
        _;
    }

    /// @dev Ensures caller is campaign owner
    modifier hasRole(bytes32 _permission, address _user) {
        require(campaignInterface.isAllowed(_permission, _user));
        _;
    }

    /**
     * @dev        Constructor
     * @param      _campaignFactory     Address of factory
     * @param      _campaign            Address of campaign this contract belongs to
     */
    function __CampaignReward_init(
        CampaignFactory _campaignFactory,
        Campaign _campaign
    ) public initializer {
        campaignFactoryInterface = ICampaignFactory(address(_campaignFactory));
        campaignInterface = ICampaign(address(_campaign));

        campaign = _campaign;
        campaignRewardAddress = address(this);

        emit CampaignRewardOwnerSet(msg.sender);
    }

    /**
     * @dev        Creates rewards contributors can attain
     * @param      _value        Reward cost
     * @param      _deliveryDate Time in which reward will be deliverd to contriutors
     * @param      _stock        Quantity available for dispatch
     * @param      _hashedReward CID reference of the reward on IPFS
     * @param      _active       Indicates if contributors can attain the reward
     */
    function createReward(
        uint256 _value,
        uint256 _deliveryDate,
        uint256 _stock,
        string memory _hashedReward,
        bool _active
    ) external hasRole(CREATE_REWARD, msg.sender) userIsVerified(msg.sender) {
        require(
            _value >
                CampaignFactoryLib.getCampaignFactoryConfig(
                    campaignFactoryInterface,
                    "minimumContributionAllowed"
                ),
            "amount too low"
        );
        require(
            _value <
                CampaignFactoryLib.getCampaignFactoryConfig(
                    campaignFactoryInterface,
                    "maximumContributionAllowed"
                ),
            "amount too high"
        );
        rewards.push(
            Reward(_value, _deliveryDate, _stock, _hashedReward, true, _active)
        );

        emit RewardCreated(
            rewards.length.sub(1),
            _value,
            _deliveryDate,
            _stock,
            _hashedReward,
            _active
        );
    }

    /**
     * @dev        Assigns a reward to a user after payment from parent contract Campaign
     * @param      _rewardId     ID of the reward being assigned
     * @param      _amount       Amount being paid by the user
     * @param      _user         Address of user reward is being assigned to
     */
    function assignReward(
        uint256 _rewardId,
        uint256 _amount,
        address _user
    ) external onlyRegisteredCampaigns userIsVerified(_user) returns (uint256) {
        require(_amount >= rewards[_rewardId].value, "amount too low");
        require(rewards[_rewardId].stock >= 1, "out of stock");
        require(rewards[_rewardId].exists, "not found");
        require(rewards[_rewardId].active, "not active");

        rewardRecipients.push(RewardRecipient(_rewardId, _user, false, false));
        userRewardCount[_user] = userRewardCount[_user].add(1);
        rewardToRewardRecipientCount[_rewardId] = rewardToRewardRecipientCount[
            _rewardId
        ].add(1);

        emit RewardRecipientAdded(
            rewardRecipients.length.sub(1),
            _rewardId,
            _amount,
            _user
        );

        return rewardRecipients.length.sub(1);
    }

    /**
     * @dev        Modifies a reward by id
     * @param      _rewardId        Reward unique id
     * @param      _value           Reward cost
     * @param      _deliveryDate    Time in which reward will be deliverd to contriutors
     * @param      _stock           Quantity available for dispatch
     * @param      _active          Indicates if contributors can attain the reward
     * @param      _hashedReward    Initial or new CID refrence of the reward on IPFS
     */
    function modifyReward(
        uint256 _rewardId,
        uint256 _value,
        uint256 _deliveryDate,
        uint256 _stock,
        bool _active,
        string memory _hashedReward
    ) external hasRole(MODIFY_REWARD, msg.sender) {
        /**
         * To modify a reward:
         * check reward has no backers
         * check reward exists
         */
        require(rewards[_rewardId].exists, "not found");
        require(rewardToRewardRecipientCount[_rewardId] < 1, "has backers");
        require(
            _value >
                CampaignFactoryLib.getCampaignFactoryConfig(
                    campaignFactoryInterface,
                    "minimumContributionAllowed"
                ),
            "amount too low"
        );
        require(
            _value <
                CampaignFactoryLib.getCampaignFactoryConfig(
                    campaignFactoryInterface,
                    "maximumContributionAllowed"
                ),
            "amount too high"
        );

        rewards[_rewardId].value = _value;
        rewards[_rewardId].deliveryDate = _deliveryDate;
        rewards[_rewardId].stock = _stock;
        rewards[_rewardId].active = _active;
        rewards[_rewardId].hashedReward = _hashedReward;

        emit RewardModified(_rewardId, _value, _deliveryDate, _stock, _active);
    }

    /**
     * @dev        Increases a reward stock count
     * @param      _rewardId        Reward unique id
     * @param      _count           Stock count to increase by
     */
    function increaseRewardStock(uint256 _rewardId, uint256 _count)
        external
        hasRole(MODIFY_REWARD, msg.sender)
    {
        require(rewards[_rewardId].exists, "not found");
        rewards[_rewardId].stock = rewards[_rewardId].stock.add(_count);

        emit RewardStockIncreased(_rewardId, _count);
    }

    /**
     * @dev        Deletes a reward by id
     * @param      _rewardId    Reward unique id
     */
    function destroyReward(uint256 _rewardId)
        external
        hasRole(DESTROY_REWARD, msg.sender)
    {
        // check reward has no backers
        require(rewardToRewardRecipientCount[_rewardId] < 1, "has backers");
        require(rewards[_rewardId].exists, "not found");

        delete rewards[_rewardId];

        emit RewardDestroyed(_rewardId);
    }

    /**
     * @dev        Called by the campaign owner to indicate they delivered the reward to the rewardRecipient
     * @param      _rewardRecipientId   ID to struct containing reward and user to be rewarded
     * @param      _status              Indicates if the delivery was successful or not
     */
    function campaignSentReward(uint256 _rewardRecipientId, bool _status)
        external
        hasRole(MODIFY_REWARD, msg.sender)
    {
        require(
            rewardToRewardRecipientCount[
                rewardRecipients[_rewardRecipientId].rewardId
            ] >= 1
        );

        rewardRecipients[_rewardRecipientId]
            .deliveryConfirmedByCampaign = _status;
        emit RewarderApproval(_rewardRecipientId, _status);
    }

    /**
     * @dev        Called by a user eligible for rewards to indicate they received their reward
     * @param      _rewardRecipientId  ID to struct containing reward and user to be rewarded
     */
    function userReceivedCampaignReward(uint256 _rewardRecipientId)
        external
        userIsVerified(msg.sender)
    {
        require(
            CampaignLib.isAnApprover(campaignInterface, msg.sender),
            "not an approver"
        );
        require(
            rewardRecipients[_rewardRecipientId].deliveryConfirmedByCampaign,
            "reward not delivered yet"
        );
        require(
            !rewardRecipients[_rewardRecipientId].deliveryConfirmedByUser,
            "reward already marked as sent"
        );
        require(
            rewardRecipients[_rewardRecipientId].user == msg.sender,
            "not owner of reward"
        );

        require(userRewardCount[msg.sender] >= 1, "you have no reward");

        rewardRecipients[_rewardRecipientId].deliveryConfirmedByUser = true;
        emit RewardRecipientApproval(_rewardRecipientId);
    }

    /**
     * @dev        Renounces rewards owned by the specified user
     * @param      _user        Address of user who rewards are being renounced
     */
    function renounceRewards(address _user) external onlyRegisteredCampaigns {
        if (userRewardCount[_user] >= 1) {
            userRewardCount[_user] = 0;

            // deduct rewardRecipients count
            for (uint256 index = 0; index < rewardRecipients.length; index++) {
                rewardToRewardRecipientCount[
                    rewardRecipients[index].rewardId
                ] = rewardToRewardRecipientCount[
                    rewardRecipients[index].rewardId
                ].sub(1);
            }
        }
    }

    /**
     * @dev        Transfers rewards from the old owner to a new owner
     * @param      _oldAddress      Address of previous owner of rewards
     * @param      _newAddress      Address of new owner rewards are being transferred to
     */
    function transferRewards(address _oldAddress, address _newAddress)
        external
        onlyRegisteredCampaigns
    {
        if (userRewardCount[_oldAddress] >= 1) {
            userRewardCount[_newAddress] = userRewardCount[_oldAddress];
            userRewardCount[_oldAddress] = 0;

            for (uint256 index = 0; index < rewardRecipients.length; index++) {
                if (rewardRecipients[index].user == _oldAddress) {
                    rewardRecipients[index].user = _newAddress;
                }
            }
        }
    }
}
