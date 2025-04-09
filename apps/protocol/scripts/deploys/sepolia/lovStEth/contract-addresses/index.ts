import { network } from "hardhat";
import { 
  RelayedOracle, RelayedOracle__factory,
  MorigamiDexAggregatorSwapper, MorigamiDexAggregatorSwapper__factory, 
  TokenPrices, TokenPrices__factory,
  MorigamiStableChainlinkOracle,
  MorigamiStableChainlinkOracle__factory,
  MockWrappedEther,
  MockStEthToken,
  MockWstEthToken,
  MockWrappedEther__factory,
  MockWstEthToken__factory,
  MockStEthToken__factory,
  MorigamiWstEthToEthOracle,
  MorigamiWstEthToEthOracle__factory,
  MockFlashLoanProvider,
  MockFlashLoanProvider__factory,
  MorigamiLovToken,
  MorigamiLovTokenFlashAndBorrowManager,
  MorigamiLovToken__factory,
  MorigamiLovTokenFlashAndBorrowManager__factory,
  MockBorrowAndLend,
  MockBorrowAndLend__factory
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
    TOKEN_PRICES: TokenPrices;
    SWAPPER_1INCH: MorigamiDexAggregatorSwapper;
    SPARK_FLASH_LOAN_PROVIDER: MockFlashLoanProvider;
  },
  ORACLES: {
    STETH_ETH: MorigamiStableChainlinkOracle;
    WSTETH_ETH: MorigamiWstEthToEthOracle;
  },
  LOV_STETH: {
    TOKEN: MorigamiLovToken;
    SPARK_BORROW_LEND: MockBorrowAndLend;
    MANAGER: MorigamiLovTokenFlashAndBorrowManager;
  },
  EXTERNAL: {
    WETH_TOKEN: MockWrappedEther,
    LIDO: {
      ST_ETH_TOKEN: MockStEthToken,
      WST_ETH_TOKEN: MockWstEthToken,
    },
    CHAINLINK: {
      STETH_ETH_ORACLE: RelayedOracle;
      ETH_USD_ORACLE: RelayedOracle;
    },
  },
}

export function connectToContracts(owner: Signer): ContractInstances {
    const ADDRS = getDeployedContracts();

    return {
      CORE: {
        TOKEN_PRICES: TokenPrices__factory.connect(ADDRS.CORE.TOKEN_PRICES, owner),
        SWAPPER_1INCH: MorigamiDexAggregatorSwapper__factory.connect(ADDRS.CORE.SWAPPER_1INCH, owner),
        SPARK_FLASH_LOAN_PROVIDER: MockFlashLoanProvider__factory.connect(ADDRS.CORE.SPARK_FLASH_LOAN_PROVIDER, owner)
      },
      ORACLES: {
        STETH_ETH: MorigamiStableChainlinkOracle__factory.connect(ADDRS.ORACLES.STETH_ETH, owner),
        WSTETH_ETH: MorigamiWstEthToEthOracle__factory.connect(ADDRS.ORACLES.WSTETH_ETH, owner),
      },
      LOV_STETH: {
        TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_STETH.TOKEN, owner),
        SPARK_BORROW_LEND: MockBorrowAndLend__factory.connect(ADDRS.LOV_STETH.SPARK_BORROW_LEND, owner),
        MANAGER: MorigamiLovTokenFlashAndBorrowManager__factory.connect(ADDRS.LOV_STETH.MANAGER, owner),
      },
      EXTERNAL: {
        WETH_TOKEN: MockWrappedEther__factory.connect(ADDRS.EXTERNAL.WETH_TOKEN, owner),
        LIDO: {
          ST_ETH_TOKEN: MockStEthToken__factory.connect(ADDRS.EXTERNAL.LIDO.ST_ETH_TOKEN, owner),
          WST_ETH_TOKEN: MockWstEthToken__factory.connect(ADDRS.EXTERNAL.LIDO.WST_ETH_TOKEN, owner),
        },
        CHAINLINK: {
          STETH_ETH_ORACLE: RelayedOracle__factory.connect(ADDRS.EXTERNAL.CHAINLINK.STETH_ETH_ORACLE, owner),
          ETH_USD_ORACLE: RelayedOracle__factory.connect(ADDRS.EXTERNAL.CHAINLINK.ETH_USD_ORACLE, owner),
        },
      },
    }
  }
