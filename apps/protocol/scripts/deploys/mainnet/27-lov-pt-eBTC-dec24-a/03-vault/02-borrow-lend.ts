import '@nomiclabs/hardhat-ethers';
import { ethers } from 'hardhat';
import {
  deployAndMine,
  ensureExpectedEnvvars,
} from '../../../helpers';
import { getDeployedContracts1, connectToContracts1 } from '../../contract-addresses';
import { DEFAULT_SETTINGS } from '../../default-settings';
import { MorigamiAaveV3BorrowAndLend__factory } from '../../../../../typechain';

async function main() {
  ensureExpectedEnvvars();
  const [owner] = await ethers.getSigners();
  const ADDRS = await getDeployedContracts1(__dirname);
  const INSTANCES = connectToContracts1(owner, ADDRS);

  const factory = new MorigamiAaveV3BorrowAndLend__factory(owner);
  await deployAndMine(
    'LOV_PT_EBTC_DEC24_A.ZEROLEND_BORROW_LEND',
    factory,
    factory.deploy,
    await owner.getAddress(),
    ADDRS.EXTERNAL.PENDLE.EBTC_DEC24.PT_TOKEN,
    ADDRS.EXTERNAL.ETHERFI.EBTC_TOKEN,
    await INSTANCES.EXTERNAL.ZEROLEND.MAINNET_BTC_POOL_ADDRESS_PROVIDER.getPool(),
    DEFAULT_SETTINGS.EXTERNAL.ZEROLEND.EMODES.DEFAULT,
  );
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });