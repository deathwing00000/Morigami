import '@nomiclabs/hardhat-ethers';
import { ethers } from 'hardhat';
import { MorigamiVolatileChainlinkOracle__factory } from '../../../../../typechain';
import {
	deployAndMine,
	ensureExpectedEnvvars,
} from '../../../helpers';
import { connectToContracts1, getDeployedContracts1 } from '../../contract-addresses';

async function main() {
	ensureExpectedEnvvars();
	const [owner] = await ethers.getSigners();
	const ADDRS = await getDeployedContracts1(__dirname);
	const INSTANCES = connectToContracts1(owner, ADDRS);

	const factory = new MorigamiVolatileChainlinkOracle__factory(owner);
	await deployAndMine(
		'ORACLES.RSWETH_WETH',
		factory,
		factory.deploy,
		{
			description: "rswETH/WETH",
			baseAssetAddress: ADDRS.EXTERNAL.SWELL.RSWETH_TOKEN,
			baseAssetDecimals: await INSTANCES.EXTERNAL.SWELL.RSWETH_TOKEN.decimals(),
			quoteAssetAddress: ADDRS.EXTERNAL.WETH_TOKEN,
			quoteAssetDecimals: await INSTANCES.EXTERNAL.WETH_TOKEN.decimals(),
		},
		ADDRS.EXTERNAL.ORIGAMI_ORACLE_ADAPTERS.RSWETH_ETH_EXCHANGE_RATE,
		0,
		false, // Morigami adapter does not use roundId
		false  // It does not use the lastUpdatedAt
	);
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});