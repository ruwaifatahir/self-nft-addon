import { HelperToken, SelfNft, SelfNftAddon } from "../../typechain-types";
import { format } from "./deployHelpers";

export async function calculateNamePrice(
  selfNft: SelfNft,
  name: any,
  selfPrice: number,
  payTknPrice: number
): Promise<string> {
  const namePrice: number = Number(format(await selfNft.getPrice(name), 6));
  return ((namePrice * selfPrice) / payTknPrice).toFixed(10);
}

export async function getTotalCollected(
  addon: SelfNftAddon,
  usdt: HelperToken
) {
  return (await addon.chainlinkPriceFeeds(usdt.address)).collectedTokens;
}
