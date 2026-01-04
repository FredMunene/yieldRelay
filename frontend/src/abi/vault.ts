import type { Abi } from 'viem';

export const vaultAbi = [
  { type: 'function', name: 'totalPrincipal', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'principalOf', stateMutability: 'view', inputs: [{ name: 'depositor', type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'accruedYield', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'pendingYield', stateMutability: 'view', inputs: [{ name: 'depositor', type: 'address' }], outputs: [{ type: 'uint256' }] },
  {
    type: 'function',
    name: 'deposit',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'amount', type: 'uint256' },
      { name: 'beneficiaries', type: 'address[]' },
      { name: 'bps', type: 'uint16[]' },
    ],
    outputs: [],
  },
  { type: 'function', name: 'withdrawPrincipal', stateMutability: 'nonpayable', inputs: [{ name: 'amount', type: 'uint256' }], outputs: [] },
  { type: 'function', name: 'setSplitConfig', stateMutability: 'nonpayable', inputs: [
      { name: 'beneficiaries', type: 'address[]' },
      { name: 'bps', type: 'uint16[]' },
    ], outputs: [] },
  { type: 'function', name: 'allocateYield', stateMutability: 'nonpayable', inputs: [{ name: 'depositor', type: 'address' }], outputs: [] },
] as const satisfies Abi;
