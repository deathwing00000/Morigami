import '@nomiclabs/hardhat-ethers';
import { ethers } from 'hardhat';
import { MorigamiLovToken__factory } from '../../../../../typechain';
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

  const factory = new MorigamiLovToken__factory(owner);
  await deployAndMine(
    'LOV_DSR.LOV_DSR_TOKEN',
    factory,
    factory.deploy,
    await owner.getAddress(),
    "Morigami lov-DSR-10x",
    "lov-DSR-10x",
    DEFAULT_SETTINGS.LOV_DSR.LOV_DSR_PERFORMANCE_FEE_BPS,
    ADDRS.CORE.FEE_COLLECTOR,
    ADDRS.CORE.TOKEN_PRICES,
    DEFAULT_SETTINGS.LOV_DSR.INITIAL_MAX_TOTAL_SUPPLY,
  );
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });