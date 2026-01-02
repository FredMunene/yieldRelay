import type { Abi } from 'viem';

export const routerAbi = [
  {
    type: 'function',
    name: 'getPrograms',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      {
        type: 'tuple[]',
        components: [
          { name: 'recipient', type: 'address' },
          { name: 'bps', type: 'uint16' },
          { name: 'metadataURI', type: 'string' },
          { name: 'active', type: 'bool' },
        ],
      },
    ],
  },
  {
    type: 'function',
    name: 'setAllocations',
    stateMutability: 'nonpayable',
    inputs: [
      {
        name: 'bpsList',
        type: 'uint16[]',
      },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'route',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
] as const satisfies Abi;
