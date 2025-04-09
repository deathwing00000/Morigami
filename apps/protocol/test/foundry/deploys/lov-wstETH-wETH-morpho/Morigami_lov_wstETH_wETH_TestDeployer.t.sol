pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMorigamiSwapper} from "contracts/interfaces/common/swappers/IMorigamiSwapper.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {IAggregatorV3Interface} from "contracts/interfaces/external/chainlink/IAggregatorV3Interface.sol";
import {IMorigamiElevatedAccess} from "contracts/interfaces/common/access/IMorigamiElevatedAccess.sol";

import {Range} from "contracts/libraries/Range.sol";
import {MorigamiStableChainlinkOracle} from "contracts/common/oracle/MorigamiStableChainlinkOracle.sol";
import {MorigamiWstEthToEthOracle} from "contracts/common/oracle/MorigamiWstEthToEthOracle.sol";
import {MorigamiDexAggregatorSwapper} from "contracts/common/swappers/MorigamiDexAggregatorSwapper.sol";
import {MorigamiLovToken} from "contracts/investments/lovToken/MorigamiLovToken.sol";
import {MorigamiLovTokenMorphoManager} from "contracts/investments/lovToken/managers/MorigamiLovTokenMorphoManager.sol";
import {TokenPrices} from "contracts/common/TokenPrices.sol";
import {DummyLovTokenSwapper} from "contracts/test/investments/lovToken/DummyLovTokenSwapper.sol";
import {DummyOracle} from "contracts/test/common/DummyOracle.sol";
import {DummyMintableToken} from "contracts/test/common/DummyMintableToken.sol";

import {Morigami_lov_wstETH_wETH_TestConstants as Constants} from "test/foundry/deploys/lov-wstETH-wETH-morpho/Morigami_lov_wstETH_wETH_TestConstants.t.sol";
import {MorigamiMorphoBorrowAndLend} from "contracts/common/borrowAndLend/MorigamiMorphoBorrowAndLend.sol";

struct ExternalContracts {
    IERC20 wethToken;
    IERC20 wstEthToken;
    IERC20 stEthToken;
    IAggregatorV3Interface clStEthToEthOracle;
}

struct LovTokenContracts {
    MorigamiLovToken lovWstEth;
    MorigamiLovTokenMorphoManager lovWstEthManager;
    MorigamiStableChainlinkOracle stEthToEthOracle;
    MorigamiWstEthToEthOracle wstEthToEthOracle;
    IMorigamiSwapper swapper;
    MorigamiMorphoBorrowAndLend borrowLend;
}

/* solhint-disable max-states-count */
contract Morigami_lov_wstETH_wETH_TestDeployer {
    address public owner;
    address public feeCollector;
    address public overlord;

    /**
     * Either forked mainnet contracts, or mocks if non-forked
     */
    IERC20 public wethToken;
    IERC20 public wstEthToken;
    IERC20 public stEthToken;
    IAggregatorV3Interface public clStEthToEthOracle;

    /**
     * core contracts
     */
    TokenPrices public tokenPrices;

    /**
     * lovWstEth contracts
     */
    MorigamiLovToken public lovWstEth;
    MorigamiLovTokenMorphoManager public lovWstEthManager;
    MorigamiStableChainlinkOracle public stEthToEthOracle;
    MorigamiWstEthToEthOracle public wstEthToEthOracle;
    IMorigamiSwapper public swapper;
    MorigamiMorphoBorrowAndLend public borrowLend;

    Range.Data public userALRange;
    Range.Data public rebalanceALRange;

    function getContracts()
        public
        view
        returns (
            ExternalContracts memory externalContracts,
            LovTokenContracts memory lovTokenContracts
        )
    {
        externalContracts.wethToken = wethToken;
        externalContracts.wstEthToken = wstEthToken;
        externalContracts.stEthToken = stEthToken;
        externalContracts.clStEthToEthOracle = clStEthToEthOracle;

        lovTokenContracts.lovWstEth = lovWstEth;
        lovTokenContracts.lovWstEthManager = lovWstEthManager;
        lovTokenContracts.stEthToEthOracle = stEthToEthOracle;
        lovTokenContracts.wstEthToEthOracle = wstEthToEthOracle;
        lovTokenContracts.swapper = swapper;
        lovTokenContracts.borrowLend = borrowLend;
    }

    function deployNonForked(
        address _owner,
        address _feeCollector,
        address _overlord
    )
        external
        returns (
            ExternalContracts memory externalContracts,
            LovTokenContracts memory lovTokenContracts
        )
    {
        owner = _owner;
        feeCollector = _feeCollector;
        overlord = _overlord;

        wethToken = new DummyMintableToken(owner, "wETH", "wETH", 18);
        wstEthToken = new DummyMintableToken(owner, "wstETH", "wstETH", 18);
        stEthToken = new DummyMintableToken(owner, "stETH", "stETH", 18);

        swapper = new DummyLovTokenSwapper();

        clStEthToEthOracle = new DummyOracle(
            DummyOracle.Answer({
                roundId: 18446744073709552516,
                answer: 0.9987854203488546e18,
                startedAt: 1706225627,
                updatedAtLag: 1706225627,
                answeredInRound: 18446744073709552516
            }),
            18
        );

        _setuplovWstEth();
        return getContracts();
    }

    function deployForked(
        address _owner,
        address _feeCollector,
        address _overlord
    )
        external
        returns (
            ExternalContracts memory externalContracts,
            LovTokenContracts memory lovTokenContracts
        )
    {
        owner = _owner;
        feeCollector = _feeCollector;
        overlord = _overlord;

        {
            wethToken = IERC20(Constants.WETH_ADDRESS);
            wstEthToken = IERC20(Constants.WSTETH_ADDRESS);
            stEthToken = IERC20(Constants.STETH_ADDRESS);

            swapper = new MorigamiDexAggregatorSwapper(owner);
            MorigamiDexAggregatorSwapper(address(swapper)).whitelistRouter(
                Constants.ONE_INCH_ROUTER,
                true
            );

            // https://data.chain.link/feeds/ethereum/mainnet/steth-eth
            clStEthToEthOracle = IAggregatorV3Interface(
                Constants.STETH_ETH_ORACLE
            );
        }

        _setuplovWstEth();
        return getContracts();
    }

    function _setuplovWstEth() private {
        stEthToEthOracle = new MorigamiStableChainlinkOracle(
            owner,
            IMorigamiOracle.BaseOracleParams(
                "stETH/ETH",
                address(stEthToken),
                Constants.STETH_DECIMALS,
                address(wethToken),
                Constants.ETH_DECIMALS
            ),
            Constants.STETH_ETH_HISTORIC_STABLE_PRICE,
            address(clStEthToEthOracle),
            Constants.STETH_ETH_STALENESS_THRESHOLD,
            Range.Data(
                Constants.STETH_ETH_MIN_THRESHOLD,
                Constants.STETH_ETH_MAX_THRESHOLD
            ),
            true, // Chainlink does use roundId
            true // It does use lastUpdatedAt
        );
        wstEthToEthOracle = new MorigamiWstEthToEthOracle(
            IMorigamiOracle.BaseOracleParams(
                "wstETH/ETH",
                address(wstEthToken),
                Constants.WSTETH_DECIMALS,
                address(wethToken),
                Constants.ETH_DECIMALS
            ),
            address(stEthToken),
            address(stEthToEthOracle)
        );

        lovWstEth = new MorigamiLovToken(
            owner,
            "Morigami lovWstEth",
            "lovWstEth",
            Constants.PERFORMANCE_FEE_BPS,
            feeCollector,
            address(tokenPrices),
            type(uint256).max
        );
        borrowLend = new MorigamiMorphoBorrowAndLend(
            owner,
            address(wstEthToken),
            address(wethToken),
            Constants.MORPHO,
            Constants.MORPHO_MARKET_ORACLE,
            Constants.MORPHO_MARKET_IRM,
            Constants.MORPHO_MARKET_LLTV,
            Constants.MAX_SAFE_LLTV
        );
        lovWstEthManager = new MorigamiLovTokenMorphoManager(
            owner,
            address(wstEthToken),
            address(wethToken),
            address(stEthToken),
            address(lovWstEth),
            address(borrowLend)
        );

        _postDeploylovWstEth();
    }

    function _postDeploylovWstEth() private {
        userALRange = Range.Data(
            Constants.USER_AL_FLOOR,
            Constants.USER_AL_CEILING
        );
        rebalanceALRange = Range.Data(
            Constants.REBALANCE_AL_FLOOR,
            Constants.REBALANCE_AL_CEILING
        );

        borrowLend.setPositionOwner(address(lovWstEthManager));
        borrowLend.setSwapper(address(swapper));

        // Initial setup of config.
        lovWstEthManager.setOracles(
            address(wstEthToEthOracle),
            address(stEthToEthOracle)
        );
        lovWstEthManager.setUserALRange(userALRange.floor, userALRange.ceiling);
        lovWstEthManager.setRebalanceALRange(
            rebalanceALRange.floor,
            rebalanceALRange.ceiling
        );
        lovWstEthManager.setFeeConfig(
            Constants.MIN_DEPOSIT_FEE_BPS,
            Constants.MIN_EXIT_FEE_BPS,
            Constants.FEE_LEVERAGE_FACTOR
        );

        _setExplicitAccess(
            lovWstEthManager,
            overlord,
            MorigamiLovTokenMorphoManager.rebalanceUp.selector,
            MorigamiLovTokenMorphoManager.rebalanceDown.selector,
            true
        );

        lovWstEth.setManager(address(lovWstEthManager));

        // Only needed in lovWstEthManager tests so we can mint/burn
        // (ordinarily lovWstEth will do this via internal fns -- but we prank using foundry)
        lovWstEth.addMinter(address(lovWstEth));
    }

    function _setExplicitAccess(
        IMorigamiElevatedAccess theContract,
        address allowedCaller,
        bytes4 fnSelector,
        bool value
    ) private {
        IMorigamiElevatedAccess.ExplicitAccess[]
            memory access = new IMorigamiElevatedAccess.ExplicitAccess[](1);
        access[0] = IMorigamiElevatedAccess.ExplicitAccess(fnSelector, value);
        theContract.setExplicitAccess(allowedCaller, access);
    }

    function _setExplicitAccess(
        IMorigamiElevatedAccess theContract,
        address allowedCaller,
        bytes4 fnSelector1,
        bytes4 fnSelector2,
        bool value
    ) private {
        IMorigamiElevatedAccess.ExplicitAccess[]
            memory access = new IMorigamiElevatedAccess.ExplicitAccess[](2);
        access[0] = IMorigamiElevatedAccess.ExplicitAccess(fnSelector1, value);
        access[1] = IMorigamiElevatedAccess.ExplicitAccess(fnSelector2, value);
        theContract.setExplicitAccess(allowedCaller, access);
    }
}
