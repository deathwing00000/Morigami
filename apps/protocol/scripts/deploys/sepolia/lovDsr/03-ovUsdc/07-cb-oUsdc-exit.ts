import '@nomiclabs/hardhat-ethers';
import { ethers } from 'hardhat';
import { MorigamiCircuitBreakerAllUsersPerPeriod__factory } from '../../../../../typechain';
import {
  deployAndMine,
  ensureExpectedEnvvars,
} from '../../../helpers';
import { getDeployedContracts } from '../contract-addresses';
import { DEFAULT_SETTINGS } from '../default-settings';

async function main() {
  ensureExpectedEnvvars();
  const [owner] = await ethers.getSigners();
  const ADDRS = getDeployedContracts();

  const factory = new MorigamiCircuitBreakerAllUsersPerPeriod__factory(owner);
  await deployAndMine(
    'OV_USDC.BORROW.CIRCUIT_BREAKER_OUSDC_EXIT',
    factory,
    factory.deploy,
    await owner.getAddress(),
    ADDRS.CORE.CIRCUIT_BREAKER_PROXY,
    26 * 60 * 60, // 26 hours
    13, // 13 periods
    DEFAULT_SETTINGS.OV_USDC.CB_DAILY_OUSDC_EXIT_LIMIT,
  );
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });