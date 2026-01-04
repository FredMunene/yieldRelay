import type { Address } from 'viem';
import type { Chain } from 'viem/chains';

const DEFAULTS = {
  vault: '0x1a17f849C8287b21be9bA54e8193284F84a05018',
  router: '0x7E81E4697863cAB4FE4C0d820baCbc9e9843e3dD',
  registry: '0x0969C4a04Bb4C5A6C3F015bB24f6E88D4C692842',
  asset: '0x2161f1A296F73702D69eFAA44e466FB2c1C3aB04',
} as const satisfies Record<string, Address>;

const env = import.meta.env;

export const NETWORK = {
  id: 5003,
  name: 'Mantle Sepolia',
  nativeCurrency: { name: 'MNT', symbol: 'MNT', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://rpc.sepolia.mantle.xyz'] },
    public: { http: ['https://rpc.sepolia.mantle.xyz'] },
  },
  blockExplorers: {
    default: { name: 'Mantle Explorer', url: 'https://explorer.sepolia.mantle.xyz' },
  },
} as const satisfies Chain;

export const CONTRACTS = {
  vault: (env.VITE_VAULT_ADDRESS ?? DEFAULTS.vault) as Address,
  router: (env.VITE_ROUTER_ADDRESS ?? DEFAULTS.router) as Address,
  registry: (env.VITE_REGISTRY_ADDRESS ?? DEFAULTS.registry) as Address,
  asset: (env.VITE_ASSET_ADDRESS ?? DEFAULTS.asset) as Address,
};

export const DISPLAY_APY = Number(env.VITE_DISPLAY_APY ?? 5);

export const PROGRAM_METADATA: Record<string, { title: string; description: string }> = {
  'ipfs://program0': {
    title: 'Public Goods Grants',
    description: 'Supports open-source builders and community-first public goods.',
  },
  'ipfs://program1': {
    title: 'Builder Round',
    description: 'Fuel early teams experimenting with new YieldRelay use cases.',
  },
};

export const BENEFICIARIES = [
  {
    address: (env.VITE_BENEFICIARY_0_ADDR ?? '0x6c550478ced0f3a3451419ceb38d59e885b2178c') as Address,
    metadataURI: 'ipfs://program0',
  },
  {
    address: (env.VITE_BENEFICIARY_1_ADDR ?? '0xF41886af501e2a0958dBD31D9a28AcD6c2f5db06') as Address,
    metadataURI: 'ipfs://program1',
  },
] as const;

export const USD_FORMATTER = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 2,
});
