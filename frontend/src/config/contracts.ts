import type { Address } from 'viem';
import { sepolia } from 'viem/chains';

const DEFAULTS = {
  vault: '0xEd74acc3a88c06E1f7b18f8800898d37bf1B217f',
  router: '0xFE7726C0915B14B2584A2407cF3d34496a0d223B',
  strategy: '0xF5DB0574FFa04f79BCbdE87d318B1cC1310acbE9',
  asset: '0x42B031295A44Ca499bB118dfFA7E2f29AFE0C88F',
} as const satisfies Record<string, Address>;

const env = import.meta.env;

export const NETWORK = sepolia;

export const CONTRACTS = {
  vault: (env.VITE_VAULT_ADDRESS ?? DEFAULTS.vault) as Address,
  router: (env.VITE_ROUTER_ADDRESS ?? DEFAULTS.router) as Address,
  strategy: (env.VITE_STRATEGY_ADDRESS ?? DEFAULTS.strategy) as Address,
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
    description: 'Fuel early teams experimenting with new Octant use cases.',
  },
};

export const USD_FORMATTER = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 2,
});
