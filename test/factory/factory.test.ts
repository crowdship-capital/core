export {};
const { expect } = require('chai');

// Load compiled artifacts
const Factory = artifacts.require('CampaignFactory');
const Campaign = artifacts.require('Campaign');
const CampaignRewards = artifacts.require('CampaignRewards');
const TestToken = artifacts.require('TestToken');

const userTests = require('./resources/users.test');
const categoryTests = require('./resources/categories.test');
const campaignTests = require('./resources/campaigns.test');
const featurePackageTests = require('./resources/featurepackage.test');
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

// Start test block
contract(
  'CampaignFactory',
  function ([
    owner,
    factoryWallet,
    addr1,
    addr2,
    addr3,
    addr4,
    otherFactoryWallet,
  ]) {
    beforeEach(async function () {
      this.factory = await Factory.new();
      this.testToken = await TestToken.new();
      this.campaign = await Campaign.new();
      this.campaignRewards = await CampaignRewards.new();
      this.owner = owner;
      this.factoryWallet = factoryWallet;
      this.addr1 = addr1;
      this.addr2 = addr2;
      this.addr3 = addr3;
      this.addr4 = addr4;

      await this.factory.__CampaignFactory_init(this.factoryWallet, {
        from: this.owner,
      });

      await this.factory.setFactoryConfig(
        otherFactoryWallet,
        this.campaign.address,
        this.campaignRewards.address
      );

      await this.testToken.__TestToken_init('Test Token', 'TT', {
        from: this.owner,
      });

      // approve admin
      const adminId = await this.factory.userID(this.owner);
      await this.factory.toggleUserApproval(adminId, true);

      await this.factory.signUp({
        from: this.addr1,
      });

      await this.factory.signUp({
        from: this.addr2,
      });

      // add token
      await this.factory.addToken(this.testToken.address);

      // approve token
      await this.factory.toggleAcceptedToken(this.testToken.address, true);

      this.factorySettings = {
        deadlineStrikesAllowed: 3,
        maxDeadlineExtension: 604800,
        minDeadlineExtension: 86400,
        minimumContributionAllowed: 1,
        maximumContributionAllowed: 10000,
        minRequestDuration: 86400,
        maxRequestDuration: 604800,
        minimumRequestAmountAllowed: 1000,
        maximumRequestAmountAllowed: 10000,
        reviewThresholdMark: 80,
        minimumCampaignTarget: 5000,
        maximumCampaignTarget: 10000000,
      };
    });

    /* -------------------------------------------------------------------------- */
    /*                          general factory settings                          */
    /* -------------------------------------------------------------------------- */
    it('should renounce oneself as admin', async function () {
      const DEFAULT_ADMIN_ROLE = await this.factory.DEFAULT_ADMIN_ROLE();
      await this.factory.renounceAdmin({ from: this.owner });
      expect(
        await this.factory.hasRole(DEFAULT_ADMIN_ROLE, this.owner)
      ).to.be.equal(false);
    });
    it('admin can remove role from non admin user', async function () {
      const MANAGE_CATEGORIES = await this.factory.MANAGE_CATEGORIES();
      await this.factory.addRole(this.addr2, MANAGE_CATEGORIES);
      await this.factory.removeRole(this.addr2, MANAGE_CATEGORIES);
      expect(
        await this.factory.hasRole(MANAGE_CATEGORIES, this.addr2)
      ).to.be.equal(false);
    });
    it('deployer owns contract', async function () {
      expect(await this.factory.root()).to.be.equal(this.owner);
    });
    it('should change factory settings', async function () {
      const campaignImplementation = await Campaign.new(),
        campaignRewardsImplementation = await CampaignRewards.new();

      await this.factory.setFactoryConfig(
        otherFactoryWallet,
        campaignImplementation.address,
        campaignRewardsImplementation.address
      );
      await Promise.all(
        Object.keys(this.factorySettings).map(async (setting) => {
          await this.factory.setCampaignTransactionConfig(
            setting,
            this.factorySettings[setting]
          );
        })
      );

      expect(await this.factory.factoryWallet()).to.be.equal(
        otherFactoryWallet
      );
      expect(await this.factory.campaignImplementation()).to.be.equal(
        campaignImplementation.address
      );
      expect(
        await this.factory.campaignTransactionConfig('defaultCommission')
      ).to.be.bignumber.equal(new BN('2'));
      expect(
        await this.factory.campaignTransactionConfig('minimumCampaignTarget')
      ).to.be.bignumber.equal(new BN('5000'));
      expect(
        await this.factory.campaignTransactionConfig('maximumCampaignTarget')
      ).to.be.bignumber.equal(new BN('10000000'));
      expect(
        await this.factory.campaignTransactionConfig('reviewThresholdMark')
      ).to.be.bignumber.equal(new BN('80'));
      expect(
        await this.factory.campaignTransactionConfig(
          'minimumRequestAmountAllowed'
        )
      ).to.be.bignumber.equal(new BN('1000'));
      expect(
        await this.factory.campaignTransactionConfig(
          'maximumRequestAmountAllowed'
        )
      ).to.be.bignumber.equal(new BN('10000'));
      expect(
        await this.factory.campaignTransactionConfig('minRequestDuration')
      ).to.be.bignumber.equal(new BN('86400'));
      expect(
        await this.factory.campaignTransactionConfig('maxRequestDuration')
      ).to.be.bignumber.equal(new BN('604800'));
      expect(
        await this.factory.campaignTransactionConfig('deadlineStrikesAllowed')
      ).to.be.bignumber.equal(new BN('3'));
      expect(
        await this.factory.campaignTransactionConfig('maxDeadlineExtension')
      ).to.be.bignumber.equal(new BN('604800'));
      expect(
        await this.factory.campaignTransactionConfig('minDeadlineExtension')
      ).to.be.bignumber.equal(new BN('86400'));
      expect(
        await this.factory.campaignTransactionConfig(
          'minimumContributionAllowed'
        )
      ).to.be.bignumber.equal(new BN('1'));
      expect(
        await this.factory.campaignTransactionConfig(
          'maximumContributionAllowed'
        )
      ).to.be.bignumber.equal(new BN('10000'));
    });
    it('should fail if non admin tries to change factory settings', async function () {
      const campaignImplementation = await Campaign.new(),
        campaignRewardsImplementation = await CampaignRewards.new();

      await expectRevert.unspecified(
        this.factory.setFactoryConfig(
          otherFactoryWallet,
          campaignImplementation.address,
          campaignRewardsImplementation.address,
          {
            from: this.addr1,
          }
        )
      );

      await expectRevert.unspecified(
        Promise.all(
          Object.keys(this.factorySettings).map(async (setting) => {
            await this.factory.setCampaignTransactionConfig(
              setting,
              this.factorySettings[setting],
              {
                from: this.addr1,
              }
            );
          })
        )
      );
    });
    it('should set default commission on request finalizations', async function () {
      await this.factory.setDefaultCommission(25, 10);
      expect(
        await this.factory.campaignTransactionConfig('defaultCommission')
      ).to.be.bignumber.equal(new BN('2500000000000000000000000000'));
    });
    it('should set commission on request finalizations per category', async function () {
      await this.factory.createCategory(true);
      await this.factory.createCategory(false);
      await this.factory.setCategoryCommission(0, 3, 1);
      await this.factory.setCategoryCommission(1, 25, 10);
      expect(await this.factory.categoryCommission(0)).to.be.bignumber.equal(
        new BN('3000000000000000000000000000')
      );
      expect(await this.factory.categoryCommission(1)).to.be.bignumber.equal(
        new BN('2500000000000000000000000000')
      );
    });
    it('set commission per category should fail if category does not exist', async function () {
      await expectRevert.unspecified(
        this.factory.setCategoryCommission(0, 4, 1)
      );
    });
    it('should fail if non admin tries to set commission per category', async function () {
      await this.factory.createCategory(true);
      await expectRevert.unspecified(
        this.factory.setCategoryCommission(0, 55, 10, { from: this.addr2 })
      );
    });

    /* -------------------------------------------------------------------------- */
    /*                         addFactoryTransactionConfig                        */
    /* -------------------------------------------------------------------------- */
    it('should add a transaction config key to factory settings', async function () {
      await this.factory.addFactoryTransactionConfig('testConfig', {
        from: this.owner,
      });
      expect(await this.factory.campaignTransactionConfigList(15)).to.be.equal(
        'testConfig'
      );
      expect(
        await this.factory.approvedCampaignTransactionConfig('testConfig')
      ).to.be.equal(true);
    });
    it('adding a factory transaction config should fail if it has already been added', async function () {
      await expectRevert.unspecified(
        this.factory.addFactoryTransactionConfig('reportThresholdMark', {
          from: this.owner,
        })
      );
    });

    /* -------------------------------------------------------------------------- */
    /*                                 removeToken                                */
    /* -------------------------------------------------------------------------- */
    it('should remove a token from list of accepted tokens', async function () {
      const receipt = await this.factory.removeToken(
        0,
        this.testToken.address,
        { from: this.owner }
      );

      expect(
        await this.factory.tokenInList(this.testToken.address)
      ).to.be.equal(false);
      expect(
        await this.factory.tokensApproved(this.testToken.address)
      ).to.be.equal(false);
      expectEvent(receipt, 'TokenRemoved', {
        tokenId: new BN('0'),
        token: this.testToken.address,
        sender: this.owner,
      });
    });

    /* -------------------------------------------------------------------------- */
    /*                                user resource                               */
    /* -------------------------------------------------------------------------- */
    userTests();

    /* -------------------------------------------------------------------------- */
    /*                              category resource                             */
    /* -------------------------------------------------------------------------- */
    categoryTests();

    /* -------------------------------------------------------------------------- */
    /*                              campaign resource                             */
    /* -------------------------------------------------------------------------- */
    campaignTests();

    /* -------------------------------------------------------------------------- */
    /*                          feature package resource                          */
    /* -------------------------------------------------------------------------- */
    featurePackageTests();
  }
);
