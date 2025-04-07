import '@nomiclabs/hardhat-ethers';
import { ethers } from 'hardhat';
import {
  ensureExpectedEnvvars,
  mine,
  ZERO_ADDRESS,
} from '../../../helpers';
import { ContractInstances, connectToContracts1, getDeployedContracts1 } from '../../contract-addresses';
import { DEFAULT_SETTINGS } from '../../default-settings';
import { ContractAddresses } from '../../contract-addresses/types';

let ADDRS: ContractAddresses;
let INSTANCES: ContractInstances;

async function sdaiToSusde_minBuyAmount() {
  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.removeOrderConfig(ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN)
  );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.setOrderConfig(
      ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN,
      {
        maxSellAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_MIN_BUY_AMOUNT.MAX_SELL_AMOUNT,
        buyToken: ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN,
        minBuyAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_MIN_BUY_AMOUNT.MIN_BUY_AMOUNT,
        limitPriceOracle: ZERO_ADDRESS,
        roundDownDivisor: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_MIN_BUY_AMOUNT.ROUND_DOWN_DIVISOR,
        partiallyFillable: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_MIN_BUY_AMOUNT.PARTIALLY_FILLABLE,
        useCurrentBalanceForSellAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_MIN_BUY_AMOUNT.USE_CURRENT_BALANCE_FOR_SELL_AMOUNT,
        limitPricePremiumBps: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_MIN_BUY_AMOUNT.LIMIT_PRICE_PREMIUM_BPS,
        verifySlippageBps: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_MIN_BUY_AMOUNT.VERIFY_SLIPPAGE_BPS,
        expiryPeriodSecs: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_MIN_BUY_AMOUNT.EXPIRY_PERIOD_SECS,
        recipient: ADDRS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2,
        appData: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_MIN_BUY_AMOUNT.APP_DATA,
      }
    )
  );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.setCowApproval(
      ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN, 
      ethers.utils.parseEther("1000"),
    )
  );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.createConditionalOrder(ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN)
  );
}

async function sdaiToSusde_exactSellAmount() {
  // await mine(
  //   INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.removeOrderConfig(ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN)
  // );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.setOrderConfig(
      ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN,
      {
        maxSellAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_EXACT_SELL_AMOUNT.MAX_SELL_AMOUNT,
        buyToken: ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN,
        minBuyAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_EXACT_SELL_AMOUNT.MIN_BUY_AMOUNT,
        limitPriceOracle: ZERO_ADDRESS,
        roundDownDivisor: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_EXACT_SELL_AMOUNT.ROUND_DOWN_DIVISOR,
        partiallyFillable: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_EXACT_SELL_AMOUNT.PARTIALLY_FILLABLE,
        useCurrentBalanceForSellAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_EXACT_SELL_AMOUNT.USE_CURRENT_BALANCE_FOR_SELL_AMOUNT,
        limitPricePremiumBps: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_EXACT_SELL_AMOUNT.LIMIT_PRICE_PREMIUM_BPS,
        verifySlippageBps: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_EXACT_SELL_AMOUNT.VERIFY_SLIPPAGE_BPS,
        expiryPeriodSecs: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_EXACT_SELL_AMOUNT.EXPIRY_PERIOD_SECS,
        recipient: ADDRS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2,
        appData: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SDAI_SUSDE_EXACT_SELL_AMOUNT.APP_DATA,
      }
    )
  );

  // await mine(
  //   INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.setCowApproval(
  //     ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN, 
  //     ethers.utils.parseEther("1000"),
  //   )
  // );

  // await mine(
  //   INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.createConditionalOrder(ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN)
  // );
}

async function susdeToSdai_exactSellAmount() {

  // await mine(
  //   INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.removeOrderConfig(ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN)
  // );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.setOrderConfig(
      ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN,
      {
        maxSellAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_EXACT_SELL_AMOUNT.MAX_SELL_AMOUNT,
        buyToken: ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN,
        minBuyAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_EXACT_SELL_AMOUNT.MIN_BUY_AMOUNT,
        limitPriceOracle: ZERO_ADDRESS,
        roundDownDivisor: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_EXACT_SELL_AMOUNT.ROUND_DOWN_DIVISOR,
        partiallyFillable: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_EXACT_SELL_AMOUNT.PARTIALLY_FILLABLE,
        useCurrentBalanceForSellAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_EXACT_SELL_AMOUNT.USE_CURRENT_BALANCE_FOR_SELL_AMOUNT,
        limitPricePremiumBps: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_EXACT_SELL_AMOUNT.LIMIT_PRICE_PREMIUM_BPS,
        verifySlippageBps: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_EXACT_SELL_AMOUNT.VERIFY_SLIPPAGE_BPS,
        expiryPeriodSecs: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_EXACT_SELL_AMOUNT.EXPIRY_PERIOD_SECS,
        recipient: ADDRS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2,
        appData: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_EXACT_SELL_AMOUNT.APP_DATA,
      }
    ),
  );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.setCowApproval(
      ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN,
      ethers.utils.parseEther("1000"),
    )
  );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.createConditionalOrder(
      ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN
    )
  );

  // await mine(
  //   INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.updateAmountsAndPremiumBps(
  //     ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN,
  //     DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI.MAX_SELL_AMOUNT,
  //     DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI.MIN_BUY_AMOUNT,
  //     DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI.LIMIT_PRICE_PREMIUM_BPS,
  //   )
  // );
}

async function susdeToSdai_minBuyAmount() {

  // await mine(
  //   INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.removeOrderConfig(ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN)
  // );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.setOrderConfig(
      ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN,
      {
        maxSellAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_MIN_BUY_AMOUNT.MAX_SELL_AMOUNT,
        buyToken: ADDRS.EXTERNAL.MAKER_DAO.SDAI_TOKEN,
        minBuyAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_MIN_BUY_AMOUNT.MIN_BUY_AMOUNT,
        limitPriceOracle: ZERO_ADDRESS,
        roundDownDivisor: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_MIN_BUY_AMOUNT.ROUND_DOWN_DIVISOR,
        partiallyFillable: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_MIN_BUY_AMOUNT.PARTIALLY_FILLABLE,
        useCurrentBalanceForSellAmount: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_MIN_BUY_AMOUNT.USE_CURRENT_BALANCE_FOR_SELL_AMOUNT,
        limitPricePremiumBps: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_MIN_BUY_AMOUNT.LIMIT_PRICE_PREMIUM_BPS,
        verifySlippageBps: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_MIN_BUY_AMOUNT.VERIFY_SLIPPAGE_BPS,
        expiryPeriodSecs: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_MIN_BUY_AMOUNT.EXPIRY_PERIOD_SECS,
        recipient: ADDRS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2,
        appData: DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI_MIN_BUY_AMOUNT.APP_DATA,
      }
    )
  );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.setCowApproval(
      ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN,
      ethers.utils.parseEther("1000"),
    )
  );

  await mine(
    INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.createConditionalOrder(
      ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN
    )
  );

  // await mine(
  //   INSTANCES.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.updateAmountsAndPremiumBps(
  //     ADDRS.EXTERNAL.ETHENA.SUSDE_TOKEN,
  //     DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI.MAX_SELL_AMOUNT,
  //     DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI.MIN_BUY_AMOUNT,
  //     DEFAULT_SETTINGS.MAINNET_TEST.SWAPPERS.COW_SWAPPER_2.SUSDE_SDAI.LIMIT_PRICE_PREMIUM_BPS,
  //   )
  // );
}

async function main() {
  ensureExpectedEnvvars();
  
  const [owner] = await ethers.getSigners();
  ADDRS = await getDeployedContracts1(__dirname);
  INSTANCES = connectToContracts1(owner, ADDRS);

  // await sdaiToSusde_minBuyAmount();
  // await sdaiToSusde_exactSellAmount();
  // await susdeToSdai_minBuyAmount();
  await susdeToSdai_exactSellAmount();
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });