# CampaignFactoryLib





## Contents
<!-- START doctoc -->
<!-- END doctoc -->




## Functions

### canManageCampaigns
>        Returns if caller can manage campaigns


#### Declaration
```solidity
  function canManageCampaigns(
    contract ICampaignFactory _factory,
    address _user
  ) internal returns (bool)
```

#### Modifiers:
No modifiers

#### Args:
| Arg | Type | Description |
| --- | --- | --- |
|`_factory` | contract ICampaignFactory |     Campaign factory interface
|`_user` | address |        Address of caller
---  
### getCampaignFactoryConfig
>        Returns information on a campaign from the factory


#### Declaration
```solidity
  function getCampaignFactoryConfig(
    contract ICampaignFactory _factory,
    string _prop
  ) internal returns (uint256)
```

#### Modifiers:
No modifiers

#### Args:
| Arg | Type | Description |
| --- | --- | --- |
|`_factory` | contract ICampaignFactory |     Campaign factory interface
|`_prop` | string |        Transaction config key
---  
### campaignInfo
>        Returns information on a campaign from the factory


#### Declaration
```solidity
  function campaignInfo(
    contract ICampaignFactory _factory,
    contract Campaign _campaign
  ) internal returns (uint256, bool)
```

#### Modifiers:
No modifiers

#### Args:
| Arg | Type | Description |
| --- | --- | --- |
|`_factory` | contract ICampaignFactory |     Campaign factory interface
|`_campaign` | contract Campaign |    Address of the campaign
---  
### userInfo
>        Returns information about a user from the factory


#### Declaration
```solidity
  function userInfo(
    contract ICampaignFactory _factory,
    address _userAddress
  ) internal returns (uint256, uint256, bool)
```

#### Modifiers:
No modifiers

#### Args:
| Arg | Type | Description |
| --- | --- | --- |
|`_factory` | contract ICampaignFactory |      Campaign factory interface
|`_userAddress` | address |  Address of the user
---  
### sendCommissionFee
>        Sends fee after request finalization to factory


#### Declaration
```solidity
  function sendCommissionFee(
    contract ICampaignFactory _factory,
    contract Campaign _campaign,
    uint256 _amount
  ) internal
```

#### Modifiers:
No modifiers

#### Args:
| Arg | Type | Description |
| --- | --- | --- |
|`_factory` | contract ICampaignFactory |     Campaign factory interface
|`_campaign` | contract Campaign |    Address of campaign sending fee
|`_amount` | uint256 |      Amount being sent
---  
### factoryPercentFee
>        Returns factory percentage cut on all requests per category


#### Declaration
```solidity
  function factoryPercentFee(
    contract ICampaignFactory _factory,
    contract Campaign _campaign
  ) internal returns (uint256)
```

#### Modifiers:
No modifiers

#### Args:
| Arg | Type | Description |
| --- | --- | --- |
|`_factory` | contract ICampaignFactory |     Campaign factory interface
|`_campaign` | contract Campaign |    Address of the campaign
---  


