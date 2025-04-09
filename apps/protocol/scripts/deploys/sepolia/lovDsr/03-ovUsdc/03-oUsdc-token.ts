import '@nomiclabs/hardhat-ethers';
import { ethers } from 'hardhat';
import { MorigamiOToken__factory } from '../../../../../typechain';
import {
  deployAndMine,
  ensureExpectedEnvvars,
} from '../../../helpers';

async function main() {
  ensureExpectedEnvvars();
  const [owner] = await ethers.getSigners();

  const factory = new MorigamiOToken__factory(owner);
  await deployAndMine(
    'OV_USDC.TOKENS.O_USDC_TOKEN',
    factory,
    factory.deploy,
    await owner.getAddress(),
    "Morigami USDC Token",
    "oUSDC",
  );
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });