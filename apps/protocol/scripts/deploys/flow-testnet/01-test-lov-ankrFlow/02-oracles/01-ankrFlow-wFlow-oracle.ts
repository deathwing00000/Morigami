import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import { MorigamiVolatileChainlinkOracle__factory } from "../../../../../typechain";
import { deployAndMine, ensureExpectedEnvvars } from "../../../helpers";
import {
  connectToContracts,
  getDeployedContracts,
} from "../../contract-addresses";
import { DEFAULT_SETTINGS } from "../../default-settings";

async function main() {
  ensureExpectedEnvvars();
  const [owner] = await ethers.getSigners();
  const ADDRS = getDeployedContracts();
  const INSTANCES = connectToContracts(owner);

  const factory = new MorigamiVolatileChainlinkOracle__factory(owner);
  await deployAndMine(
    "ORACLES.ANKRFLOW_WFLOW",
    factory,
    factory.deploy,
    {
      description: "ankrFLOW/wFLOW",
      baseAssetAddress: ADDRS.EXTERNAL.ANKRFLOW_TOKEN,
      baseAssetDecimals: await INSTANCES.EXTERNAL.ANKRFLOW_TOKEN.decimals(),
      quoteAssetAddress: ADDRS.EXTERNAL.WFLOW_TOKEN,
      quoteAssetDecimals: await INSTANCES.EXTERNAL.WFLOW_TOKEN.decimals(),
    },
    ADDRS.EXTERNAL.CHAINLINK.ANKRFLOW_WFLOW_ORACLE,
    DEFAULT_SETTINGS.EXTERNAL.CHAINLINK.ANKRFLOW_WFLOW_ORACLE
      .STALENESS_THRESHOLD,
    true, // Chainlink does use roundId
    true // It does use the lastUpdatedAt
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
