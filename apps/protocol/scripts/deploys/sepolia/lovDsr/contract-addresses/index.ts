import { network } from "hardhat";
import { 
  DummyMintableToken, DummyMintableToken__factory,
  RelayedOracle, RelayedOracle__factory,
  LinearWithKinkInterestRateModel, LinearWithKinkInterestRateModel__factory,
  MockSDaiToken, MockSDaiToken__factory,
  MorigamiAaveV3IdleStrategy, MorigamiAaveV3IdleStrategy__factory, 
  MorigamiCircuitBreakerAllUsersPerPeriod, MorigamiCircuitBreakerAllUsersPerPeriod__factory, 
  MorigamiCircuitBreakerProxy, MorigamiCircuitBreakerProxy__factory, 
  MorigamiCrossRateOracle, MorigamiCrossRateOracle__factory, 
  MorigamiDebtToken, MorigamiDebtToken__factory, 
  MorigamiDexAggregatorSwapper, MorigamiDexAggregatorSwapper__factory, 
  MorigamiIdleStrategyManager, MorigamiIdleStrategyManager__factory, 
  MorigamiInvestmentVault, MorigamiInvestmentVault__factory, 
  MorigamiLendingClerk, MorigamiLendingClerk__factory, 
  MorigamiLendingRewardsMinter, MorigamiLendingRewardsMinter__factory, 
  MorigamiLendingSupplyManager, MorigamiLendingSupplyManager__factory, 
  MorigamiLovToken, MorigamiLovToken__factory, 
  MorigamiLovTokenErc4626Manager, MorigamiLovTokenErc4626Manager__factory, 
  MorigamiOToken, MorigamiOToken__factory, TokenPrices, TokenPrices__factory,
  MorigamiStableChainlinkOracle,
  MorigamiStableChainlinkOracle__factory
} from "../../../../../typechain";
import { Signer } from "ethers";
import { ContractAddresses } from "./types";
import { CONTRACTS as SEPOLIA_CONTRACTS } from "./sepolia";
import { CONTRACTS as LOCALHOST_CONTRACTS } from "./localhost";


export function getDeployedContracts(): ContractAddresses {
  if (network.name === 'sepolia') {
    return SEPOLIA_CONTRACTS;
  } else if (network.name === 'localhost') {
    return LOCALHOST_CONTRACTS;
  }
  console.log(`No contracts configured for ${network.name}`);
  throw new Error(`No contracts configured for ${network.name}`);
}

export interface ContractInstances {
  CORE: {
    CIRCUIT_BREAKER_PROXY: MorigamiCircuitBreakerProxy;
    TOKEN_PRICES: TokenPrices;
    SWAPPER_1INCH: MorigamiDexAggregatorSwapper;
  },
  OV_USDC: {
    TOKENS: {
      OV_USDC_TOKEN: MorigamiInvestmentVault;
      O_USDC_TOKEN: MorigamiOToken;
      IUSDC_DEBT_TOKEN: MorigamiDebtToken;
    },
    SUPPLY: {
      SUPPLY_MANAGER: MorigamiLendingSupplyManager;
      REWARDS_MINTER: MorigamiLendingRewardsMinter;
      IDLE_STRATEGY_MANAGER: MorigamiIdleStrategyManager;
      AAVE_V3_IDLE_STRATEGY: MorigamiAaveV3IdleStrategy;
    },
    BORROW: {
        LENDING_CLERK: MorigamiLendingClerk;
        CIRCUIT_BREAKER_USDC_BORROW: MorigamiCircuitBreakerAllUsersPerPeriod;
        CIRCUIT_BREAKER_OUSDC_EXIT: MorigamiCircuitBreakerAllUsersPerPeriod;
        GLOBAL_INTEREST_RATE_MODEL: LinearWithKinkInterestRateModel;
    },
  },
  LOV_DSR: {
    LOV_DSR_TOKEN: MorigamiLovToken;
    LOV_DSR_MANAGER: MorigamiLovTokenErc4626Manager;
    LOV_DSR_IR_MODEL: LinearWithKinkInterestRateModel;
  },
  ORACLES: {
    DAI_USD: MorigamiStableChainlinkOracle;
    IUSDC_USD: MorigamiStableChainlinkOracle;
    DAI_IUSDC: MorigamiCrossRateOracle;
  },
  EXTERNAL: {
    MAKER_DAO: {
      DAI_TOKEN: DummyMintableToken;
      SDAI_TOKEN: MockSDaiToken;
    },
    CIRCLE: {
      USDC_TOKEN: DummyMintableToken;
    },
    CHAINLINK: {
      DAI_USD_ORACLE: RelayedOracle;
      USDC_USD_ORACLE: RelayedOracle;
      ETH_USD_ORACLE: RelayedOracle;
    },
  },
}
export function connectToContracts(owner: Signer): ContractInstances {
    const ADDRS = getDeployedContracts();

    return {
      CORE: {
        CIRCUIT_BREAKER_PROXY: MorigamiCircuitBreakerProxy__factory.connect(ADDRS.CORE.CIRCUIT_BREAKER_PROXY, owner),
        TOKEN_PRICES: TokenPrices__factory.connect(ADDRS.CORE.TOKEN_PRICES, owner),
        SWAPPER_1INCH: MorigamiDexAggregatorSwapper__factory.connect(ADDRS.CORE.SWAPPER_1INCH, owner),
      },
      OV_USDC: {
        TOKENS: {
          OV_USDC_TOKEN: MorigamiInvestmentVault__factory.connect(ADDRS.OV_USDC.TOKENS.OV_USDC_TOKEN, owner),
          O_USDC_TOKEN: MorigamiOToken__factory.connect(ADDRS.OV_USDC.TOKENS.O_USDC_TOKEN, owner),
          IUSDC_DEBT_TOKEN: MorigamiDebtToken__factory.connect(ADDRS.OV_USDC.TOKENS.IUSDC_DEBT_TOKEN, owner),
        },
        SUPPLY: {
          SUPPLY_MANAGER: MorigamiLendingSupplyManager__factory.connect(ADDRS.OV_USDC.SUPPLY.SUPPLY_MANAGER, owner),
          REWARDS_MINTER: MorigamiLendingRewardsMinter__factory.connect(ADDRS.OV_USDC.SUPPLY.REWARDS_MINTER, owner),
          IDLE_STRATEGY_MANAGER: MorigamiIdleStrategyManager__factory.connect(ADDRS.OV_USDC.SUPPLY.IDLE_STRATEGY_MANAGER, owner),
          AAVE_V3_IDLE_STRATEGY: MorigamiAaveV3IdleStrategy__factory.connect(ADDRS.OV_USDC.SUPPLY.AAVE_V3_IDLE_STRATEGY, owner),
        },
        BORROW: {
            LENDING_CLERK: MorigamiLendingClerk__factory.connect(ADDRS.OV_USDC.BORROW.LENDING_CLERK, owner),
            CIRCUIT_BREAKER_USDC_BORROW: MorigamiCircuitBreakerAllUsersPerPeriod__factory.connect(ADDRS.OV_USDC.BORROW.CIRCUIT_BREAKER_USDC_BORROW, owner),
            CIRCUIT_BREAKER_OUSDC_EXIT: MorigamiCircuitBreakerAllUsersPerPeriod__factory.connect(ADDRS.OV_USDC.BORROW.CIRCUIT_BREAKER_OUSDC_EXIT, owner),
            GLOBAL_INTEREST_RATE_MODEL: LinearWithKinkInterestRateModel__factory.connect(ADDRS.OV_USDC.BORROW.GLOBAL_INTEREST_RATE_MODEL, owner),
        },
      },
      LOV_DSR: {
        LOV_DSR_TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_DSR.LOV_DSR_TOKEN, owner),
        LOV_DSR_MANAGER: MorigamiLovTokenErc4626Manager__factory.connect(ADDRS.LOV_DSR.LOV_DSR_MANAGER, owner),
        LOV_DSR_IR_MODEL: LinearWithKinkInterestRateModel__factory.connect(ADDRS.LOV_DSR.LOV_DSR_IR_MODEL, owner),
      },
      ORACLES: {
        DAI_USD: MorigamiStableChainlinkOracle__factory.connect(ADDRS.ORACLES.DAI_USD, owner),
        IUSDC_USD: MorigamiStableChainlinkOracle__factory.connect(ADDRS.ORACLES.IUSDC_USD, owner),
        DAI_IUSDC: MorigamiCrossRateOracle__factory.connect(ADDRS.ORACLES.DAI_IUSDC, owner),
      },
      EXTERNAL: {
        MAKER_DAO: {
          DAI_TOKEN: DummyMintableToken__factory.connect(ADDRS.EXTERNAL.MAKER_DAO.DAI_TOKEN, owner),
          SDAI_TOKEN: MockSDaiToken__factory.connect(ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN, owner),
        },
        CIRCLE: {
          USDC_TOKEN: DummyMintableToken__factory.connect(ADDRS.EXTERNAL.CIRCLE.USDC_TOKEN, owner),
        },
        CHAINLINK: {
          DAI_USD_ORACLE: RelayedOracle__factory.connect(ADDRS.EXTERNAL.CHAINLINK.DAI_USD_ORACLE, owner),
          USDC_USD_ORACLE: RelayedOracle__factory.connect(ADDRS.EXTERNAL.CHAINLINK.USDC_USD_ORACLE, owner),
          ETH_USD_ORACLE: RelayedOracle__factory.connect(ADDRS.EXTERNAL.CHAINLINK.ETH_USD_ORACLE, owner),
        },
      },
    }
  }
