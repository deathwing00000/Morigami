import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import { MorigamiAaveV3BorrowAndLend__factory } from "../../../../../typechain";
import { deployAndMine, ensureExpectedEnvvars } from "../../../helpers";
import {
  connectToContracts1,
  getDeployedContracts1,
} from "../../contract-addresses";
import { DEFAULT_SETTINGS } from "../../default-settings";

async function main() {
  ensureExpectedEnvvars();
  const [owner] = await ethers.getSigners();
  const ADDRS = await getDeployedContracts1(__dirname);
  const INSTANCES = connectToContracts1(owner, ADDRS);

  const factory = new MorigamiAaveV3BorrowAndLend__factory(owner);
  await deployAndMine(
    "LOV_TEST_ANKRFLOW_FLOW.SPARK_BORROW_LEND",
    factory,
    factory.deploy,
    await owner.getAddress(),
    ADDRS.EXTERNAL.ANKRFLOW_TOKEN,
    ADDRS.EXTERNAL.WFLOW_TOKEN,
    await INSTANCES.EXTERNAL.MORE.V3_POOL_ADDRESS_PROVIDER.getPool(),
    DEFAULT_SETTINGS.EXTERNAL.MORE.EMODES.NATIVE
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
