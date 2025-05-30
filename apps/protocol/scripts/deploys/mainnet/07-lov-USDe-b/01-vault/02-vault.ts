import '@nomiclabs/hardhat-ethers';
import { ethers, network } from 'hardhat';
import { MorigamiLovToken__factory } from '../../../../../typechain';
import {
  deployAndMine,
  ensureExpectedEnvvars,
} from '../../../helpers';
import { getDeployedContracts } from '../../contract-addresses';
import { DEFAULT_SETTINGS } from '../../default-settings';

async function main() {
  ensureExpectedEnvvars();
  const [owner] = await ethers.getSigners();
  const ADDRS = getDeployedContracts();

  const factory = new MorigamiLovToken__factory(owner);
  await deployAndMine(
    'LOV_USDE_B.TOKEN',
    factory,
    factory.deploy,
    await owner.getAddress(),
    DEFAULT_SETTINGS.LOV_USDE_B.TOKEN_NAME,
    DEFAULT_SETTINGS.LOV_USDE_B.TOKEN_SYMBOL,
    DEFAULT_SETTINGS.LOV_USDE_B.PERFORMANCE_FEE_BPS,
    ADDRS.CORE.FEE_COLLECTOR,
    ADDRS.CORE.TOKEN_PRICES.V1,
    network.name === "localhost" ? ethers.utils.parseEther("1000000") : DEFAULT_SETTINGS.LOV_USDE_B.INITIAL_MAX_TOTAL_SUPPLY,
  );
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });