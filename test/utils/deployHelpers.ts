import { ethers } from "hardhat";

export const parse = ethers.utils.parseUnits;
export const format = ethers.utils.formatUnits;

//Prices of tokens in USD
export const SELF_PRICE = 0.01175;
export const USDT_PRICE = 1;
export const BTC_PRICE = 25964.5;
export const ETH_PRICE = 1637.17;

export const ZERO_ADDRESS = ethers.constants.AddressZero;

const deployToken = async (name: string, symbol: string, decimals: number) => {
  const TokenFactory = await ethers.getContractFactory("HelperToken");
  return await TokenFactory.deploy(name, symbol, decimals);
};

const deployNft = async (tokenAddress: string) => {
  const NftFactory = await ethers.getContractFactory("SelfNft");
  const nft = await NftFactory.deploy(tokenAddress);
  return nft;
};

const deployAddon = async (tokenAddress: string, nftAddress: string) => {
  const AddonFactory = await ethers.getContractFactory("SelfNftAddon");
  return await AddonFactory.deploy(tokenAddress, nftAddress);
};

const deployPricefeedMock = async () => {
  const PricefeedMockFactory = await ethers.getContractFactory(
    "ChainlinkPricefeedMock"
  );
  return await PricefeedMockFactory.deploy();
};

const deployAddonMock = async (tokenAddress: string, nftAddress: string) => {
  const AddonMockFactory = await ethers.getContractFactory("SelfNftAddonMock");
  return await AddonMockFactory.deploy(tokenAddress, nftAddress);
};

export const deployAddonSuite = async () => {
  const [owner, otherAccount, otherAccount1, otherAccount2] =
    await ethers.getSigners();

  const selfToken = await deployToken("Self Identity", "$SELF", 18);
  const usdt = await deployToken("Tether USD", "USDT", 6);
  const btc = await deployToken("Bitcoin", "BTC", 8);
  const eth = await deployToken("Ethereum", "ETH", 18);

  const selfNft = await deployNft(selfToken.address);
  await selfNft.setPrice(5, 4000000000);
  await selfNft.setPrice(6, 2000000000);
  await selfNft.setPrice(7, 1000000000);
  await selfNft.setPrice(8, 500000000);

  const addon = await deployAddon(selfToken.address, selfNft.address);

  const addonMock = await deployAddonMock(selfToken.address, selfNft.address);

  const usdtPricefeedMock = await deployPricefeedMock();
  const btcPricefeedMock = await deployPricefeedMock();
  const ethPricefeedMock = await deployPricefeedMock();

  await addon.addChainlinkPricefeed(usdt.address, usdtPricefeedMock.address, 6);
  await addon.addChainlinkPricefeed(btc.address, btcPricefeedMock.address, 8);
  await addon.addChainlinkPricefeed(eth.address, ethPricefeedMock.address, 18);

  await selfToken.approve(addon.address, parse("1000000", 18));
  await addon.depositSelfTokens(parse("1000000", 18));
  await addon.approveSelfTokens(parse("1000000", 18));
  await addon.setSelfPrice(parse(SELF_PRICE.toString(), 18));

  //////////////////

  await addonMock.addChainlinkPricefeed(
    usdt.address,
    usdtPricefeedMock.address,
    6
  );
  await addonMock.addChainlinkPricefeed(
    btc.address,
    btcPricefeedMock.address,
    8
  );
  await addonMock.addChainlinkPricefeed(
    eth.address,
    ethPricefeedMock.address,
    18
  );

  await selfToken.approve(addonMock.address, parse("1000000", 18));
  await addonMock.depositSelfTokens(parse("1000000", 18));
  await addonMock.approveSelfTokens(parse("1000000", 18));
  await addonMock.setSelfPrice(parse(SELF_PRICE.toString(), 18));

  await usdtPricefeedMock.setPrice(parse(USDT_PRICE.toString(), 8));
  await btcPricefeedMock.setPrice(parse(BTC_PRICE.toString(), 8));
  await ethPricefeedMock.setPrice(parse(ETH_PRICE.toString(), 8));

  return {
    selfToken,
    usdt,
    btc,
    eth,
    selfNft,
    addon,
    addonMock,
    usdtPricefeedMock,
    btcPricefeedMock,
    ethPricefeedMock,
    owner,
    otherAccount,
    otherAccount1,
    otherAccount2,
  };
};
