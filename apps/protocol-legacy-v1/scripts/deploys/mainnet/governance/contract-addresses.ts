import { network } from "hardhat";

export interface GovernanceDeployedContracts {
    ORIGAMI: {
        MULTISIG: string,
        GOV_TIMELOCK: string,
    },
};

const GOV_DEPLOYED_CONTRACTS: {[key: string]: GovernanceDeployedContracts} = {
    mainnet: {
        ORIGAMI: {
            MULTISIG: '',
            GOV_TIMELOCK: '',
        },
    },
    localhost: {
        ORIGAMI: {
            MULTISIG: '0xA7F0F04efB55eaEfBC4649C523F7a773f91D5526',
            GOV_TIMELOCK: '0xD2D5e508C82EFc205cAFA4Ad969a4395Babce026',
        },
    },
}

export function getDeployedContracts(): GovernanceDeployedContracts {
    if (GOV_DEPLOYED_CONTRACTS[network.name] === undefined) {
      console.log(`No contracts configured for ${network.name}`);
      throw new Error(`No contracts configured for ${network.name}`);
    } else {
      return GOV_DEPLOYED_CONTRACTS[network.name];
    }
}
