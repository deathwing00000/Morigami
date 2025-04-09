import { network } from "hardhat";
import { 
  RelayedOracle, RelayedOracle__factory,
  MorigamiDexAggregatorSwapper, MorigamiDexAggregatorSwapper__factory, 
  TokenPrices, TokenPrices__factory,
  MorigamiStableChainlinkOracle,
  MorigamiStableChainlinkOracle__factory,
  MorigamiLovToken,
  MorigamiLovToken__factory,
  DummyMintableToken,
  MorigamiLovTokenMorphoManager,
  MorigamiMorphoBorrowAndLend,
  MorigamiMorphoBorrowAndLend__factory,
  MorigamiLovTokenMorphoManager__factory,
  DummyMintableToken__factory,
  Morpho,
  AdaptiveCurveIrm,
  MorphoChainlinkOracleV2,
  Morpho__factory,
  AdaptiveCurveIrm__factory,
  MorphoChainlinkOracleV2__factory
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
  },
  ORACLES: {
    USDE_DAI: MorigamiStableChainlinkOracle;
  },
  LOV_USDE: {
    SWAPPER_1INCH: MorigamiDexAggregatorSwapper;
    TOKEN: MorigamiLovToken;
    MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend;
    MANAGER: MorigamiLovTokenMorphoManager;
  },
  EXTERNAL: {
    MAKER_DAO: {
      DAI_TOKEN: DummyMintableToken;
    },
    ETHENA: {
      USDE_TOKEN: DummyMintableToken,
    },
    REDSTONE: {
      USDE_USD_ORACLE: RelayedOracle;
    },
    MORPHO: {
      SINGLETON: Morpho,
      IRM: AdaptiveCurveIrm,
      USDE_USD_ORACLE: MorphoChainlinkOracleV2,
    }
  },
}

export function connectToContracts(owner: Signer): ContractInstances {
    const ADDRS = getDeployedContracts();

    return {
      CORE: {
        TOKEN_PRICES: TokenPrices__factory.connect(ADDRS.CORE.TOKEN_PRICES, owner),
      },
      ORACLES: {
        USDE_DAI: MorigamiStableChainlinkOracle__factory.connect(ADDRS.ORACLES.USDE_DAI, owner),
      },
      LOV_USDE: {
        SWAPPER_1INCH: MorigamiDexAggregatorSwapper__factory.connect(ADDRS.LOV_USDE.SWAPPER_1INCH, owner),
        TOKEN: MorigamiLovToken__factory.connect(ADDRS.LOV_USDE.TOKEN, owner),
        MORPHO_BORROW_LEND: MorigamiMorphoBorrowAndLend__factory.connect(ADDRS.LOV_USDE.MORPHO_BORROW_LEND, owner),
        MANAGER: MorigamiLovTokenMorphoManager__factory.connect(ADDRS.LOV_USDE.MANAGER, owner),
      },
      EXTERNAL: {
        MAKER_DAO: {
          DAI_TOKEN: DummyMintableToken__factory.connect(ADDRS.EXTERNAL.MAKER_DAO.DAI_TOKEN, owner),
        },
        ETHENA: {
          USDE_TOKEN: DummyMintableToken__factory.connect(ADDRS.EXTERNAL.ETHENA.USDE_TOKEN, owner),
        },
        REDSTONE: {
          USDE_USD_ORACLE: RelayedOracle__factory.connect(ADDRS.EXTERNAL.REDSTONE.USDE_USD_ORACLE, owner),
        },
        MORPHO: {
          SINGLETON: Morpho__factory.connect(ADDRS.EXTERNAL.MORPHO.SINGLETON, owner),
          IRM: AdaptiveCurveIrm__factory.connect(ADDRS.EXTERNAL.MORPHO.IRM, owner),
          USDE_USD_ORACLE: MorphoChainlinkOracleV2__factory.connect(ADDRS.EXTERNAL.MORPHO.USDE_USD_ORACLE, owner),
        },
      },
    }
  }
