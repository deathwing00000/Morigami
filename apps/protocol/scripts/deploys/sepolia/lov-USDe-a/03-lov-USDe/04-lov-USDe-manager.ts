import '@nomiclabs/hardhat-ethers';
import { ethers } from 'hardhat';
import { MorigamiLovTokenMorphoManager__factory } from '../../../../../typechain';
import {
  deployAndMine,
  ensureExpectedEnvvars,
} from '../../../helpers';
import { getDeployedContracts } from '../contract-addresses';

async function main() {
  ensureExpectedEnvvars();
  const [owner] = await ethers.getSigners();
  const ADDRS = getDeployedContracts();

  const factory = new MorigamiLovTokenMorphoManager__factory(owner);
  await deployAndMine(
    'LOV_USDE.MANAGER',
    factory,
    factory.deploy,
    await owner.getAddress(),
    ADDRS.EXTERNAL.ETHENA.USDE_TOKEN,
    ADDRS.EXTERNAL.MAKER_DAO.DAI_TOKEN,
    ADDRS.EXTERNAL.ETHENA.USDE_TOKEN,
    ADDRS.LOV_USDE.TOKEN,
    ADDRS.LOV_USDE.MORPHO_BORROW_LEND,
  );
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });