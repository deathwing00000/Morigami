import { ContractAddresses } from "./types";

export const CONTRACTS: ContractAddresses = {
  CORE: {
    MULTISIG: "0xC8419191Cb1A3bF4FfC022D01f857D5AFdeD01ba",
    FEE_COLLECTOR: "0xC8419191Cb1A3bF4FfC022D01f857D5AFdeD01ba",
    TOKEN_PRICES: {
      V1: "0x40eD9824964aefe744A3Ce7E75202F93DFA6B849",
      V2: "0xfC20b8c73263d989A90B927e9a68E06df6C13242",
      V3: "0x43A3cb2cf5eA2331174c166214302f0C3BbA6A85",
    },
  },
  ORACLES: {
    ANKRFLOW_WFLOW: "0x9f5F81820bFa6d42042795424f30A68dEf87D3DC",
    USDE_DAI: "0x39CfDbEfe1e7ccF0665675a3c3f6469b61dD32F5",
    SUSDE_DAI: "0x784f75C39bD7D3EBC377e64991e99178341c831D",
    WEETH_WETH: "0xE0Db69920e90CA56E29F71b7F566655De923c32B",
    EZETH_WETH: "0x28c26e682e26486F311134e5102723c0F1342215",
    STETH_WETH: "0x1B184454E6C02370927789A3564f9D16368d55E4",
    WSTETH_WETH: "0x2848d944EAB78C3ABf02C89fF97f1652A0FBaD77",
    WOETH_WETH: "0x9d492B172eF372c33E63FfD867E7A534DDCd62Fb",
    WETH_DAI: "0xc9A161601B76C0333dCa022efd45b2549396B8b9",
    WBTC_DAI: "0xAeDDad15BE7428D8c53a217Da6e245701e22D2d1",
    WETH_WBTC: "0x000b7163b325e147e33AC728d62FeBAd1d67B83D",
    SDAI_DAI: "0x55f84cD659c0C1A6BC225F5cE9016Ad591B49ceD",
    WETH_SDAI: "0x075766cB4eFcFF684FeCa227C80546F30B8de783",
    WBTC_SDAI: "0xc2D80F4777dA9d3372132E264D014ee4b29e2c62",
    DAI_USD: "0x10400DF986C4E5C295e889b114644b75A5657337",
    PT_SUSDE_OCT24_USDE: "0xF516f47aDD499c82E5552A5894481A216af3aFdd",
    PT_SUSDE_OCT24_DAI: "0x76Bb10FA166a53941634ED26F5dA0E129CC3433c",
    PT_SUSDE_MAR_2025_USDE: "0x2267a91555DC492aeab78999263e09635135b3A7",
    PT_SUSDE_MAR_2025_DAI: "0x669B05610852F5d0Fba3920BB8aD4C4c5C3C3D59",
    PT_SUSDE_MAR_2025_DISCOUNT_TO_MATURITY:
      "0xA2A4359B9ad771B2A1743d1e855c0D4dC0531a2B",
    PT_SUSDE_MAR_2025_DAI_WITH_DISCOUNT_TO_MATURITY:
      "0xc75314d540462bE5B275d45D277775f2E574dd93",
    MKR_DAI: "",
    AAVE_USDC: "0x6a0be5c8e2fef6e965d429E78964b292173e442B",
    SDAI_USDC: "0x690939cf345793BD7950915F84ADbd1AEBCFa9a3",
    USD0pp_USD0: "0xA513991175BB745e7b4a6cfE541c7f6170e476ab",
    USD0pp_USDC: "0x65792959dd27e4eE6bDb3A1Af6d38592Bdb0E81F",
    USD0_USDC: "0x6668daECe8FeB73d186c543fFC162694b847BE99",
    RSWETH_WETH: "0x044002707390DEA875a8f42db89Ea88E7a385297",
    SUSDE_USD_INTERNAL: "0x943F1e9dE4508e9eb6863A10697B26D3678A2A52",
    SDAI_USD_INTERNAL: "0xEc875016b442597d9ad7843B663Cec6c12fEA233",
    SDAI_SUSDE: "0x73DCA51d16711dbE50212c50e80675B60CADb184",
    PT_EBTC_DEC24_EBTC: "0x01Eb1Bb7A8446d674e0cAD9021cA9630Fa5beee2",
    PT_CORN_LBTC_DEC24_LBTC: "0x6ACf4bc24a68CA35FFD2D39DDEC6182FBa2b1b45",
    WETH_CBBTC: "0xE8F39B02d95DD7A9788bec8329a61026c4270Bfc",
  },
  SWAPPERS: {
    DIRECT_SWAPPER: "0xF7B2c7Dc3d3EE437F2AF26C4A491D087679d77Bb",
    SUSDE_SWAPPER: "0x302563254A72B59d71DD5BC209e1e91b7a84E262",
  },
  FLASHLOAN_PROVIDERS: {
    SPARK: "0x88469316c5f828b4Dfd11C4d8529CD9F96b2E006",
    MORE: "0x4DBfCA4E8fe2A7CDa3524D5Abc6b2C248EC63605",

    // Aave charge a 5bps fee on this - so prefer not to use it.
    AAVE_V3_MAINNET_HAS_FEE: "0x89e7D0CDA75F61DbECf466C29338F598e991ae3E",
    MORPHO: "0xC8eE801b35a82743BA7F314623962a2bBfdbC90A",
    ZEROLEND_MAINNET_BTC: "0xd2DB05D0Ba16f3bE2Dd0f6E2dc809403b251464E",
  },
  LOV_TEST_ANKRFLOW_FLOW: {
    OVERLORD_WALLET: "0xC8419191Cb1A3bF4FfC022D01f857D5AFdeD01ba",
    SPARK_BORROW_LEND: "0x65C74046B380a9521b075763B944983B758cFA92",
    TOKEN: "0x87fDa685d17865825474d99d5153b8a17c402bA5",
    MANAGER: "0x2Ef48D580227FF7122592279a82Bd41dE8c3b47f",
  },
  LOV_SUSDE_A: {
    OVERLORD_WALLET: "0xd42c38b2cebb59e77fc985d0cb0d340f15053bcd",
    MORPHO_BORROW_LEND: "0xb48aC9c5585e5F3c88c63CF9bcbAEdC921F76Df2",
    TOKEN: "0x7FC862A47BBCDe3812CA772Ae851d0A9D1619eDa",
    MANAGER: "0x0b53Afe5de9f9df65C3Fe8A9DA81dC410d14d4d4",
  },
  LOV_SUSDE_B: {
    OVERLORD_WALLET: "0xca0678c3a9b1acb50276245ddda06c91ab072fdd",
    MORPHO_BORROW_LEND: "0xEfc8eDaA7cFd0Cf272a0f55de37d62F0ADFb7e93",
    TOKEN: "0xE567DCf433F97d787dF2359bDBF95dFd2B7aBF4E",
    MANAGER: "0x7D7609bF7c3A3c91D524C718FcBfD93398C76603",
  },
  LOV_USDE_A: {
    OVERLORD_WALLET: "0xebf8629d589d5c6ef1ec055c1fa41ecb5c6e5c4f",
    MORPHO_BORROW_LEND: "0x550433C439f92C2f8068b375D8a4ec8d2Dc98299",
    TOKEN: "0xC65a88A7b7752873a3106BD864BBCd717e35d2e5",
    MANAGER: "0x2eC7777838A49E2C83152d455B3CA753c6d08b79",
  },
  LOV_USDE_B: {
    OVERLORD_WALLET: "0xcd745c7eb39472c804db981b1829c99ce0b26ce0",
    MORPHO_BORROW_LEND: "0xC8a26A2ddC176E02A8FD67cB3c8548aA6c8bE32C",
    TOKEN: "0x9fA6D162E32A08B323ADEaE2560F0E44D6dBE53c",
    MANAGER: "0x5383bfABbfCF670cEAC0C7cAd0e5E0a141B23b79",
  },
  LOV_WEETH_A: {
    OVERLORD_WALLET: "0x40557e20e0ffb01849782a09fcb681d5e8d9d229",
    MORPHO_BORROW_LEND: "0xF919e7a09d6c9dC2db9c3DdD9c667ed5949C322c",
    TOKEN: "0x9C1F7237480c030Cb14375Ff6b650606248A5247",
    MANAGER: "0x43947Fe908C9C1F9F64857C2429bF2bb1DD0D111",
  },
  LOV_EZETH_A: {
    OVERLORD_WALLET: "0xd9a1febccb928e6205952a167808d867567d5c92",
    MORPHO_BORROW_LEND: "0xc766e69258408d77967f9a9eB9065B69700D0DeC",
    TOKEN: "0xFbd65E8c1C191F697598307d4E907CDA3CffE33f",
    MANAGER: "0x86142891d70910DceC62c3aBd3c0b5eAD43A02F2",
  },
  LOV_WSTETH_A: {
    OVERLORD_WALLET: "0x46167be270f2b44fbfa8b22d7226c520b943d037",
    TOKEN: "0x117b36e79aDadD8ea81fbc53Bfc9CD33270d845D",
    SPARK_BORROW_LEND: "0x53628BEfA12c80cFdc2C833e0bd13D1014e1985b",
    MANAGER: "0xC9632e9CBdEE643Bc490572DD0750EA394E8e3a9",
  },
  LOV_WSTETH_B: {
    OVERLORD_WALLET: "0x5a03e9a5bfd374a259edfffec6c36c3133174c2c",
    TOKEN: "0xC03C434D8430d27bb16f07658be4352BeAD17eA5",
    SPARK_BORROW_LEND: "0x42Cd294ab9C4ABc787109564e9CDB3Ec73F5D342",
    MANAGER: "0xC1A2499fFb03Ae462242890cb852cC80cB0203cd",
  },
  LOV_WOETH_A: {
    OVERLORD_WALLET: "0x956442579a697f9a502fbbf589d8352536161fa0",
    MORPHO_BORROW_LEND: "0x4e568666DED61D6077EFf8979733cEe4610a5eA2",
    TOKEN: "0xC242487172641eEf13626C2c426CB3d41BebC6DE",
    MANAGER: "0x051dC89b797652CE8E19A9004d10A74EaaBB1Ec3",
  },
  LOV_WETH_DAI_LONG_A: {
    OVERLORD_WALLET: "0x035463e9302d0fb3fdd555e83f642f57f2373550",
    TOKEN: "0x235e2afeAA56497436987E87bb475D04BEFC1394",
    SPARK_BORROW_LEND: "0x2432B4767c6C3B4B5cFf16acea8F51c013DBB678",
    MANAGER: "0xBfa722C4fdf41632A8648C5F1Ae129242b1a9CE6",
  },
  LOV_WETH_SDAI_SHORT_A: {
    OVERLORD_WALLET: "0xa14deecd977ec226334f7bfe224ee9841a4cb725",
    TOKEN: "0xC3979edD2bC308D536964b9515161C8551D0aE3a",
    SPARK_BORROW_LEND: "0xa4361532B9e648dDF9DA3FfF0c283e9761A9D0be",
    MANAGER: "0xd414c46Ac45e14f3171e857e35eC12D8E38598fe",
  },
  LOV_WBTC_DAI_LONG_A: {
    OVERLORD_WALLET: "0x4950e6b586ed6e6762f096a1dc7bcc6f49d69f04",
    TOKEN: "0xA64a28deaff01CFFEd21303D0419CEE67549e407",
    SPARK_BORROW_LEND: "0xDcE5d4F7B729Bb44895E4Ba19b4f3740017c6bDf",
    MANAGER: "0xACDE8c62a1939fBF0F33AC1eb6B3D387c6240a39",
  },
  LOV_WBTC_SDAI_SHORT_A: {
    OVERLORD_WALLET: "0x4910729567c8a65bf3440ab93d9f143d97936020",
    TOKEN: "0xbC882B8A51C75229188B8e1AbFa1100201aCc3A9",
    SPARK_BORROW_LEND: "0x5E4a600Ff58cd9045A3e096E6788d779A68766ec",
    MANAGER: "0x706E9b38fd6dd48ABF1445cc3cff2202977bFb45",
  },
  LOV_WETH_WBTC_LONG_A: {
    OVERLORD_WALLET: "0xb12a09bbee9a895ecd1597485976b9ba1ab38db2",
    TOKEN: "0xd47d334473Ec3e0e2B4bBF60dd41b0E404676362",
    SPARK_BORROW_LEND: "0x16515224648D441140016e3202cAc50855dE167b",
    MANAGER: "0xa1a07863e51d932A71133Bde956f3d3B6D4C21E4",
  },
  LOV_WETH_WBTC_SHORT_A: {
    OVERLORD_WALLET: "0x753254c544ef69d023f29633d1c82e38cb38a7b8",
    TOKEN: "0x24D43755ce2a59C6b31EafD9424f1661eA968dce",
    SPARK_BORROW_LEND: "0x0665B774DE7DFf6c003Cb84F71123EB26CDF1033",
    MANAGER: "0xcF4Bf725898cC787e597332c0C5F0843c3E85CBB",
  },
  LOV_PT_SUSDE_OCT24_A: {
    OVERLORD_WALLET: "0x6f4C6D6f836394BB8c0f46121e963821B8B3a822",
    MORPHO_BORROW_LEND: "0x03401161Fc7785C86ee5Cd96560711A677533e3B",
    TOKEN: "0xb9dad3693AEAc9025Cb24a47AFA6930539877187",
    MANAGER: "0x71578e532f30983aF51981DeeDa0a7bba88da22A",
  },
  LOV_PT_SUSDE_MAR_2025_A: {
    OVERLORD_WALLET: "0x6f4C6D6f836394BB8c0f46121e963821B8B3a822",
    MORPHO_BORROW_LEND: "0x9e0457B5BcD95F4e2fc7FabCC41faAD0D443B4F7",
    TOKEN: "0xDb4f1Bb3f8c9929aaFbe7197e10ffaFEEAe19B9A",
    MANAGER: "0xe581eF672a0698a8cE5E85469e69FEEAebfC3DB3",
  },
  LOV_MKR_DAI_LONG_A: {
    OVERLORD_WALLET: "",
    TOKEN: "",
    SPARK_BORROW_LEND: "",
    MANAGER: "",
  },
  LOV_AAVE_USDC_LONG_A: {
    OVERLORD_WALLET: "0x33776897f75dfe6865ba6ccf4cc049027d29a0c4",
    TOKEN: "0x26DF9465964C2cEF869281c09a10F7Dd7b1321a7",
    SPARK_BORROW_LEND: "0xb26631bc6AFd6483ac4fDCd5F943E8a788352D96",
    MANAGER: "0xED95cf020eCE657a10793488622Ed2f837F1e83c",
  },
  LOV_SDAI_A: {
    OVERLORD_WALLET: "0x39a9e58ae15e70350eeb147d59f9182d4b891e4d",
    MORPHO_BORROW_LEND: "0x415A37462350C7B428D3310629f8B5520e18dDB1",
    TOKEN: "0xdE6d401E4B651F313edB7da0A11e072EEf4Ce7BE",
    MANAGER: "0xc387Db4203d81723367CFf6Bcd14Ad2099A7Fbce",
  },
  LOV_USD0pp_A: {
    OVERLORD_WALLET: "0xfa18305212046966dca26dece54e29354389fa80",
    MORPHO_BORROW_LEND: "0x3963D8D2d7AC114573c1184F4036D9A12FbDEFe6",
    TOKEN: "0x78F3108a8dDf0faaE25862d4008DE3adF129A8e6",
    MANAGER: "0x180f4D73cA3eFfdAa0F582Fd42D9588d14118129",
  },
  LOV_RSWETH_A: {
    OVERLORD_WALLET: "0x7784d68076c829fef27b7a270d1fea070996ec11",
    MORPHO_BORROW_LEND: "0xe6B1F872b1073408a1E619319718E0Bce3E48F17",
    TOKEN: "0x71520ce2DB377AFa999bc6fdc1af896B21b2F26a",
    MANAGER: "0x2f80eE76E44047E3CbB40FC4C0CC2f7f04fA1709",
  },
  LOV_PT_EBTC_DEC24_A: {
    OVERLORD_WALLET: "0xedfb76227c7ea507138952fed9a0cfdfb1f433ef",
    TOKEN: "0xCaB062047F8b3e2CecB27206d8399899eC4ad2eB",
    ZEROLEND_BORROW_LEND: "0x16316604AeabcacCe89481B1946B3b89041B39e2",
    MANAGER: "0x013C5194B3548B1A9D460D6F80bd8D214bAc13e2",
  },
  LOV_PT_CORN_LBTC_DEC24_A: {
    OVERLORD_WALLET: "0x11c6b49ef6224af51bcf5c1accd735347085c48d",
    TOKEN: "0xcA92bccEB7349347bB14bd5748820659e198c632",
    ZEROLEND_BORROW_LEND: "0x8EcA7b9c038C5eD79470366b51860A4B50e75B8c",
    MANAGER: "0x1592ec59f5362d9A095c322de2c3cDab1c9B9c66",
  },
  LOV_WETH_CBBTC_LONG_A: {
    OVERLORD_WALLET: "0xfa5496e089b2d171a01ec822b3a6afd26ce8831e",
    TOKEN: "0x5Ca7539f4a3D0E5006523C1380898898457E927f",
    SPARK_BORROW_LEND: "0xE508C0703647AB7FeB6950dB0cd974e079194cc0",
    MANAGER: "0xC8462C87F7b7446D99C7F1c2F4915A67D711b2aC",
  },

  VAULTS: {
    SUSDSpS: {
      OVERLORD_WALLET: "0xfb8e07a50033b88c219caaa32cc9d4ac92ed6bfe",
      TOKEN: "0x0f90a6962e86b5587b4c11bA2B9697dC3bA84800",
      MANAGER: "0x05654Ff0Cb3635fA5De00CC11607dBf203435C13",
      COW_SWAPPER: "0x80B921C724202969295dCF2DA2B36e9F052315b4",
    },
  },

  EXTERNAL: {
    ANKRFLOW_TOKEN: "0x8E3DC6E937B560ce6a1Aaa78AfC775228969D16c",
    WFLOW_TOKEN: "0xd3bf53dac106a0290b0483ecbc89d40fcc961f3e",
    WETH_TOKEN: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    WBTC_TOKEN: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
    INTERNAL_USD: "0x000000000000000000000000000000000000115d",
    MAKER_DAO: {
      DAI_TOKEN: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
      SDAI_TOKEN: "0x83F20F44975D03b1b09e64809B757c47f942BEeA",
      MKR_TOKEN: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    },
    SKY: {
      USDS_TOKEN: "0xdC035D45d973E3EC169d2276DDab16f1e407384F",
      SUSDS_TOKEN: "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD",
      SKY_TOKEN: "0x56072C95FAA701256059aa122697B133aDEd9279",
      STAKING_FARMS: {
        USDS_SKY: "0x0650CAF159C5A49f711e8169D4336ECB9b950275",
      },
    },
    CIRCLE: {
      USDC_TOKEN: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    },
    ETHENA: {
      USDE_TOKEN: "0x4c9EDD5852cd905f086C759E8383e09bff1E68B3",
      SUSDE_TOKEN: "0x9D39A5DE30e57443BfF2A8307A4256c8797A3497",
    },
    ETHERFI: {
      WEETH_TOKEN: "0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee",
      LIQUIDITY_POOL: "0x308861A430be4cce5502d0A12724771Fc6DaF216",
      EBTC_TOKEN: "0x657e8C867D8B37dCC18fA4Caead9C45EB088C642",
    },
    RENZO: {
      EZETH_TOKEN: "0xbf5495Efe5DB9ce00f80364C8B423567e58d2110",
      RESTAKE_MANAGER: "0x74a09653A083691711cF8215a6ab074BB4e99ef5",
    },
    LIDO: {
      STETH_TOKEN: "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
      WSTETH_TOKEN: "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0",
    },
    ORIGIN: {
      OETH_TOKEN: "0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3",
      WOETH_TOKEN: "0xDcEe70654261AF21C44c093C300eD3Bb97b78192",
    },
    USUAL: {
      USD0pp_TOKEN: "0x35D8949372D46B7a3D5A56006AE77B215fc69bC0",
      USD0_TOKEN: "0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5",
    },
    CURVE: {
      USD0pp_USD0_STABLESWAP_NG: "0x1d08E7adC263CfC70b1BaBe6dC5Bb339c16Eec52",
      USD0_USDC_STABLESWAP_NG: "0x14100f81e33C33Ecc7CDac70181Fb45B6E78569F",
    },
    SWELL: {
      RSWETH_TOKEN: "0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0",
    },
    LOMBARD: {
      LBTC_TOKEN: "0x8236a87084f8B84306f72007F36F2618A5634494",
    },
    COINBASE: {
      CBBTC_TOKEN: "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf",
    },
    REDSTONE: {
      USDE_USD_ORACLE: "0xbC5FBcf58CeAEa19D523aBc76515b9AEFb5cfd58",
      SUSDE_USD_ORACLE: "0xb99D174ED06c83588Af997c8859F93E83dD4733f",
      WEETH_WETH_ORACLE: "0x8751F736E94F6CD167e8C5B97E245680FbD9CC36",
      WEETH_USD_ORACLE: "0xdDb6F90fFb4d3257dd666b69178e5B3c5Bf41136",
      EZETH_WETH_ORACLE: "0xF4a3e183F59D2599ee3DF213ff78b1B3b1923696",
    },
    CHAINLINK: {
      ANKRFLOW_USD_ORACLE: "0xA6204a9Cc18E6CFcf3EB247DBE40d402d8735EB3",
      WFLOW_USD_ORACLE: "0xaCAd8eB605A93b8E0fF993f437f64155FB68D5DD",
      ANKRFLOW_WFLOW_ORACLE: "0x5c4684Da04Bc1bc2deD6d0E0C662102fA946e2Ff",
      DAI_USD_ORACLE: "0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9",
      ETH_USD_ORACLE: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
      BTC_USD_ORACLE: "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c",
      ETH_BTC_ORACLE: "0xAc559F25B1619171CbC396a50854A3240b6A4e99",
      STETH_ETH_ORACLE: "0x86392dC19c0b719886221c78AB11eb8Cf5c52812",
      MKR_USD_ORACLE: "0xec1D1B3b0443256cc3860e24a46F108e699484Aa",
      AAVE_USD_ORACLE: "0x547a514d5e3769680Ce22B2361c10Ea13619e8a9",
      USDC_USD_ORACLE: "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6",
    },
    ORIGAMI_ORACLE_ADAPTERS: {
      RSWETH_ETH_EXCHANGE_RATE: "0xb2b18E668CE6326760e3B063f72684fdF2a2D582",
    },
    SPARK: {
      POOL_ADDRESS_PROVIDER: "0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE",
    },
    AAVE: {
      AAVE_TOKEN: "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9",
      V3_MAINNET_POOL_ADDRESS_PROVIDER:
        "0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e",
      V3_LIDO_POOL_ADDRESS_PROVIDER:
        "0xcfBf336fe147D643B9Cb705648500e101504B16d",
    },
    MORE: {
      V3_POOL_ADDRESS_PROVIDER: "0xEe5C46a2Ed7c985e10852b364472c86B7FDE9488",
    },
    ZEROLEND: {
      MAINNET_BTC_POOL_ADDRESS_PROVIDER:
        "0x17878AFdD5772F4Ec93c265Ac7Ad8E2b29abB857",
    },
    KITTY_PUNCH: {
      ROUTER_V2: "0xeD53235cC3E9d2d464E9c408B95948836648870B",
    },
    MORPHO: {
      SINGLETON: "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb",
      IRM: "0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC",
      ORACLE: {
        SUSDE_DAI: "0x5D916980D5Ae1737a8330Bf24dF812b2911Aae25",
        USDE_DAI: "0xaE4750d0813B5E37A51f7629beedd72AF1f9cA35",
        WEETH_WETH: "0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a",
        EZETH_WETH: "0x61025e2B0122ac8bE4e37365A4003d87ad888Cc3",
        WOETH_WETH: "0xb7948b5bEEe825E609990484A99340D8767B420e",
        PT_SUSDE_OCT24_DAI: "0xaE4750d0813B5E37A51f7629beedd72AF1f9cA35",
        PT_SUSDE_MAR_2025_DAI: "0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7",
        SDAI_USDC: "0xd6361d441EA8Fd285F7cd8b7d406b424e50c5429",
        USD0pp_USDC: "0x1325Eb089Ac14B437E78D5D481e32611F6907eF8",
        RSWETH_WETH: "0x56e2d0957d2376dF4A0519b91D1Fa19D2d63bd9b",
      },
    },
    PENDLE: {
      ORACLE: "0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2",
      ROUTER: "0x888888888889758F76e7103c6CbF23ABbF58F946",
      SUSDE_OCT24: {
        MARKET: "0xbBf399db59A845066aAFce9AE55e68c505FA97B7",
        PT_TOKEN: "0xAE5099C39f023C91d3dd55244CAFB36225B0850E",
      },
      SUSDE_MAR_2025: {
        MARKET: "0xcDd26Eb5EB2Ce0f203a84553853667aE69Ca29Ce",
        PT_TOKEN: "0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81",
        DISCOUNT_TO_MATURITY_ORACLE:
          "0x3fa71e3F2788f85d8c4F9c3a05B038EAf29e7D35",
      },
      EBTC_DEC24: {
        MARKET: "0x36d3ca43ae7939645C306E26603ce16e39A89192",
        PT_TOKEN: "0xB997B3418935A1Df0F914Ee901ec83927c1509A0",
      },
      CORN_LBTC_DEC24: {
        MARKET: "0xCaE62858DB831272A03768f5844cbe1B40bB381f",
        PT_TOKEN: "0x332A8ee60EdFf0a11CF3994b1b846BBC27d3DcD6",
      },
    },
    ONE_INCH: {
      ROUTER_V6: "0x111111125421cA6dc452d289314280a0f8842A65",
    },
    KYBERSWAP: {
      ROUTER_V2: "0x6131B5fae19EA4f9D964eAc0408E4408b66337b5",
    },
    COW_SWAP: {
      VAULT_RELAYER: "0xC92E8bdf79f0507f65a392b0ab4667716BFE0110",
      SETTLEMENT: "0x9008D19f58AAbD9eD0D60971565AA8510560ab41",
    },
  },

  MAINNET_TEST: {
    SWAPPERS: {
      COW_SWAPPER_1: "0xc582c92C4f7E6af76daB4b376Da34DDD3cD3eB41",
      COW_SWAPPER_2: "0xe8F154a43BEBdF9ff6Dc1dc0B09Da94290cCe42e",
    },
  },
};
