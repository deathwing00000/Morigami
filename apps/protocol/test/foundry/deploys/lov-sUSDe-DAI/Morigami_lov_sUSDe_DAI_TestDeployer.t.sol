pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMorigamiSwapper} from "contracts/interfaces/common/swappers/IMorigamiSwapper.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {IAggregatorV3Interface} from "contracts/interfaces/external/chainlink/IAggregatorV3Interface.sol";
import {IMorigamiElevatedAccess} from "contracts/interfaces/common/access/IMorigamiElevatedAccess.sol";

import {Range} from "contracts/libraries/Range.sol";
import {MorigamiStableChainlinkOracle} from "contracts/common/oracle/MorigamiStableChainlinkOracle.sol";
import {MorigamiErc4626Oracle} from "contracts/common/oracle/MorigamiErc4626Oracle.sol";
import {MorigamiErc4626AndDexAggregatorSwapper} from "contracts/common/swappers/MorigamiErc4626AndDexAggregatorSwapper.sol";
import {MorigamiLovToken} from "contracts/investments/lovToken/MorigamiLovToken.sol";
import {MorigamiLovTokenMorphoManager} from "contracts/investments/lovToken/managers/MorigamiLovTokenMorphoManager.sol";
import {TokenPrices} from "contracts/common/TokenPrices.sol";
import {DummyLovTokenSwapper} from "contracts/test/investments/lovToken/DummyLovTokenSwapper.sol";
import {DummyOracle} from "contracts/test/common/DummyOracle.sol";
import {DummyMintableToken} from "contracts/test/common/DummyMintableToken.sol";

import {Morigami_lov_sUSDe_DAI_TestConstants as Constants} from "test/foundry/deploys/lov-sUSDe-DAI/Morigami_lov_sUSDe_DAI_TestConstants.t.sol";
import {MorigamiMorphoBorrowAndLend} from "contracts/common/borrowAndLend/MorigamiMorphoBorrowAndLend.sol";

struct ExternalContracts {
    IERC20 daiToken;
    IERC20 sUsdeToken;
    IERC20 usdeToken;
    IAggregatorV3Interface redstoneUsdeToUsdOracle;
}

struct LovTokenContracts {
    MorigamiLovToken lovToken;
    MorigamiLovTokenMorphoManager lovTokenManager;
    MorigamiStableChainlinkOracle usdeToDaiOracle;
    MorigamiErc4626Oracle sUsdeToDaiOracle;
    IMorigamiSwapper swapper;
    MorigamiMorphoBorrowAndLend borrowLend;
}

/* solhint-disable max-states-count */
contract Morigami_lov_sUSDe_DAI_TestDeployer {
    address public owner;
    address public feeCollector;
    address public overlord;

    /**
     * Either forked mainnet contracts, or mocks if non-forked
     */
    IERC20 public daiToken;
    IERC20 public sUsdeToken;
    IERC20 public usdeToken;
    IAggregatorV3Interface public redstoneUsdeToUsdOracle;

    /**
     * core contracts
     */
    TokenPrices public tokenPrices;

    /**
     * LovToken contracts
     */
    MorigamiLovToken public lovToken;
    MorigamiLovTokenMorphoManager public lovTokenManager;
    MorigamiStableChainlinkOracle public usdeToDaiOracle;
    MorigamiErc4626Oracle public sUsdeToDaiOracle;
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
        externalContracts.daiToken = daiToken;
        externalContracts.sUsdeToken = sUsdeToken;
        externalContracts.usdeToken = usdeToken;
        externalContracts.redstoneUsdeToUsdOracle = redstoneUsdeToUsdOracle;

        lovTokenContracts.lovToken = lovToken;
        lovTokenContracts.lovTokenManager = lovTokenManager;
        lovTokenContracts.usdeToDaiOracle = usdeToDaiOracle;
        lovTokenContracts.sUsdeToDaiOracle = sUsdeToDaiOracle;
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

        daiToken = new DummyMintableToken(owner, "DAI", "DAI", 18);
        sUsdeToken = new DummyMintableToken(owner, "sUSDe", "sUSDe", 18);
        usdeToken = new DummyMintableToken(owner, "USDe", "USDe", 18);

        swapper = new DummyLovTokenSwapper();

        redstoneUsdeToUsdOracle = new DummyOracle(
            DummyOracle.Answer({
                roundId: 1,
                answer: 1.00135613e8,
                startedAt: 1711046891,
                updatedAtLag: 1711046891,
                answeredInRound: 1
            }),
            8
        );

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
            daiToken = IERC20(Constants.DAI_ADDRESS);
            sUsdeToken = IERC20(Constants.SUSDE_ADDRESS);
            usdeToken = IERC20(Constants.USDE_ADDRESS);

            swapper = new MorigamiErc4626AndDexAggregatorSwapper(
                owner,
                Constants.SUSDE_ADDRESS
            );
            MorigamiErc4626AndDexAggregatorSwapper(address(swapper))
                .whitelistRouter(Constants.ONE_INCH_ROUTER, true);

            // https://docs.redstone.finance/docs/smart-contract-devs/price-feeds#available-on-chain-classic-model
            redstoneUsdeToUsdOracle = IAggregatorV3Interface(
                Constants.USDE_USD_ORACLE
            );
        }

        _setupLovToken();
        return getContracts();
    }

    function _setupLovToken() private {
        usdeToDaiOracle = new MorigamiStableChainlinkOracle(
            owner,
            IMorigamiOracle.BaseOracleParams(
                "USDe/DAI",
                address(usdeToken),
                Constants.USDE_DECIMALS,
                Constants.DAI_ADDRESS,
                Constants.DAI_DECIMALS
            ),
            Constants.USDE_USD_HISTORIC_STABLE_PRICE,
            address(redstoneUsdeToUsdOracle),
            Constants.USDE_USD_STALENESS_THRESHOLD,
            Range.Data(
                Constants.USDE_USD_MIN_THRESHOLD,
                Constants.USDE_USD_MAX_THRESHOLD
            ),
            false, // Redstone does not use roundId
            true // It does use lastUpdatedAt
        );
        sUsdeToDaiOracle = new MorigamiErc4626Oracle(
            IMorigamiOracle.BaseOracleParams(
                "sUSDe/DAI",
                address(sUsdeToken),
                Constants.SUSDE_DECIMALS,
                Constants.DAI_ADDRESS,
                Constants.DAI_DECIMALS
            ),
            address(usdeToDaiOracle)
        );

        lovToken = new MorigamiLovToken(
            owner,
            "Morigami lov-sUSDe",
            "lov-sUSDe",
            Constants.PERFORMANCE_FEE_BPS,
            feeCollector,
            address(tokenPrices),
            type(uint256).max
        );
        borrowLend = new MorigamiMorphoBorrowAndLend(
            owner,
            address(sUsdeToken),
            address(daiToken),
            Constants.MORPHO,
            Constants.MORPHO_MARKET_ORACLE,
            Constants.MORPHO_MARKET_IRM,
            Constants.MORPHO_MARKET_LLTV,
            Constants.MAX_SAFE_LLTV
        );
        lovTokenManager = new MorigamiLovTokenMorphoManager(
            owner,
            address(sUsdeToken),
            address(daiToken),
            address(usdeToken),
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
            address(sUsdeToDaiOracle),
            address(usdeToDaiOracle)
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
