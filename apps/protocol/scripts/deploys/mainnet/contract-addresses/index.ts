import { network } from "hardhat";
import {
  TokenPrices, TokenPrices__factory,
  MorigamiVolatileChainlinkOracle, MorigamiVolatileChainlinkOracle__factory,
  MorigamiStableChainlinkOracle, MorigamiStableChainlinkOracle__factory,
  MorigamiLovToken, MorigamiLovToken__factory,
  MorigamiLovTokenMorphoManager, MorigamiLovTokenMorphoManager__factory,
  MorigamiMorphoBorrowAndLend, MorigamiMorphoBorrowAndLend__factory,
  MorigamiErc4626Oracle, MorigamiErc4626Oracle__factory,
  AdaptiveCurveIrm, AdaptiveCurveIrm__factory,
  MorphoChainlinkOracleV2, MorphoChainlinkOracleV2__factory,
  MorigamiErc4626AndDexAggregatorSwapper, MorigamiErc4626AndDexAggregatorSwapper__factory,
  IMorpho, IMorpho__factory,
  AggregatorV3Interface, AggregatorV3Interface__factory,
  MorigamiDexAggregatorSwapper,
  MorigamiDexAggregatorSwapper__factory,
  MorigamiEtherFiEthToEthOracle,
  MorigamiRenzoEthToEthOracle,
  MorigamiEtherFiEthToEthOracle__factory,
  MorigamiRenzoEthToEthOracle__factory,
  IRenzoRestakeManager,
  IEtherFiLiquidityPool,
  IEtherFiLiquidityPool__factory,
  IRenzoRestakeManager__factory,
  MorigamiWstEthToEthOracle,
  MorigamiWstEthToEthOracle__factory,
  MorigamiAaveV3FlashLoanProvider,
  MorigamiAaveV3BorrowAndLend,
  MorigamiLovTokenFlashAndBorrowManager,
  MorigamiAaveV3FlashLoanProvider__factory,
  MorigamiAaveV3BorrowAndLend__factory,
  MorigamiLovTokenFlashAndBorrowManager__factory,
  IPoolAddressesProvider, IPoolAddressesProvider__factory,
  MorigamiCrossRateOracle,
  MorigamiCrossRateOracle__factory,
  MorigamiPendlePtToAssetOracle,
  MorigamiPendlePtToAssetOracle__factory,
  IERC20Metadata,
  IERC20Metadata__factory,
  MorigamiFixedPriceOracle,
  MorigamiVolatileCurveEmaOracle,
  MorigamiVolatileCurveEmaOracle__factory,
  MorigamiFixedPriceOracle__factory,
  MorigamiCowSwapper,
  MorigamiCowSwapper__factory,
  MorigamiSuperSavingsUsdsManager, MorigamiSuperSavingsUsdsManager__factory,
  MorigamiSuperSavingsUsdsVault, MorigamiSuperSavingsUsdsVault__factory,
  MorigamiScaledOracle,
  MorigamiScaledOracle__factory,
  MorigamiLovTokenMorphoManagerMarketAL,
  MorigamiLovTokenMorphoManagerMarketAL__factory,
} from "../../../../typechain";
import { Signer } from "ethers";
import { ContractAddresses } from "./types";
import { CONTRACTS as MAINNET_CONTRACTS } from "./mainnet";
import { CONTRACTS as LOCALHOST_CONTRACTS } from "./localhost";
import { IERC4626 } from "../../../../typechain/@openzeppelin/contracts/interfaces";
import { IERC4626__factory } from "../../../../typechain/factories/@openzeppelin/contracts/interfaces";

// dirname is expected to be the path of the hardhat deploy script
// This will crudely search for the `scripts/${dir}/address-overrides.ts` module
// and apply the overrides to addrs
async function applyOverrides(addrs: ContractAddresses, dirname: string) {
  const dirs = dirname.split("/");
  let scriptDir = "";
  for (let i = dirs.length-1; i >= 0; i--) {
    if (dirs[i] == "mainnet" || dirs[i] == "scripts") {
      scriptDir = dirs[i+1];
      break;
    }
  }

  const module = await import(`../scripts/${scriptDir}/address-overrides`);
  return module.applyOverrides(addrs);
}

export function getDeployedContracts(): ContractAddresses {
  if (network.name === 'mainnet') {
    return MAINNET_CONTRACTS;
  } else if (network.name === 'localhost') {
    return LOCALHOST_CONTRACTS;
  }
  console.log(`No contracts configured for ${network.name}`);
  throw new Error(`No contracts configured for ${network.name}`);
}

export async function getDeployedContracts1(
  applyOverridesPath: string
): Promise<ContractAddresses> {
  if (network.name === 'mainnet') {
    return MAINNET_CONTRACTS;
  } else if (network.name === 'localhost') {
    return await applyOverrides(MAINNET_CONTRACTS, applyOverridesPath);
  }
  console.log(`No contracts configured for ${network.name}`);
  throw new Error(`No contracts configured for ${network.name}`);
}

interface IType {
  TOKEN: MorigamiLovToken;
};

interface IMorphoType extends IType {
  MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend;
  MANAGER: MorigamiLovTokenMorphoManager;
}

interface IMorphoMarketALType extends IType {
  MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend;
  MANAGER: MorigamiLovTokenMorphoManagerMarketAL;
}

interface ISparkType extends IType {
  SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend;
  MANAGER: MorigamiLovTokenFlashAndBorrowManager;
}

interface IZeroLendType extends IType {
  ZEROLEND_BORROW_LEND: MorigamiAaveV3BorrowAndLend;
  MANAGER: MorigamiLovTokenFlashAndBorrowManager;
}

export interface ContractInstances {
  CORE: {
    TOKEN_PRICES: {
      V1: TokenPrices;
      V2: TokenPrices;
      V3: TokenPrices;
    };
  };
  ORACLES: {
    USDE_DAI: MorigamiStableChainlinkOracle;
    SUSDE_DAI: MorigamiErc4626Oracle;
    WEETH_WETH: MorigamiEtherFiEthToEthOracle;
    EZETH_WETH: MorigamiRenzoEthToEthOracle;
    STETH_WETH: MorigamiStableChainlinkOracle;
    WSTETH_WETH: MorigamiWstEthToEthOracle;
    WOETH_WETH: MorigamiErc4626Oracle;
    WETH_DAI: MorigamiVolatileChainlinkOracle;
    WBTC_DAI: MorigamiVolatileChainlinkOracle;
    WETH_WBTC: MorigamiVolatileChainlinkOracle;
    DAI_USD: MorigamiStableChainlinkOracle;
    SDAI_DAI: MorigamiErc4626Oracle;
    WETH_SDAI: MorigamiCrossRateOracle;
    WBTC_SDAI: MorigamiCrossRateOracle;
    PT_SUSDE_OCT24_USDE: MorigamiPendlePtToAssetOracle;
    PT_SUSDE_OCT24_DAI: MorigamiCrossRateOracle;
    PT_SUSDE_MAR_2025_USDE: MorigamiPendlePtToAssetOracle;
    PT_SUSDE_MAR_2025_DAI: MorigamiCrossRateOracle;
    PT_SUSDE_MAR_2025_DISCOUNT_TO_MATURITY: MorigamiVolatileChainlinkOracle;
    PT_SUSDE_MAR_2025_DAI_WITH_DISCOUNT_TO_MATURITY: MorigamiScaledOracle;
    MKR_DAI: MorigamiVolatileChainlinkOracle;
    AAVE_USDC: MorigamiVolatileChainlinkOracle;
    SDAI_USDC: MorigamiErc4626Oracle;
    USD0pp_USD0: MorigamiVolatileCurveEmaOracle;
    USD0pp_USDC: MorigamiFixedPriceOracle;
    USD0_USDC: MorigamiVolatileCurveEmaOracle;
    RSWETH_WETH: MorigamiVolatileChainlinkOracle;
    PT_EBTC_DEC24_EBTC: MorigamiPendlePtToAssetOracle;
    PT_CORN_LBTC_DEC24_LBTC: MorigamiPendlePtToAssetOracle;
    WETH_CBBTC: MorigamiVolatileChainlinkOracle;
  };
  SWAPPERS: {
    DIRECT_SWAPPER: MorigamiDexAggregatorSwapper;
    SUSDE_SWAPPER: MorigamiErc4626AndDexAggregatorSwapper;
  };
  FLASHLOAN_PROVIDERS: {
    SPARK: MorigamiAaveV3FlashLoanProvider;
  };
  LOV_SUSDE_A: IMorphoType;
  LOV_SUSDE_B: IMorphoType;
  LOV_USDE_A: IMorphoType;
  LOV_USDE_B: IMorphoType;
  LOV_WEETH_A: IMorphoType;
  LOV_EZETH_A: IMorphoType;
  LOV_WSTETH_A: ISparkType;
  LOV_WSTETH_B: ISparkType;
  LOV_WOETH_A: IMorphoType;
  LOV_WETH_DAI_LONG_A: ISparkType;
  LOV_WETH_SDAI_SHORT_A: ISparkType;
  LOV_WBTC_DAI_LONG_A: ISparkType;
  LOV_WBTC_SDAI_SHORT_A: ISparkType;
  LOV_WETH_WBTC_LONG_A: ISparkType;
  LOV_WETH_WBTC_SHORT_A: ISparkType;
  LOV_PT_SUSDE_OCT24_A: IMorphoMarketALType;
  LOV_PT_SUSDE_MAR_2025_A: IMorphoMarketALType;
  LOV_MKR_DAI_LONG_A: ISparkType;
  LOV_AAVE_USDC_LONG_A: ISparkType;
  LOV_SDAI_A: IMorphoType;
  LOV_USD0pp_A: IMorphoType;
  LOV_RSWETH_A: IMorphoType;
  LOV_PT_EBTC_DEC24_A: IZeroLendType;
  LOV_PT_CORN_LBTC_DEC24_A: IZeroLendType;
  LOV_WETH_CBBTC_LONG_A: ISparkType;

  VAULTS: {
    SUSDSpS: {
      TOKEN: MorigamiSuperSavingsUsdsVault;
      MANAGER: MorigamiSuperSavingsUsdsManager;
      COW_SWAPPER: MorigamiCowSwapper;
    };
  };

  EXTERNAL: {
    WETH_TOKEN: IERC20Metadata;
    WBTC_TOKEN: IERC20Metadata;
    MAKER_DAO: {
      DAI_TOKEN: IERC20Metadata;
      SDAI_TOKEN: IERC4626;
      MKR_TOKEN: IERC20Metadata;
    };
    SKY: {
      USDS_TOKEN: IERC20Metadata;
      SUSDS_TOKEN: IERC4626;
      SKY_TOKEN: IERC20Metadata;
    };
    CIRCLE: {
      USDC_TOKEN: IERC20Metadata;
    };
    ETHENA: {
      USDE_TOKEN: IERC20Metadata;
      SUSDE_TOKEN: IERC4626;
    };
    ETHERFI: {
      WEETH_TOKEN: IERC20Metadata;
      LIQUIDITY_POOL: IEtherFiLiquidityPool;
      EBTC_TOKEN: IERC20Metadata;
    };
    RENZO: {
      EZETH_TOKEN: IERC20Metadata;
      RESTAKE_MANAGER: IRenzoRestakeManager;
    };
    LIDO: {
      STETH_TOKEN: IERC20Metadata;
      WSTETH_TOKEN: IERC20Metadata;
    };
    ORIGIN: {
      OETH_TOKEN: IERC20Metadata;
      WOETH_TOKEN: IERC4626;
    };
    USUAL: {
      USD0pp_TOKEN: IERC20Metadata;
      USD0_TOKEN: IERC20Metadata;
    };
    SWELL: {
      RSWETH_TOKEN: IERC20Metadata;
    };
    LOMBARD: {
      LBTC_TOKEN: IERC20Metadata;
    };
    COINBASE: {
      CBBTC_TOKEN: IERC20Metadata;
    };
    REDSTONE: {
      USDE_USD_ORACLE: AggregatorV3Interface;
      SUSDE_USD_ORACLE: AggregatorV3Interface;
      WEETH_WETH_ORACLE: AggregatorV3Interface;
      WEETH_USD_ORACLE: AggregatorV3Interface;
      EZETH_WETH_ORACLE: AggregatorV3Interface;
    };
    CHAINLINK: {
      ETH_USD_ORACLE: AggregatorV3Interface;
      STETH_ETH_ORACLE: AggregatorV3Interface;
    };
    MORPHO: {
      SINGLETON: IMorpho;
      IRM: AdaptiveCurveIrm;
      ORACLE: {
        SUSDE_DAI: MorphoChainlinkOracleV2;
        USDE_DAI: MorphoChainlinkOracleV2;
        WEETH_WETH: MorphoChainlinkOracleV2;
        EZETH_WETH: MorphoChainlinkOracleV2;
      };
    };
    SPARK: {
      POOL_ADDRESS_PROVIDER: IPoolAddressesProvider;
    };
    ZEROLEND: {
      MAINNET_BTC_POOL_ADDRESS_PROVIDER: IPoolAddressesProvider;
    };
    AAVE: {
      AAVE_TOKEN: IERC20Metadata;
      V3_MAINNET_POOL_ADDRESS_PROVIDER: IPoolAddressesProvider;
      V3_LIDO_POOL_ADDRESS_PROVIDER: IPoolAddressesProvider;
    };
    PENDLE: {
      SUSDE_OCT24: {
        PT_TOKEN: IERC20Metadata;
      };
      SUSDE_MAR_2025: {
        PT_TOKEN: IERC20Metadata;
      };
      EBTC_DEC24: {
        PT_TOKEN: IERC20Metadata;
      };
      CORN_LBTC_DEC24: {
        PT_TOKEN: IERC20Metadata;
      };
    };
  };

  MAINNET_TEST: {
    SWAPPERS: {
      COW_SWAPPER_1: MorigamiCowSwapper;
      COW_SWAPPER_2: MorigamiCowSwapper;
    },
  },
}

export function connectToContracts(owner: Signer): ContractInstances {
  return connectToContracts1(owner, getDeployedContracts());
}

export function connectToContracts1(owner: Signer, ADDRS: ContractAddresses): ContractInstances {
  return {
    CORE: {
      TOKEN_PRICES: {
          V1: TokenPrices__factory.connect(ADDRS.CORE.TOKEN_PRICES.V1, owner),
          V2: TokenPrices__factory.connect(ADDRS.CORE.TOKEN_PRICES.V2, owner),
          V3: TokenPrices__factory.connect(ADDRS.CORE.TOKEN_PRICES.V3, owner),
        },
    },
    ORACLES: {
      USDE_DAI: MorigamiStableChainlinkOracle__factory.connect(ADDRS.ORACLES.USDE_DAI, owner),
      SUSDE_DAI: MorigamiErc4626Oracle__factory.connect(ADDRS.ORACLES.SUSDE_DAI, owner),
      WEETH_WETH: MorigamiEtherFiEthToEthOracle__factory.connect(ADDRS.ORACLES.WEETH_WETH, owner),
      EZETH_WETH: MorigamiRenzoEthToEthOracle__factory.connect(ADDRS.ORACLES.EZETH_WETH, owner),
      STETH_WETH: MorigamiStableChainlinkOracle__factory.connect(ADDRS.ORACLES.STETH_WETH, owner),
      WSTETH_WETH: MorigamiWstEthToEthOracle__factory.connect(ADDRS.ORACLES.WSTETH_WETH, owner),
      WOETH_WETH: MorigamiErc4626Oracle__factory.connect(ADDRS.ORACLES.WOETH_WETH, owner),
      WETH_DAI: MorigamiVolatileChainlinkOracle__factory.connect(ADDRS.ORACLES.WETH_DAI, owner),
      WBTC_DAI: MorigamiVolatileChainlinkOracle__factory.connect(ADDRS.ORACLES.WBTC_DAI, owner),
      WETH_WBTC: MorigamiVolatileChainlinkOracle__factory.connect(ADDRS.ORACLES.WETH_WBTC, owner),
      WETH_SDAI: MorigamiCrossRateOracle__factory.connect(ADDRS.ORACLES.WETH_SDAI, owner),
      WBTC_SDAI: MorigamiCrossRateOracle__factory.connect(ADDRS.ORACLES.WBTC_SDAI, owner),
      DAI_USD: MorigamiStableChainlinkOracle__factory.connect(ADDRS.ORACLES.DAI_USD, owner),
      SDAI_DAI: MorigamiErc4626Oracle__factory.connect(ADDRS.ORACLES.SDAI_DAI, owner),
      PT_SUSDE_OCT24_USDE: MorigamiPendlePtToAssetOracle__factory.connect(ADDRS.ORACLES.PT_SUSDE_OCT24_USDE, owner),
      PT_SUSDE_OCT24_DAI: MorigamiCrossRateOracle__factory.connect(ADDRS.ORACLES.PT_SUSDE_OCT24_DAI, owner),
      PT_SUSDE_MAR_2025_USDE: MorigamiPendlePtToAssetOracle__factory.connect(ADDRS.ORACLES.PT_SUSDE_MAR_2025_USDE, owner),
      PT_SUSDE_MAR_2025_DAI: MorigamiCrossRateOracle__factory.connect(ADDRS.ORACLES.PT_SUSDE_MAR_2025_DAI, owner),
      PT_SUSDE_MAR_2025_DISCOUNT_TO_MATURITY: MorigamiVolatileChainlinkOracle__factory.connect(ADDRS.ORACLES.PT_SUSDE_MAR_2025_DISCOUNT_TO_MATURITY, owner),
      PT_SUSDE_MAR_2025_DAI_WITH_DISCOUNT_TO_MATURITY: MorigamiScaledOracle__factory.connect(ADDRS.ORACLES.PT_SUSDE_MAR_2025_DAI_WITH_DISCOUNT_TO_MATURITY, owner),
      MKR_DAI: MorigamiVolatileChainlinkOracle__factory.connect(ADDRS.ORACLES.MKR_DAI, owner),
      AAVE_USDC: MorigamiVolatileChainlinkOracle__factory.connect(ADDRS.ORACLES.AAVE_USDC, owner),
      SDAI_USDC: MorigamiErc4626Oracle__factory.connect(ADDRS.ORACLES.SDAI_USDC, owner),
      USD0pp_USD0: MorigamiVolatileCurveEmaOracle__factory.connect(ADDRS.ORACLES.USD0pp_USD0, owner),
      USD0pp_USDC: MorigamiFixedPriceOracle__factory.connect(ADDRS.ORACLES.USD0pp_USDC, owner),
      USD0_USDC: MorigamiVolatileCurveEmaOracle__factory.connect(ADDRS.ORACLES.USD0_USDC, owner),
      RSWETH_WETH: MorigamiVolatileChainlinkOracle__factory.connect(ADDRS.ORACLES.RSWETH_WETH, owner),
      PT_EBTC_DEC24_EBTC: MorigamiPendlePtToAssetOracle__factory.connect(ADDRS.ORACLES.PT_EBTC_DEC24_EBTC, owner),
      PT_CORN_LBTC_DEC24_LBTC: MorigamiPendlePtToAssetOracle__factory.connect(ADDRS.ORACLES.PT_CORN_LBTC_DEC24_LBTC, owner),
      WETH_CBBTC: MorigamiVolatileChainlinkOracle__factory.connect(ADDRS.ORACLES.WETH_CBBTC, owner),
    },
    SWAPPERS: {
      DIRECT_SWAPPER: MorigamiDexAggregatorSwapper__factory.connect(ADDRS.SWAPPERS.DIRECT_SWAPPER, owner),
      SUSDE_SWAPPER: MorigamiErc4626AndDexAggregatorSwapper__factory.connect(ADDRS.SWAPPERS.SUSDE_SWAPPER, owner),
    },
    FLASHLOAN_PROVIDERS: {
      SPARK: MorigamiAaveV3FlashLoanProvider__factory.connect(ADDRS.FLASHLOAN_PROVIDERS.SPARK, owner),
    },
    LOV_SUSDE_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_SUSDE_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_SUSDE_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_SUSDE_A.MANAGER, owner),
    },
    LOV_SUSDE_B: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_SUSDE_B.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_SUSDE_B.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_SUSDE_B.MANAGER, owner),
    },
    LOV_USDE_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_USDE_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_USDE_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_USDE_A.MANAGER, owner),
    },
    LOV_USDE_B: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_USDE_B.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_USDE_B.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_USDE_B.MANAGER, owner),
    },
    LOV_WEETH_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_WEETH_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WEETH_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_WEETH_A.MANAGER, owner),
    },
    LOV_EZETH_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_EZETH_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_EZETH_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_EZETH_A.MANAGER, owner),
    },
    LOV_WSTETH_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WSTETH_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_WSTETH_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_WSTETH_A.MANAGER, owner),
    },
    LOV_WSTETH_B: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WSTETH_B.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_WSTETH_B.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_WSTETH_B.MANAGER, owner),
    },
    LOV_WOETH_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_WOETH_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WOETH_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_WOETH_A.MANAGER, owner),
    },
    LOV_WETH_DAI_LONG_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WETH_DAI_LONG_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_WETH_DAI_LONG_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_WETH_DAI_LONG_A.MANAGER, owner),
    },
    LOV_WETH_SDAI_SHORT_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WETH_SDAI_SHORT_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_WETH_SDAI_SHORT_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_WETH_SDAI_SHORT_A.MANAGER, owner),
    },
    LOV_WBTC_DAI_LONG_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WBTC_DAI_LONG_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_WBTC_DAI_LONG_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_WBTC_DAI_LONG_A.MANAGER, owner),
    },
    LOV_WBTC_SDAI_SHORT_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WBTC_SDAI_SHORT_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_WBTC_SDAI_SHORT_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_WBTC_SDAI_SHORT_A.MANAGER, owner),
    },
    LOV_WETH_WBTC_LONG_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WETH_WBTC_LONG_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_WETH_WBTC_LONG_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_WETH_WBTC_LONG_A.MANAGER, owner),
    },
    LOV_WETH_WBTC_SHORT_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WETH_WBTC_SHORT_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_WETH_WBTC_SHORT_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_WETH_WBTC_SHORT_A.MANAGER, owner),
    },
    LOV_PT_SUSDE_OCT24_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_PT_SUSDE_OCT24_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_PT_SUSDE_OCT24_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManagerMarketAL__factory.connect(ADDRS.LOV_PT_SUSDE_OCT24_A.MANAGER, owner),
    },
    LOV_PT_SUSDE_MAR_2025_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_PT_SUSDE_MAR_2025_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_PT_SUSDE_MAR_2025_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManagerMarketAL__factory.connect(ADDRS.LOV_PT_SUSDE_MAR_2025_A.MANAGER, owner),
    },
    LOV_MKR_DAI_LONG_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_MKR_DAI_LONG_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_MKR_DAI_LONG_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_MKR_DAI_LONG_A.MANAGER, owner),
    },
    LOV_AAVE_USDC_LONG_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_AAVE_USDC_LONG_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_AAVE_USDC_LONG_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_AAVE_USDC_LONG_A.MANAGER, owner),
    },
    LOV_SDAI_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_SDAI_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_SDAI_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_SDAI_A.MANAGER, owner),
    },
    LOV_USD0pp_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_USD0pp_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_USD0pp_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_USD0pp_A.MANAGER, owner),
    },
    LOV_RSWETH_A: {
      MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_RSWETH_A.MORPHO_BORROW_LEND, owner),
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_RSWETH_A.TOKEN, owner),
      MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_RSWETH_A.MANAGER, owner),
    },
    LOV_PT_EBTC_DEC24_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_PT_EBTC_DEC24_A.TOKEN, owner),
      ZEROLEND_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_PT_EBTC_DEC24_A.ZEROLEND_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_PT_EBTC_DEC24_A.MANAGER, owner),
    },
    LOV_PT_CORN_LBTC_DEC24_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_PT_CORN_LBTC_DEC24_A.TOKEN, owner),
      ZEROLEND_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_PT_CORN_LBTC_DEC24_A.ZEROLEND_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_PT_CORN_LBTC_DEC24_A.MANAGER, owner),
    },
    LOV_WETH_CBBTC_LONG_A: {
      TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_WETH_CBBTC_LONG_A.TOKEN, owner),
      SPARK_BORROW_LEND: MorigamiAaveV3BorrowAndLend__factory.connect(ADDRS.LOV_WETH_CBBTC_LONG_A.SPARK_BORROW_LEND, owner),
      MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_WETH_CBBTC_LONG_A.MANAGER, owner),
    },

    VAULTS: {
      SUSDSpS: {
        TOKEN: MorigamiSuperSavingsUsdsVault__factory.connect(ADDRS.VAULTS.SUSDSpS.TOKEN, owner),
        MANAGER: MorigamiSuperSavingsUsdsManager__factory.connect(ADDRS.VAULTS.SUSDSpS.MANAGER, owner),
        COW_SWAPPER: MorigamiCowSwapper__factory.connect(ADDRS.VAULTS.SUSDSpS.COW_SWAPPER, owner),
      },
    },
    
    EXTERNAL: {
      WETH_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.WETH_TOKEN, owner),
      WBTC_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.WBTC_TOKEN, owner),
      MAKER_DAO: {
        DAI_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.MAKER_DAO.DAI_TOKEN, owner),
        SDAI_TOKEN: IERC4626__factory.connect(ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN, owner),
        MKR_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.MAKER_DAO.MKR_TOKEN, owner),
      },
      SKY: {
        USDS_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.SKY.USDS_TOKEN, owner),
        SUSDS_TOKEN: IERC4626__factory.connect(ADDRS.EXTERNAL.SKY.SUSDS_TOKEN, owner),
        SKY_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.SKY.SKY_TOKEN, owner),
      },
      CIRCLE: {
        USDC_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.CIRCLE.USDC_TOKEN, owner),
      },
      ETHENA: {
        USDE_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.ETHENA.USDE_TOKEN, owner),
        SUSDE_TOKEN: IERC4626__factory.connect(ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN, owner),
      },
      ETHERFI: {
        WEETH_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.ETHERFI.WEETH_TOKEN, owner),
        LIQUIDITY_POOL: IEtherFiLiquidityPool__factory.connect(ADDRS.EXTERNAL.ETHERFI.LIQUIDITY_POOL, owner),
        EBTC_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.ETHERFI.EBTC_TOKEN, owner),
      },
      RENZO: {
        EZETH_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.RENZO.EZETH_TOKEN, owner),
        RESTAKE_MANAGER: IRenzoRestakeManager__factory.connect(ADDRS.EXTERNAL.RENZO.RESTAKE_MANAGER, owner),
      },
      LIDO: {
        STETH_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.LIDO.STETH_TOKEN, owner),
        WSTETH_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.LIDO.WSTETH_TOKEN, owner),
      },
      ORIGIN: {
        OETH_TOKEN: IERC4626__factory.connect(ADDRS.EXTERNAL.ORIGIN.OETH_TOKEN, owner),
        WOETH_TOKEN: IERC4626__factory.connect(ADDRS.EXTERNAL.ORIGIN.WOETH_TOKEN, owner),
      },
      USUAL: {
        USD0pp_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.USUAL.USD0pp_TOKEN, owner),
        USD0_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.USUAL.USD0_TOKEN, owner),
      },
      SWELL: {
        RSWETH_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.SWELL.RSWETH_TOKEN, owner),
      },
      LOMBARD: {
        LBTC_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.LOMBARD.LBTC_TOKEN, owner),
      },
      COINBASE: {
        CBBTC_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.COINBASE.CBBTC_TOKEN, owner),
      },
      REDSTONE: {
        USDE_USD_ORACLE: AggregatorV3Interface__factory.connect(ADDRS.EXTERNAL.REDSTONE.USDE_USD_ORACLE, owner),
        SUSDE_USD_ORACLE: AggregatorV3Interface__factory.connect(ADDRS.EXTERNAL.REDSTONE.SUSDE_USD_ORACLE, owner),
        WEETH_WETH_ORACLE: AggregatorV3Interface__factory.connect(ADDRS.EXTERNAL.REDSTONE.WEETH_WETH_ORACLE, owner),
        WEETH_USD_ORACLE: AggregatorV3Interface__factory.connect(ADDRS.EXTERNAL.REDSTONE.WEETH_USD_ORACLE, owner),
        EZETH_WETH_ORACLE: AggregatorV3Interface__factory.connect(ADDRS.EXTERNAL.REDSTONE.EZETH_WETH_ORACLE, owner),
      },
      CHAINLINK: {
        ETH_USD_ORACLE: AggregatorV3Interface__factory.connect(ADDRS.EXTERNAL.CHAINLINK.ETH_USD_ORACLE, owner),
        STETH_ETH_ORACLE: AggregatorV3Interface__factory.connect(ADDRS.EXTERNAL.CHAINLINK.STETH_ETH_ORACLE, owner),
      },
      MORPHO: {
        SINGLETON: IMorpho__factory.connect(ADDRS.EXTERNAL.MORPHO.SINGLETON, owner),
        IRM: AdaptiveCurveIrm__factory.connect(ADDRS.EXTERNAL.MORPHO.IRM, owner),
        ORACLE: {
          SUSDE_DAI: MorphoChainlinkOracleV2__factory.connect(ADDRS.EXTERNAL.MORPHO.ORACLE.SUSDE_DAI, owner),
          USDE_DAI: MorphoChainlinkOracleV2__factory.connect(ADDRS.EXTERNAL.MORPHO.ORACLE.USDE_DAI, owner),
          WEETH_WETH: MorphoChainlinkOracleV2__factory.connect(ADDRS.EXTERNAL.MORPHO.ORACLE.WEETH_WETH, owner),
          EZETH_WETH: MorphoChainlinkOracleV2__factory.connect(ADDRS.EXTERNAL.MORPHO.ORACLE.EZETH_WETH, owner),
        },
      },
      SPARK: {
        POOL_ADDRESS_PROVIDER: IPoolAddressesProvider__factory.connect(ADDRS.EXTERNAL.SPARK.POOL_ADDRESS_PROVIDER, owner),
      },
      AAVE: {
        AAVE_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.AAVE.AAVE_TOKEN, owner),
        V3_MAINNET_POOL_ADDRESS_PROVIDER: IPoolAddressesProvider__factory.connect(ADDRS.EXTERNAL.AAVE.V3_MAINNET_POOL_ADDRESS_PROVIDER, owner),
        V3_LIDO_POOL_ADDRESS_PROVIDER: IPoolAddressesProvider__factory.connect(ADDRS.EXTERNAL.AAVE.V3_LIDO_POOL_ADDRESS_PROVIDER, owner),
      },
      ZEROLEND: {
        MAINNET_BTC_POOL_ADDRESS_PROVIDER: IPoolAddressesProvider__factory.connect(ADDRS.EXTERNAL.ZEROLEND.MAINNET_BTC_POOL_ADDRESS_PROVIDER, owner),
      },
      PENDLE: {
        SUSDE_OCT24: {
          PT_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.PENDLE.SUSDE_OCT24.PT_TOKEN, owner),
        },
        SUSDE_MAR_2025: {
          PT_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.PENDLE.SUSDE_MAR_2025.PT_TOKEN, owner),
        },
        EBTC_DEC24: {
          PT_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.PENDLE.EBTC_DEC24.PT_TOKEN, owner),
        },
        CORN_LBTC_DEC24: {
          PT_TOKEN: IERC20Metadata__factory.connect(ADDRS.EXTERNAL.PENDLE.CORN_LBTC_DEC24.PT_TOKEN, owner),
        },
      },
    },

    MAINNET_TEST: {
      SWAPPERS: {
        COW_SWAPPER_1: MorigamiCowSwapper__factory.connect(ADDRS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_1, owner),
        COW_SWAPPER_2: MorigamiCowSwapper__factory.connect(ADDRS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2, owner),
      },
    },
  }
}
