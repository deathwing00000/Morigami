import "@nomiclabs/hardhat-ethers";
import { ethers, network } from "hardhat";
import {
  encodedRepricingTokenPrice,
  ensureExpectedEnvvars,
  impersonateAndFund,
  mine,
} from "../../../helpers";
import {
  ContractInstances,
  connectToContracts1,
  getDeployedContracts1,
} from "../../contract-addresses";
import { ContractAddresses } from "../../contract-addresses/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { DEFAULT_SETTINGS } from "../../default-settings";
import { TokenPrices } from "../../../../../typechain";
import {
  createSafeBatch,
  setTokenPriceFunction,
  writeSafeTransactionsBatch,
} from "../../../safe-tx-builder";
import path from "path";

let ADDRS: ContractAddresses;
let INSTANCES: ContractInstances;

const getEncodedPrices = () => ({
  lovTokenToUsd: encodedRepricingTokenPrice(ADDRS.LOV_TEST_ANKRFLOW_FLOW.TOKEN),
});

async function updatePrices(contract: TokenPrices) {
  const encodedPrices = getEncodedPrices();

  await mine(
    contract.setTokenPriceFunction(
      ADDRS.LOV_TEST_ANKRFLOW_FLOW.TOKEN,
      encodedPrices.lovTokenToUsd
    )
  );
}

async function updatePricesSafeBatch(contract: TokenPrices) {
  const encodedPrices = getEncodedPrices();

  const batch = createSafeBatch(1, [
    setTokenPriceFunction(
      contract,
      ADDRS.LOV_TEST_ANKRFLOW_FLOW.TOKEN,
      encodedPrices.lovTokenToUsd
    ),
  ]);

  const filename = path.join(__dirname, "../transactions-batch.json");
  writeSafeTransactionsBatch(batch, filename);
  console.log(`Wrote Safe tx's batch to: ${filename}`);
}

// Required for testnet run to impersonate the msig
async function setupPricesTestnet(owner: SignerWithAddress) {
  const signer = await impersonateAndFund(owner, ADDRS.CORE.MULTISIG);
  await updatePrices(INSTANCES.CORE.TOKEN_PRICES.V1.connect(signer));
}

async function setupPrices() {
  updatePricesSafeBatch(INSTANCES.CORE.TOKEN_PRICES.V1);
}

async function main() {
  ensureExpectedEnvvars();

  const [owner] = await ethers.getSigners();
  ADDRS = await getDeployedContracts1(__dirname);
  INSTANCES = connectToContracts1(owner, ADDRS);

  // Initial setup of config.
  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.SPARK_BORROW_LEND.setPositionOwner(
      ADDRS.LOV_TEST_ANKRFLOW_FLOW.MANAGER
    )
  );

  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.MANAGER.setOracles(
      ADDRS.ORACLES.ANKRFLOW_WFLOW,
      ADDRS.ORACLES.ANKRFLOW_WFLOW
    )
  );

  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.MANAGER.setUserALRange(
      DEFAULT_SETTINGS.LOV_TEST_ANKRFLOW_FLOW.USER_AL_FLOOR,
      DEFAULT_SETTINGS.LOV_TEST_ANKRFLOW_FLOW.USER_AL_CEILING
    )
  );
  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.MANAGER.setRebalanceALRange(
      DEFAULT_SETTINGS.LOV_TEST_ANKRFLOW_FLOW.REBALANCE_AL_FLOOR,
      DEFAULT_SETTINGS.LOV_TEST_ANKRFLOW_FLOW.REBALANCE_AL_CEILING
    )
  );
  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.MANAGER.setSwapper(
      ADDRS.SWAPPERS.DIRECT_SWAPPER
    )
  );

  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.MANAGER.setFeeConfig(
      DEFAULT_SETTINGS.LOV_TEST_ANKRFLOW_FLOW.MIN_DEPOSIT_FEE_BPS,
      DEFAULT_SETTINGS.LOV_TEST_ANKRFLOW_FLOW.MIN_EXIT_FEE_BPS,
      DEFAULT_SETTINGS.LOV_TEST_ANKRFLOW_FLOW.FEE_LEVERAGE_FACTOR
    )
  );

  await mine(
    INSTANCES.LOV_TEST_ANKRFLOW_FLOW.TOKEN.setManager(
      ADDRS.LOV_TEST_ANKRFLOW_FLOW.MANAGER
    )
  );

  await mine(INSTANCES.LOV_TEST_ANKRFLOW_FLOW.MANAGER.setAllowAll(true));

  if (network.name === "localhost") {
    await setupPricesTestnet(owner);
  } else {
    await setupPrices();
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
