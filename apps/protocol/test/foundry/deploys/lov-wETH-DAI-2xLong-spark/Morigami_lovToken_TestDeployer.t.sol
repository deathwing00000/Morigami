pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMorigamiSwapper} from "contracts/interfaces/common/swappers/IMorigamiSwapper.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {IAggregatorV3Interface} from "contracts/interfaces/external/chainlink/IAggregatorV3Interface.sol";
import {IMorigamiElevatedAccess} from "contracts/interfaces/common/access/IMorigamiElevatedAccess.sol";

import {Range} from "contracts/libraries/Range.sol";
import {MorigamiVolatileChainlinkOracle} from "contracts/common/oracle/MorigamiVolatileChainlinkOracle.sol";
import {MorigamiDexAggregatorSwapper} from "contracts/common/swappers/MorigamiDexAggregatorSwapper.sol";
import {MorigamiLovToken} from "contracts/investments/lovToken/MorigamiLovToken.sol";
import {MorigamiLovTokenFlashAndBorrowManager} from "contracts/investments/lovToken/managers/MorigamiLovTokenFlashAndBorrowManager.sol";
import {TokenPrices} from "contracts/common/TokenPrices.sol";
import {DummyLovTokenSwapper} from "contracts/test/investments/lovToken/DummyLovTokenSwapper.sol";
import {DummyOracle} from "contracts/test/common/DummyOracle.sol";
import {DummyMintableToken} from "contracts/test/common/DummyMintableToken.sol";
import {MorigamiAaveV3FlashLoanProvider} from "contracts/common/flashLoan/MorigamiAaveV3FlashLoanProvider.sol";
import {Morigami_lovToken_TestConstants as Constants} from "test/foundry/deploys/lov-wETH-DAI-2xLong-spark/Morigami_lovToken_TestConstants.t.sol";
import {MorigamiAaveV3BorrowAndLend} from "contracts/common/borrowAndLend/MorigamiAaveV3BorrowAndLend.sol";

struct ExternalContracts {
    IERC20 reserveToken;
    IERC20 debtToken;
    IAggregatorV3Interface clReserveToDebtOracle;
}

struct LovTokenContracts {
    MorigamiLovToken lovToken;
    MorigamiLovTokenFlashAndBorrowManager lovTokenManager;
    MorigamiVolatileChainlinkOracle reserveToDebtOracle;
    IMorigamiSwapper swapper;
    MorigamiAaveV3FlashLoanProvider flashLoanProvider;
    MorigamiAaveV3BorrowAndLend borrowLend;
}

/* solhint-disable max-states-count */
contract Morigami_lovToken_TestDeployer {
    address public owner;
    address public feeCollector;
    address public overlord;

    /**
     * Either forked mainnet contracts, or mocks if non-forked
     */
    IERC20 public reserveToken;
    IERC20 public debtToken;
    IAggregatorV3Interface public clReserveToDebtOracle;

    /**
     * core contracts
     */
    TokenPrices public tokenPrices;

    /**
     * lovToken contracts
     */
    MorigamiLovToken public lovToken;
    MorigamiLovTokenFlashAndBorrowManager public lovTokenManager;
    MorigamiVolatileChainlinkOracle public reserveToDebtOracle;
    IMorigamiSwapper public swapper;
    MorigamiAaveV3FlashLoanProvider public flashLoanProvider;
    MorigamiAaveV3BorrowAndLend public borrowLend;

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
        externalContracts.reserveToken = reserveToken;
        externalContracts.debtToken = debtToken;
        externalContracts.clReserveToDebtOracle = clReserveToDebtOracle;

        lovTokenContracts.lovToken = lovToken;
        lovTokenContracts.lovTokenManager = lovTokenManager;
        lovTokenContracts.reserveToDebtOracle = reserveToDebtOracle;
        lovTokenContracts.swapper = swapper;
        lovTokenContracts.flashLoanProvider = flashLoanProvider;
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

        reserveToken = new DummyMintableToken(owner, "wETH", "wETH", 18);
        debtToken = new DummyMintableToken(owner, "DAI", "DAI", 18);

        swapper = new DummyLovTokenSwapper();

        clReserveToDebtOracle = new DummyOracle(
            DummyOracle.Answer({
                roundId: 110680464442257326562,
                answer: 2_885.56181640e8,
                startedAt: 1715572559,
                updatedAtLag: 1715572559,
                answeredInRound: 110680464442257326562
            }),
            18
        );

        _setuplovToken();
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
            reserveToken = IERC20(Constants.WETH_ADDRESS);
            debtToken = IERC20(Constants.DAI_ADDRESS);

            swapper = new MorigamiDexAggregatorSwapper(owner);
            MorigamiDexAggregatorSwapper(address(swapper)).whitelistRouter(
                Constants.ONE_INCH_ROUTER,
                true
            );

            clReserveToDebtOracle = IAggregatorV3Interface(
                Constants.ETH_USD_ORACLE
            );
        }

        _setuplovToken();
        return getContracts();
    }

    function _setuplovToken() private {
        reserveToDebtOracle = new MorigamiVolatileChainlinkOracle(
            IMorigamiOracle.BaseOracleParams(
                "wETH/DAI",
                address(reserveToken),
                Constants.WETH_DECIMALS,
                address(debtToken),
                Constants.DAI_DECIMALS
            ),
            address(clReserveToDebtOracle),
            Constants.ETH_USD_STALENESS_THRESHOLD,
            true, // Chainlink does use roundId
            true // Chainlink does use lastUpdatedAt
        );

        flashLoanProvider = new MorigamiAaveV3FlashLoanProvider(
            Constants.SPARK_POOL_ADDRESS_PROVIDER
        );

        lovToken = new MorigamiLovToken(
            owner,
            "Morigami lov-wETH-DAI-2x-long",
            "lov-wETH-DAI-2x-long",
            Constants.PERFORMANCE_FEE_BPS,
            feeCollector,
            address(tokenPrices),
            type(uint256).max
        );
        borrowLend = new MorigamiAaveV3BorrowAndLend(
            owner,
            address(reserveToken),
            address(debtToken),
            Constants.SPARK_POOL,
            Constants.SPARK_EMODE_NOT_ENABLED
        );
        lovTokenManager = new MorigamiLovTokenFlashAndBorrowManager(
            owner,
            address(reserveToken),
            address(debtToken),
            address(reserveToken),
            address(lovToken),
            address(flashLoanProvider),
            address(borrowLend)
        );

        _postDeploylovToken();
    }

    function _postDeploylovToken() private {
        userALRange = Range.Data(
            Constants.USER_AL_FLOOR,
            Constants.USER_AL_CEILING
        );
        rebalanceALRange = Range.Data(
            Constants.REBALANCE_AL_FLOOR,
            Constants.REBALANCE_AL_CEILING
        );

        borrowLend.setPositionOwner(address(lovTokenManager));

        // Initial setup of config.
        lovTokenManager.setOracles(
            address(reserveToDebtOracle),
            address(reserveToDebtOracle)
        );
        lovTokenManager.setUserALRange(userALRange.floor, userALRange.ceiling);
        lovTokenManager.setRebalanceALRange(
            rebalanceALRange.floor,
            rebalanceALRange.ceiling
        );
        lovTokenManager.setSwapper(address(swapper));
        lovTokenManager.setFeeConfig(
            Constants.MIN_DEPOSIT_FEE_BPS,
            Constants.MIN_EXIT_FEE_BPS,
            Constants.FEE_LEVERAGE_FACTOR
        );

        _setExplicitAccess(
            lovTokenManager,
            overlord,
            MorigamiLovTokenFlashAndBorrowManager.rebalanceUp.selector,
            MorigamiLovTokenFlashAndBorrowManager.rebalanceDown.selector,
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
