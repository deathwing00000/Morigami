import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import { MorigamiLovTokenFlashAndBorrowManager__factory } from "../../../../../typechain";
import { deployAndMine, ensureExpectedEnvvars } from "../../../helpers";
import { getDeployedContracts1 } from "../../contract-addresses";

async function main() {
  ensureExpectedEnvvars();
  const [owner] = await ethers.getSigners();
  const ADDRS = await getDeployedContracts1(__dirname);

  const factory = new MorigamiLovTokenFlashAndBorrowManager__factory(owner);
  await deployAndMine(
    "LOV_TEST_ANKRFLOW_FLOW.MANAGER",
    factory,
    factory.deploy,
    await owner.getAddress(),
    ADDRS.EXTERNAL.ANKRFLOW_TOKEN,
    ADDRS.EXTERNAL.WFLOW_TOKEN,
    ADDRS.EXTERNAL.ANKRFLOW_TOKEN,
    ADDRS.LOV_TEST_ANKRFLOW_FLOW.TOKEN,
    ADDRS.FLASHLOAN_PROVIDERS.MORE,
    ADDRS.LOV_TEST_ANKRFLOW_FLOW.SPARK_BORROW_LEND
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
