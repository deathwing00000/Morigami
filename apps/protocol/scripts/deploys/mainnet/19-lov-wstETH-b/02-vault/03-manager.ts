import '@nomiclabs/hardhat-ethers';
import { ethers } from 'hardhat';
import { MorigamiLovTokenFlashAndBorrowManager__factory } from '../../../../../typechain';
import {
  deployAndMine,
  ensureExpectedEnvvars,
} from '../../../helpers';
import { getDeployedContracts1 } from '../../contract-addresses';

async function main() {
  ensureExpectedEnvvars();
  const [owner] = await ethers.getSigners();
  const ADDRS = await getDeployedContracts1(__dirname);

  const factory = new MorigamiLovTokenFlashAndBorrowManager__factory(owner);
  await deployAndMine(
    'LOV_WSTETH_B.MANAGER',
    factory,
    factory.deploy,
    await owner.getAddress(),
    ADDRS.EXTERNAL.LIDO.WSTETH_TOKEN,
    ADDRS.EXTERNAL.WETH_TOKEN,
    ADDRS.EXTERNAL.LIDO.STETH_TOKEN,
    ADDRS.LOV_WSTETH_B.TOKEN,
    ADDRS.FLASHLOAN_PROVIDERS.SPARK,
    ADDRS.LOV_WSTETH_B.SPARK_BORROW_LEND
  );
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });