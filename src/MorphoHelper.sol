// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// Morpho Blue interfaces
import {Id, IMorpho, MarketParams, Market, Position} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {IIrm} from "../lib/morpho-blue/src/interfaces/IIrm.sol";

// Morpho Blue libraries
import {MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {MorphoBalancesLib} from "../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoStorageLib} from "../lib/morpho-blue/src/libraries/periphery/MorphoStorageLib.sol";
import {MorphoLib} from "../lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import "../lib/morpho-blue/src/libraries/ConstantsLib.sol";

// OpenZeppelin upgradeability
import {Initializable} from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

// Project interfaces
import {IMetaMorpho, MarketAllocation} from "./interfaces/IMetaMorpho.sol";
import {IPublicAllocator, FlowCapsConfig} from "./interfaces/IPublicAllocator.sol";
import {IMorphoReader, MarketDataExt, PositionExt} from "./interfaces/IMorphoReader.sol";

/**
 * @title MorphoHelper
 * @author Morpho Labs
 * @notice Helper contract facilitating interactions with Morpho Blue and MetaMorpho vaults.
 * @dev Provides restricted functions for operators/admins to manage vaults and public allocator settings,
 *      as well as view functions to read data from Morpho Blue.
 *      Upgradeable using the UUPS pattern.
 */
contract MorphoHelper is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    using MathLib for uint256;
    using MorphoBalancesLib for IMorpho;
    using MorphoStorageLib for IMorpho;
    using MorphoLib for IMorpho;
    using MarketParamsLib for MarketParams;

    // =========================================================================
    //                           Custom Structs
    // =========================================================================

    /// @notice Represents a withdrawal/deposit instruction for a specific market.
    struct Withdrawal {
        MarketParams market; /// The market parameters.
        int256 amount;       /// The amount of assets to withdraw (positive) or deposit (negative).
    }

    /// @notice Represents a withdrawal/deposit instruction for a market ID.
    struct WithdrawalById {
        Id marketId; /// The market ID.
        int256 amount; /// The amount of assets to withdraw (positive) or deposit (negative).
    }

    // =========================================================================
    //                           Constants & State
    // =========================================================================

    /// @notice Role for operators allowed to perform restricted actions.
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    /// @notice Role for accounts allowed to upgrade the contract.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice The Morpho Blue core contract instance.
    IMorpho public morpho;
    /// @notice The Public Allocator contract instance.
    IPublicAllocator public public_allocator;


    // =========================================================================
    //                           Constructor & Initializer
    // =========================================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        if (block.chainid == 1) { // Ethereum Mainnet
            morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
            public_allocator = IPublicAllocator(0xfd32fA2ca22c76dD6E550706Ad913FC6CE91c75D);
        } else if (block.chainid == 8453) { // Base Mainnet
            morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
            public_allocator = IPublicAllocator(0xA090dD1a701408Df1d4d0B85b716c87565f90467);
        }
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract, setting up access control and UUPS upgradeability.
     * @param initialAdmin The address to grant initial admin, upgrader, and operator roles.
     */
    function initialize(address initialAdmin) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(UPGRADER_ROLE, initialAdmin);
        _grantRole(OPERATOR_ROLE, initialAdmin);
    }

    // =========================================================================
    //                              Modifiers
    // =========================================================================

    /**
     * @notice Restricts execution to OPERATOR_ROLE or DEFAULT_ADMIN_ROLE.
     */
    modifier onlyOperator() {
        address sender = _msgSender();
        require(hasRole(OPERATOR_ROLE, sender) || hasRole(DEFAULT_ADMIN_ROLE, sender), "MorphoHelper: Caller is not an operator");
        _;
    }

    modifier onlyUpgrader() {
        address sender = _msgSender();
        require(hasRole(UPGRADER_ROLE, sender) || hasRole(DEFAULT_ADMIN_ROLE, sender), "MorphoHelper: Caller is not an upgrader");
        _;
    }

    modifier onlyAdmin() {
        address sender = _msgSender();
        require(hasRole(DEFAULT_ADMIN_ROLE, sender), "MorphoHelper: Caller is not an admin");
        _;
    }

    // =========================================================================
    //                        Admin & Configuration
    // =========================================================================

    /**
     * @notice Authorizes an upgrade to a new implementation.
     * @dev Only callable by UPGRADER_ROLE. Part of OpenZeppelin UUPS pattern.
     * @param newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    /**
     * @notice Updates the Morpho Blue core contract address.
     * @dev Only callable by UPGRADER_ROLE.
     * @param morpho_ The new Morpho Blue contract address.
     */
    function setMorpho(address morpho_) external onlyUpgrader {
        morpho = IMorpho(morpho_);
    }

    /**
     * @notice Updates the Public Allocator contract address.
     * @dev Only callable by UPGRADER_ROLE.
     * @param publicAllocator_ The new Public Allocator contract address.
     */
    function setPublicAllocator(address publicAllocator_) external onlyUpgrader {
        public_allocator = IPublicAllocator(publicAllocator_);
    }

    /**
     * @notice Grants or revokes the OPERATOR_ROLE.
     * @dev Only callable by UPGRADER_ROLE.
     * @param operator The address to grant or revoke the role from.
     * @param grant True to grant the role, false to revoke it.
     */
    function setOperatorRole(address operator, bool grant) external onlyUpgrader {
        if (grant) {
            _grantRole(OPERATOR_ROLE, operator);
        } else {
            _revokeRole(OPERATOR_ROLE, operator);
        }
    }

    // =========================================================================
    //                          Vault Operations
    // =========================================================================

    /**
     * @notice Reallocates assets for a MetaMorpho vault.
     * @dev Wrapper for `IMetaMorpho.reallocate`.
     * @param vault The MetaMorpho vault instance.
     * @param allocations Target assets for each market.
     */
    function reallocate(IMetaMorpho vault, MarketAllocation[] calldata allocations) external onlyOperator {
        vault.reallocate(allocations);
    }

    /**
     * @notice Sets the supply queue for a MetaMorpho vault.
     * @dev Wrapper for `IMetaMorpho.setSupplyQueue`.
     * @param vault The MetaMorpho vault instance.
     * @param newSupplyQueue Market IDs for the new supply queue order.
     */
    function vault_setSupplyQueue(IMetaMorpho vault, Id[] calldata newSupplyQueue) external onlyOperator {
        vault.setSupplyQueue(newSupplyQueue);
    }

    /**
     * @notice Updates the withdraw queue for a MetaMorpho vault.
     * @dev Wrapper for `IMetaMorpho.updateWithdrawQueue`.
     * @param vault The MetaMorpho vault instance.
     * @param indexes Indexes to update in the withdraw queue.
     */
    function vault_updateWithdrawQueue(IMetaMorpho vault, uint256[] calldata indexes) external onlyOperator {
        vault.updateWithdrawQueue(indexes);
    }

    /**
     * @notice Gets the supplied assets of a vault in a specific market.
     * @param vault The MetaMorpho vault instance.
     * @param market The market parameters.
     * @return The amount of assets supplied by the vault.
     */
    function vaultPosition(IMetaMorpho vault, MarketParams memory market) public view returns (uint256) {
        return morpho.expectedSupplyAssets(market, address(vault));
    }

    /**
     * @notice Moves assets between two markets for a vault.
     * @dev Calls `reallocate` setting the destination allocation to `type(uint256).max`.
     * @param vault The MetaMorpho vault instance.
     * @param sourceMarket Market to move assets from.
     * @param destinationMarket Market to move assets to.
     * @param amount Net amount to move. Positive withdraws from source, negative deposits to source.
     */
    function move(
        IMetaMorpho vault,
        MarketParams memory sourceMarket,
        MarketParams memory destinationMarket,
        int256 amount
    ) public onlyOperator {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        uint256 sourcePosition = vaultPosition(vault, sourceMarket);

        uint256 newSourcePosition;
        if (amount < 0) { // Deposit to source
            newSourcePosition = sourcePosition + uint256(-amount);
        } else { // Withdraw from source
            newSourcePosition = uint256(amount) <= sourcePosition ? sourcePosition - uint256(amount) : 0;
        }

        allocations[0] = MarketAllocation({marketParams: sourceMarket, assets: newSourcePosition});
        allocations[1] = MarketAllocation({marketParams: destinationMarket, assets: type(uint256).max});

        vault.reallocate(allocations);
    }

    /**
     * @notice Moves assets between two markets (by ID) for a vault.
     * @dev Converts IDs to `MarketParams` and calls the internal `move` logic.
     * @param vault The MetaMorpho vault instance.
     * @param sourceMarketId ID of the market to move assets from.
     * @param destinationMarketId ID of the market to move assets to.
     * @param amount Net amount to move. Positive withdraws from source, negative deposits to source.
     */
    function move(IMetaMorpho vault, Id sourceMarketId, Id destinationMarketId, int256 amount) external onlyOperator {
        move(vault, morpho.idToMarketParams(sourceMarketId), morpho.idToMarketParams(destinationMarketId), amount);
    }

    /**
     * @notice Moves assets from multiple source markets to a single destination market.
     * @dev Aggregates withdrawals/deposits into one `reallocate` call.
     * @param vault The MetaMorpho vault instance.
     * @param withdrawals Amounts to move from each source market.
     * @param destinationMarket Market to move assets to.
     */
    function move(
        IMetaMorpho vault,
        Withdrawal[] calldata withdrawals,
        MarketParams calldata destinationMarket
    ) external onlyOperator {
        _moveInternal(vault, withdrawals, destinationMarket);
    }

    /**
     * @notice Moves assets from multiple source markets (by ID) to a single destination market (by ID).
     * @dev Converts IDs to `MarketParams` and calls the internal move logic.
     * @param vault The MetaMorpho vault instance.
     * @param withdrawals Amounts to move from each source market (by ID).
     * @param destinationMarketId ID of the market to move assets to.
     */
    function move(IMetaMorpho vault, WithdrawalById[] calldata withdrawals, Id destinationMarketId) external onlyOperator {
        Withdrawal[] memory withdrawals_ = new Withdrawal[](withdrawals.length);
        for (uint256 i = 0; i < withdrawals.length; i++) {
            withdrawals_[i] = Withdrawal({market: morpho.idToMarketParams(withdrawals[i].marketId), amount: withdrawals[i].amount});
        }
        _moveInternal(vault, withdrawals_, morpho.idToMarketParams(destinationMarketId));
    }

    /**
     * @notice Internal logic for moving assets from multiple sources to one destination.
     */
    function _moveInternal(IMetaMorpho vault, Withdrawal[] memory withdrawals, MarketParams memory destinationMarket) internal {
        MarketAllocation[] memory allocations = new MarketAllocation[](withdrawals.length + 1);
        for (uint256 i = 0; i < withdrawals.length; i++) {
            uint256 sourcePosition = vaultPosition(vault, withdrawals[i].market);

            uint256 newSourcePosition;
            if (withdrawals[i].amount < 0) { // Deposit to source
                newSourcePosition = sourcePosition + uint256(-withdrawals[i].amount);
            } else { // Withdraw from source
                newSourcePosition = uint256(withdrawals[i].amount) <= sourcePosition
                    ? sourcePosition - uint256(withdrawals[i].amount)
                    : 0;
            }

            allocations[i] = MarketAllocation({marketParams: withdrawals[i].market, assets: newSourcePosition});
        }
        allocations[withdrawals.length] = MarketAllocation({marketParams: destinationMarket, assets: type(uint256).max});

        vault.reallocate(allocations);
    }


    // =========================================================================
    //                      Public Allocator Operations
    // =========================================================================

    /**
     * @notice Sets flow caps for a vault via the Public Allocator.
     * @dev Wrapper for `IPublicAllocator.setFlowCaps`.
     * @param vault Address used as identifier in Public Allocator.
     * @param flowCaps Flow caps definitions for each market.
     */
    function pa_setFlowCaps(IMetaMorpho vault, FlowCapsConfig[] calldata flowCaps) external onlyOperator {
        public_allocator.setFlowCaps(address(vault), flowCaps);
    }

    /**
     * @notice Sets the fee for a vault within the Public Allocator.
     * @dev Wrapper for `IPublicAllocator.setFee`.
     * @param vault Address used as identifier in Public Allocator.
     * @param newFee New fee basis points.
     */
    function pa_setFee(address vault, uint256 newFee) external onlyOperator {
        public_allocator.setFee(vault, newFee);
    }

    /**
     * @notice Transfers accumulated fees for a vault from the Public Allocator.
     * @dev Wrapper for `IPublicAllocator.transferFee`.
     * @param vault Address used as identifier in Public Allocator.
     * @param feeRecipient Address to receive the fees.
     */
    function pa_transferFee(address vault, address payable feeRecipient) external onlyOperator {
        public_allocator.transferFee(vault, feeRecipient);
    }

    /**
     * @notice Sets the admin for a vault within the Public Allocator.
     * @dev Wrapper for `IPublicAllocator.setAdmin`. Requires DEFAULT_ADMIN_ROLE.
     * @param vault Address used as identifier in Public Allocator.
     * @param newAdmin New admin address for the vault in the Public Allocator.
     */
    function pa_setAdmin(address vault, address newAdmin) external onlyUpgrader {
        public_allocator.setAdmin(vault, newAdmin);
    }

    // =========================================================================
    //                           Morpho Reader Views
    // =========================================================================

    /**
     * @notice Converts Morpho Blue market parameters to its unique identifier.
     * @param marketParams The market parameters.
     * @return id The unique identifier for the market.
     */
    function marketParamsToId(MarketParams memory marketParams) public pure returns (Id) {
        return marketParams.id();
    }

    /**
     * @notice Retrieves extended data for a Morpho Blue market.
     * @param id The unique identifier of the market.
     * @return marketData A `MarketDataExt` struct with detailed market information.
     */
    function getMarketData(Id id) public view returns (MarketDataExt memory marketData) {
        Market memory market = morpho.market(id);
        MarketParams memory marketParams = morpho.idToMarketParams(id);

        (marketData.totalSupplyAssets, marketData.totalSupplyShares, marketData.totalBorrowAssets, marketData.totalBorrowShares) = morpho
            .expectedMarketBalances(marketParams);

        marketData.fee = morpho.fee(id);

        // Get the borrow rate
        marketData.borrowRate = 0;
        if (address(marketParams.irm) != address(0)) {
            marketData.borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market).wTaylorCompounded(365 days);
        }

        // Get the supply rate
        marketData.utilization = marketData.totalSupplyAssets == 0 ? 0 : marketData.totalBorrowAssets.wDivUp(marketData.totalSupplyAssets);

        marketData.supplyRate = marketData.borrowRate.wMulDown(1 ether - market.fee).wMulDown(marketData.utilization);
    }

    /**
     * @notice Retrieves extended position data for a user in a Morpho Blue market.
     * @param id The unique identifier of the market.
     * @param user The address of the user.
     * @return position A `PositionExt` struct with detailed position information.
     */
    function getPosition(Id id, address user) public view returns (PositionExt memory position) {
        MarketParams memory marketParams = morpho.idToMarketParams(id);

        Position memory p = morpho.position(id, user);

        uint256 collateralPrice = (address(marketParams.oracle) == address(0)) ? 0 : IOracle(marketParams.oracle).price();

        position.collateral = p.collateral;
        position.collateralValue = position.collateral.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE);

        position.borrowedAssets = morpho.expectedBorrowAssets(marketParams, user);
        position.borrowedShares = p.borrowShares;
        position.suppliedAssets = morpho.expectedSupplyAssets(marketParams, user);
        position.suppliedShares = p.supplyShares;

        position.ltv = (position.collateralValue == 0) ? 0 : position.borrowedAssets.wDivUp(position.collateralValue);

        uint256 maxBorrow = position.collateral.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(marketParams.lltv);

        position.healthFactor = (position.borrowedAssets == 0) ? type(uint256).max : maxBorrow.wDivDown(position.borrowedAssets);
    }
}