import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { NETWORK } from '../config/contracts';

const shortAddress = (address: string) => `${address.slice(0, 6)}…${address.slice(-4)}`;

export function ConnectButton() {
  const { address, status } = useAccount();
  const { connectors, connect } = useConnect();
  const { disconnect } = useDisconnect();

  const primaryConnector = connectors[0];

  if (address) {
    return (
      <button className="btn btn-ghost" onClick={() => disconnect()}>
        {status === 'connecting' ? 'Connecting…' : shortAddress(address)} (Disconnect)
      </button>
    );
  }

  return (
    <button
      className="btn btn-secondary"
      onClick={() => connect({ connector: primaryConnector })}
      disabled={!primaryConnector}
    >
      {primaryConnector ? `Connect ${primaryConnector.name}` : `Connect (${NETWORK.name})`}
    </button>
  );
}
