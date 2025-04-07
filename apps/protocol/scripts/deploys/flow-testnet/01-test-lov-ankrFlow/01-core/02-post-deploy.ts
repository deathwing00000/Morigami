import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import {
  encodedOraclePrice,
  ensureExpectedEnvvars,
  mine,
} from "../../../helpers";
import {
  ContractInstances,
  connectToContracts,
  getDeployedContracts,
} from "../../contract-addresses";
import { ContractAddresses } from "../../contract-addresses/types";
import { DEFAULT_SETTINGS } from "../../default-settings";

let ADDRS: ContractAddresses;
let INSTANCES: ContractInstances;

async function setupPrices() {
  // ANKRFLOW/USD
  const encodedAnkrFlowToUsd = encodedOraclePrice(
    ADDRS.EXTERNAL.CHAINLINK.ANKRFLOW_USD_ORACLE,
    DEFAULT_SETTINGS.EXTERNAL.CHAINLINK.ANKRFLOW_USD_ORACLE.STALENESS_THRESHOLD
  );
  await mine(
    INSTANCES.CORE.TOKEN_PRICES.V1.setTokenPriceFunction(
      ADDRS.EXTERNAL.ANKRFLOW_TOKEN,
      encodedAnkrFlowToUsd
    )
  );

  // WFLOW/USD
  const encodedWFlowToUsd = encodedOraclePrice(
    ADDRS.EXTERNAL.CHAINLINK.WFLOW_USD_ORACLE,
    DEFAULT_SETTINGS.EXTERNAL.CHAINLINK.WFLOW_USD_ORACLE.STALENESS_THRESHOLD
  );
  await mine(
    INSTANCES.CORE.TOKEN_PRICES.V1.setTokenPriceFunction(
      ADDRS.EXTERNAL.WFLOW_TOKEN,
      encodedWFlowToUsd
    )
  );
}

async function main() {
  ensureExpectedEnvvars();

  const [owner] = await ethers.getSigners();
  ADDRS = getDeployedContracts();
  INSTANCES = connectToContracts(owner);

  await setupPrices();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
