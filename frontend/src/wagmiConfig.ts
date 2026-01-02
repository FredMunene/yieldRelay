import { createConfig, http } from 'wagmi';
import { injected, walletConnect } from 'wagmi/connectors';
import { NETWORK } from './config/contracts';

const rpcUrls = NETWORK.rpcUrls as {
  public?: { http?: readonly string[] };
  default: { http?: readonly string[] };
};
const defaultRpc = rpcUrls.public?.http?.[0] ?? rpcUrls.default.http?.[0];
if (!defaultRpc && !import.meta.env.VITE_RPC_URL) {
  console.warn('No RPC URL configured for wagmi; set VITE_RPC_URL in .env');
}
const rpcUrl = import.meta.env.VITE_RPC_URL ?? defaultRpc ?? '';
const walletConnectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID;

const connectors = [
  injected({ target: 'metaMask' }),
  ...(walletConnectId
    ? [
        walletConnect({
          projectId: walletConnectId,
          showQrModal: true,
        }),
      ]
    : []),
];

export const wagmiConfig = createConfig({
  chains: [NETWORK],
  transports: {
    [NETWORK.id]: http(rpcUrl),
  },
  connectors,
});
