import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import { ensureExpectedEnvvars, mine } from "../../../helpers";
import {
  ContractInstances,
  connectToContracts,
  getDeployedContracts,
} from "../../contract-addresses";

let INSTANCES: ContractInstances;

async function main() {
  ensureExpectedEnvvars();

  const [owner] = await ethers.getSigners();
  const ADDRS = getDeployedContracts();
  INSTANCES = connectToContracts(owner);

  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.TOKEN.proposeNewOwner(ADDRS.CORE.MULTISIG)
  );
  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.SPARK_BORROW_LEND.proposeNewOwner(
      ADDRS.CORE.MULTISIG
    )
  );
  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.MANAGER.proposeNewOwner(
      ADDRS.CORE.MULTISIG
    )
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
