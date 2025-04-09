pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMorigamiSwapper} from "contracts/interfaces/common/swappers/IMorigamiSwapper.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {IAggregatorV3Interface} from "contracts/interfaces/external/chainlink/IAggregatorV3Interface.sol";
import {IMorigamiElevatedAccess} from "contracts/interfaces/common/access/IMorigamiElevatedAccess.sol";
import {IRenzoRestakeManager} from "contracts/interfaces/external/renzo/IRenzoRestakeManager.sol";

import {Range} from "contracts/libraries/Range.sol";
import {MorigamiRenzoEthToEthOracle} from "contracts/common/oracle/MorigamiRenzoEthToEthOracle.sol";
import {MorigamiDexAggregatorSwapper} from "contracts/common/swappers/MorigamiDexAggregatorSwapper.sol";
import {MorigamiLovToken} from "contracts/investments/lovToken/MorigamiLovToken.sol";
import {MorigamiLovTokenMorphoManager} from "contracts/investments/lovToken/managers/MorigamiLovTokenMorphoManager.sol";
import {TokenPrices} from "contracts/common/TokenPrices.sol";
import {DummyLovTokenSwapper} from "contracts/test/investments/lovToken/DummyLovTokenSwapper.sol";
import {DummyOracle} from "contracts/test/common/DummyOracle.sol";
import {DummyMintableToken} from "contracts/test/common/DummyMintableToken.sol";

import {Morigami_lov_ezETH_wETH_TestConstants as Constants} from "test/foundry/deploys/lov-ezETH-wETH/Morigami_lov_ezETH_wETH_TestConstants.t.sol";
import {MorigamiMorphoBorrowAndLend} from "contracts/common/borrowAndLend/MorigamiMorphoBorrowAndLend.sol";

struct ExternalContracts {
    IERC20 ezEthToken;
    IERC20 wEthToken;
    IAggregatorV3Interface redstoneEzEthToEthOracle;
    IRenzoRestakeManager renzoRestakeManager;
}

struct LovTokenContracts {
    MorigamiLovToken lovToken;
    MorigamiLovTokenMorphoManager lovTokenManager;
    MorigamiRenzoEthToEthOracle ezEthToEthOracle;
    IMorigamiSwapper swapper;
    MorigamiMorphoBorrowAndLend borrowLend;
}

/* solhint-disable max-states-count */
contract Morigami_lov_ezETH_wETH_TestDeployer {
    address public owner;
    address public feeCollector;
    address public overlord;

    /**
     * Either forked mainnet contracts, or mocks if non-forked
     */
    IERC20 public wEthToken;
    IERC20 public ezEthToken;
    IAggregatorV3Interface public redstoneEzEthToEthOracle;
    IRenzoRestakeManager public renzoRestakeManager;

    /**
     * core contracts
     */
    TokenPrices public tokenPrices;

    /**
     * LovToken contracts
     */
    MorigamiLovToken public lovToken;
    MorigamiLovTokenMorphoManager public lovTokenManager;
    MorigamiRenzoEthToEthOracle public ezEthToEthOracle;
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
        externalContracts.wEthToken = wEthToken;
        externalContracts.ezEthToken = ezEthToken;
        externalContracts.redstoneEzEthToEthOracle = redstoneEzEthToEthOracle;
        externalContracts.renzoRestakeManager = renzoRestakeManager;

        lovTokenContracts.lovToken = lovToken;
        lovTokenContracts.lovTokenManager = lovTokenManager;
        lovTokenContracts.ezEthToEthOracle = ezEthToEthOracle;
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

        wEthToken = new DummyMintableToken(owner, "wEth", "wEth", 18);
        ezEthToken = new DummyMintableToken(owner, "ezEth", "ezEth", 18);

        swapper = new DummyLovTokenSwapper();

        redstoneEzEthToEthOracle = new DummyOracle(
            DummyOracle.Answer({
                roundId: 132,
                answer: 1.00795447e8,
                startedAt: 1713394343,
                updatedAtLag: 1713394343,
                answeredInRound: 132
            }),
            8
        );

        // @todo Need a dummy contract
        // renzoRestakeManager = IRenzoRestakeManager(Constants.RENZO_RESTAKE_MANAGER);

        _setupLovToken();
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
            wEthToken = IERC20(Constants.WETH_ADDRESS);
            ezEthToken = IERC20(Constants.EZETH_ADDRESS);

            swapper = new MorigamiDexAggregatorSwapper(owner);
            MorigamiDexAggregatorSwapper(address(swapper)).whitelistRouter(
                Constants.ONE_INCH_ROUTER,
                true
            );

            // https://docs.redstone.finance/docs/smart-contract-devs/price-feeds#available-on-chain-classic-model
            redstoneEzEthToEthOracle = IAggregatorV3Interface(
                Constants.REDSTONE_EZETH_ETH_ORACLE
            );

            renzoRestakeManager = IRenzoRestakeManager(
                Constants.RENZO_RESTAKE_MANAGER
            );
        }

        _setupLovToken();
        return getContracts();
    }

    function _setupLovToken() private {
        ezEthToEthOracle = new MorigamiRenzoEthToEthOracle(
            owner,
            IMorigamiOracle.BaseOracleParams(
                "ezETH/wETH",
                address(ezEthToken),
                Constants.EZETH_DECIMALS,
                Constants.WETH_ADDRESS,
                Constants.WETH_DECIMALS
            ),
            address(redstoneEzEthToEthOracle),
            Constants.EZETH_ETH_STALENESS_THRESHOLD,
            Constants.EZETH_ETH_MAX_REL_DIFF_THRESHOLD_BPS,
            address(renzoRestakeManager)
        );

        lovToken = new MorigamiLovToken(
            owner,
            "Morigami lov-ezETH-a",
            "lov-ezETH-a",
            Constants.PERFORMANCE_FEE_BPS,
            feeCollector,
            address(tokenPrices),
            type(uint256).max
        );
        borrowLend = new MorigamiMorphoBorrowAndLend(
            owner,
            address(ezEthToken),
            address(wEthToken),
            Constants.MORPHO,
            Constants.MORPHO_MARKET_ORACLE,
            Constants.MORPHO_MARKET_IRM,
            Constants.MORPHO_MARKET_LLTV,
            Constants.MAX_SAFE_LLTV
        );
        lovTokenManager = new MorigamiLovTokenMorphoManager(
            owner,
            address(ezEthToken),
            address(wEthToken),
            address(ezEthToken),
            address(lovToken),
            address(borrowLend)
        );

        _postDeployLovToken();
    }

    function _postDeployLovToken() private {
        userALRange = Range.Data(
            Constants.USER_AL_FLOOR,
            Constants.USER_AL_CEILING
        );
        rebalanceALRange = Range.Data(
            Constants.REBALANCE_AL_FLOOR,
            Constants.REBALANCE_AL_CEILING
        );

        borrowLend.setPositionOwner(address(lovTokenManager));
        borrowLend.setSwapper(address(swapper));

        // Initial setup of config.
        lovTokenManager.setOracles(
            address(ezEthToEthOracle),
            address(ezEthToEthOracle)
        );
        lovTokenManager.setUserALRange(userALRange.floor, userALRange.ceiling);
        lovTokenManager.setRebalanceALRange(
            rebalanceALRange.floor,
            rebalanceALRange.ceiling
        );
        lovTokenManager.setFeeConfig(
            Constants.MIN_DEPOSIT_FEE_BPS,
            Constants.MIN_EXIT_FEE_BPS,
            Constants.FEE_LEVERAGE_FACTOR
        );

        _setExplicitAccess(
            lovTokenManager,
            overlord,
            MorigamiLovTokenMorphoManager.rebalanceUp.selector,
            MorigamiLovTokenMorphoManager.rebalanceDown.selector,
            true
        );

        lovToken.setManager(address(lovTokenManager));

        // Only needed in lovTokenManager tests so we can mint/burn
        // (ordinarily lovToken will do this via internal fns -- but we prank using foundry)
        lovToken.addMinter(address(lovToken));
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
