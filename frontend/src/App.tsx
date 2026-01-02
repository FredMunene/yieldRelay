import { useEffect, useMemo, useState } from 'react';
import {
  useAccount,
  useChainId,
  usePublicClient,
  useReadContract,
  useSwitchChain,
  useWriteContract,
} from 'wagmi';
import { formatUnits, maxUint256, parseUnits } from 'viem';
import { CONTRACTS, DISPLAY_APY, NETWORK, PROGRAM_METADATA } from './config/contracts';
import { vaultAbi } from './abi/vault';
import { routerAbi } from './abi/router';
import { erc20Abi } from './abi/erc20';
import { ConnectButton } from './components/ConnectButton';
import { SimulationModal } from './components/SimulationModal';
import { formatCurrency } from './lib/format';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

type FlowCard = {
  id: string;
  title: string;
  description: string;
  note?: string;
};

type Program = {
  id: number;
  recipient: string;
  bps: number;
  metadataURI: string;
  active: boolean;
};

const flows: FlowCard[] = [
  {
    id: 'deposit',
    title: 'Deposit',
    description:
      'Put treasury assets into a secure ERC-4626 vault. Your principal stays safe while Octant Mini prepares it to generate yield.',
  },
  {
    id: 'generate',
    title: 'Generate',
    description: 'Your vault automatically earns yield through diversified, low-risk DeFi strategies.',
    note: 'No manual management required.',
  },
  {
    id: 'route',
    title: 'Route',
    description: 'The Dragon Router sends a portion of your yield directly to programs you choose.',
    note: "Always aligned with your ecosystem's priorities.",
  },
];

const iconMap: Record<string, JSX.Element> = {
  deposit: (
    <svg viewBox="0 0 40 40" role="img" aria-hidden>
      <path
        d="M20 6v28M10 24l10 10 10-10"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  ),
  generate: (
    <svg viewBox="0 0 40 40" role="img" aria-hidden>
      <path
        d="M11 14c1.5-4 5.5-7 9.9-7 6.7 0 12.1 5.4 12.1 12.1 0 6.7-5.4 12.1-12.1 12.1-4.4 0-8.4-3-9.9-7"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.4"
        strokeLinecap="round"
      />
      <path
        d="M20 11v9l6 3"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  ),
  route: (
    <svg viewBox="0 0 40 40" role="img" aria-hidden>
      <path
        d="M12 10h8c5 0 8 3 8 8v12"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.4"
        strokeLinecap="round"
      />
      <path
        d="M28 30l-4-4 4-4"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="12" cy="10" r="3" fill="currentColor" />
    </svg>
  ),
};

const yieldSources = ['Lido', 'Aave', 'Rocket Pool'];

const placeholderLandingVaults = [
  {
    id: 'stable',
    name: 'Dragon Vault Stable',
    variant: 'stable' as const,
    principal: '$ 12.1m',
    apy: '5.0%',
    topFundedLabel: 'Top Funded Genre',
    topFundedValue: 'Public Goods Grants',
  },
  {
    id: 'experimental',
    name: 'Dragon Vault Experimental',
    variant: 'experimental' as const,
    principal: '$ 12.1m',
    apy: '5.0%',
    topFundedLabel: 'Top Funded Program',
    topFundedValue: 'Public Goods Grants',
    action: 'View Routing',
  },
];

const bnToNumber = (value?: bigint, decimals = 18) => {
  if (!value) return 0;
  return Number(formatUnits(value, decimals));
};

const programTitle = (program: Program) =>
  PROGRAM_METADATA[program.metadataURI]?.title ?? `Program #${program.id + 1}`;

const programDescription = (program: Program) =>
  PROGRAM_METADATA[program.metadataURI]?.description ?? 'Active ecosystem recipient';

function App() {
  const renderVaultLabel = (name: string) => name.split(' ').pop() ?? '';
  const [view, setView] = useState<'landing' | 'demo'>('landing');
  const [showSimulation, setShowSimulation] = useState(false);
  const [depositAmount, setDepositAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [feedback, setFeedback] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState<string | null>(null);
  const [allocationDraft, setAllocationDraft] = useState<number[]>([]);

  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { switchChainAsync } = useSwitchChain();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();

  const decimalsQuery = useReadContract({
    address: CONTRACTS.asset,
    abi: erc20Abi,
    functionName: 'decimals',
  });
  const assetDecimals = Number(decimalsQuery.data ?? 18);

  const assetSymbolQuery = useReadContract({
    address: CONTRACTS.asset,
    abi: erc20Abi,
    functionName: 'symbol',
  });
  const assetSymbol = assetSymbolQuery.data ?? 'TOKEN';

  const totalAssetsQuery = useReadContract({
    address: CONTRACTS.vault,
    abi: vaultAbi,
    functionName: 'totalAssets',
    query: { refetchInterval: 15000 },
  });
  const managedAssetsQuery = useReadContract({
    address: CONTRACTS.vault,
    abi: vaultAbi,
    functionName: 'managedAssets',
    query: { refetchInterval: 15000 },
  });
  const availableLiquidityQuery = useReadContract({
    address: CONTRACTS.vault,
    abi: vaultAbi,
    functionName: 'availableLiquidity',
    query: { refetchInterval: 15000 },
  });
  const totalSupplyQuery = useReadContract({
    address: CONTRACTS.vault,
    abi: vaultAbi,
    functionName: 'totalSupply',
  });
  const routerBalanceQuery = useReadContract({
    address: CONTRACTS.asset,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [CONTRACTS.router],
    query: { refetchInterval: 15000 },
  });
  const walletBalanceQuery = useReadContract({
    address: CONTRACTS.asset,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address ?? ZERO_ADDRESS],
    query: { enabled: Boolean(address), refetchInterval: 15000 },
  });
  const allowanceQuery = useReadContract({
    address: CONTRACTS.asset,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address ?? ZERO_ADDRESS, CONTRACTS.vault],
    query: { enabled: Boolean(address), refetchInterval: 15000 },
  });
  const userSharesQuery = useReadContract({
    address: CONTRACTS.vault,
    abi: vaultAbi,
    functionName: 'balanceOf',
    args: [address ?? ZERO_ADDRESS],
    query: { enabled: Boolean(address), refetchInterval: 15000 },
  });
  const programsQuery = useReadContract({
    address: CONTRACTS.router,
    abi: routerAbi,
    functionName: 'getPrograms',
    query: { refetchInterval: 20000 },
  });

  const programs: Program[] = useMemo(() => {
    if (!programsQuery.data) return [];
    return programsQuery.data.map((program, idx) => {
      const item = program as {
        recipient: `0x${string}`;
        bps: number;
        metadataURI: string;
        active: boolean;
      };
      return {
        id: idx,
        recipient: item.recipient,
        bps: Number(item.bps ?? 0),
        metadataURI: item.metadataURI ?? '',
        active: Boolean(item.active),
      };
    });
  }, [programsQuery.data]);

  useEffect(() => {
    if (!programs.length) return;
    setAllocationDraft((prev) => {
      const next = programs.map((program) => program.bps / 100);
      if (
        prev.length !== next.length ||
        prev.some((value, idx) => Math.round(value * 100) !== programs[idx].bps)
      ) {
        return next;
      }
      return prev;
    });
  }, [programs]);

  const tvl = bnToNumber(totalAssetsQuery.data, assetDecimals);
  const managedAssetsValue = bnToNumber(managedAssetsQuery.data, assetDecimals);
  const availableLiquidityValue = bnToNumber(availableLiquidityQuery.data, assetDecimals);
  const routerBalanceValue = bnToNumber(routerBalanceQuery.data, assetDecimals);
  const walletBalanceValue = isConnected ? bnToNumber(walletBalanceQuery.data, assetDecimals) : 0;
  const allowanceValue = allowanceQuery.data ?? 0n;
  const totalSupply = totalSupplyQuery.data ?? 0n;
  const userShares = userSharesQuery.data ?? 0n;

  const userShareValue = useMemo(() => {
    if (!userShares || !totalAssetsQuery.data || totalSupply === 0n) return 0;
    const value = (userShares * totalAssetsQuery.data) / totalSupply;
    return bnToNumber(value, assetDecimals);
  }, [userShares, totalAssetsQuery.data, totalSupply, assetDecimals]);

  const projectedMonthlyYield = tvl * (DISPLAY_APY / 100) / 12;

  const depositAmountUnits = useMemo(() => {
    if (!depositAmount) return null;
    try {
      return parseUnits(depositAmount, assetDecimals);
    } catch {
      return null;
    }
  }, [depositAmount, assetDecimals]);

  const withdrawAmountUnits = useMemo(() => {
    if (!withdrawAmount) return null;
    try {
      return parseUnits(withdrawAmount, assetDecimals);
    } catch {
      return null;
    }
  }, [withdrawAmount, assetDecimals]);

  const needsApproval = Boolean(
    depositAmountUnits && allowanceQuery.data !== undefined && allowanceValue < depositAmountUnits,
  );

  const allocationSum = allocationDraft.reduce((acc, value) => acc + value, 0);
  const allocationsMatchOnChain =
    allocationDraft.length === programs.length &&
    allocationDraft.every(
      (percent, idx) => Math.round(percent * 100) === (programs[idx]?.bps ?? 0),
    );

  const impactPrograms = programs
    .filter((program) => program.active && program.bps > 0)
    .map((program) => {
      const percent = program.bps / 100;
      const queuedAmount = routerBalanceValue * (program.bps / 10_000);
      return {
        id: program.id,
        title: programTitle(program),
        percent,
        amount: queuedAmount,
        description: programDescription(program),
      };
    });

  const simulationPrograms = (programs.length ? programs : [
    { id: 0, recipient: ZERO_ADDRESS, bps: 5000, metadataURI: 'ipfs://program0', active: true },
    { id: 1, recipient: ZERO_ADDRESS, bps: 5000, metadataURI: 'ipfs://program1', active: true },
  ]).map((program) => ({
    id: program.id,
    title: programTitle(program),
    percent: program.bps / 100,
    amount: projectedMonthlyYield * (program.bps / 10_000),
    description: programDescription(program),
  }));

  const allocationDisplay = programs.length
    ? programs.map((program) => ({
        id: `program-${program.id}`,
        label: programTitle(program),
        value: `${(program.bps / 100).toFixed(1)}%`,
      }))
    : placeholderLandingVaults.map((vault) => ({
        id: vault.id,
        label: vault.name,
        value: vault.apy,
      }));

  const refetchAll = async () => {
    await Promise.all([
      totalAssetsQuery.refetch?.(),
      managedAssetsQuery.refetch?.(),
      availableLiquidityQuery.refetch?.(),
      routerBalanceQuery.refetch?.(),
      walletBalanceQuery.refetch?.(),
      allowanceQuery.refetch?.(),
      userSharesQuery.refetch?.(),
      programsQuery.refetch?.(),
    ]);
  };

  const ensureWalletReady = async () => {
    if (!address) throw new Error('Connect wallet to continue');
    if (chainId !== NETWORK.id && switchChainAsync) {
      await switchChainAsync({ chainId: NETWORK.id });
    }
  };

  const runTransaction = async (label: string, action: () => Promise<`0x${string}`>) => {
    try {
      setPendingAction(label);
      setFeedback(null);
      await ensureWalletReady();
      const hash = await action();
      if (publicClient) {
        await publicClient.waitForTransactionReceipt({ hash });
      }
      await refetchAll();
      setFeedback(`${label} confirmed`);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Transaction failed';
      setFeedback(message);
    } finally {
      setPendingAction(null);
    }
  };

  const handleApprove = async () => {
    if (!depositAmountUnits) return;
    await runTransaction('Allowance updated', () =>
      writeContractAsync({
        address: CONTRACTS.asset,
        abi: erc20Abi,
        functionName: 'approve',
        args: [CONTRACTS.vault, maxUint256],
      }),
    );
  };

  const handleDeposit = async () => {
    if (!depositAmountUnits || depositAmountUnits <= 0n) return;
    await runTransaction('Deposit', () =>
      writeContractAsync({
        address: CONTRACTS.vault,
        abi: vaultAbi,
        functionName: 'deposit',
        args: [depositAmountUnits, address ?? ZERO_ADDRESS],
      }),
    );
    setDepositAmount('');
  };

  const handleWithdraw = async () => {
    if (!withdrawAmountUnits || withdrawAmountUnits <= 0n) return;
    await runTransaction('Withdraw', () =>
      writeContractAsync({
        address: CONTRACTS.vault,
        abi: vaultAbi,
        functionName: 'withdraw',
        args: [withdrawAmountUnits, address ?? ZERO_ADDRESS, address ?? ZERO_ADDRESS],
      }),
    );
    setWithdrawAmount('');
  };

  const handleSaveAllocations = async () => {
    if (!allocationDraft.length) return;
    const bpsPayload = allocationDraft.map((percent) => Math.round(percent * 100));
    await runTransaction('Allocations updated', () =>
      writeContractAsync({
        address: CONTRACTS.router,
        abi: routerAbi,
        functionName: 'setAllocations',
        args: [bpsPayload],
      }),
    );
  };

  const handleRoute = async () => {
    await runTransaction('Route', () =>
      writeContractAsync({
        address: CONTRACTS.router,
        abi: routerAbi,
        functionName: 'route',
        args: [],
      }),
    );
  };

  const goToLanding = () => {
    setShowSimulation(false);
    setView('landing');
  };

  const heroVaultCard = {
    id: 'l1',
    name: 'Dragon Vault L1',
    variant: 'l1' as const,
    principal: tvl ? formatCurrency(tvl, { compact: true }) : '—',
    apy: `${DISPLAY_APY.toFixed(1)}%`,
    topFundedLabel: 'Queued Yield',
    topFundedValue: routerBalanceValue ? formatCurrency(routerBalanceValue, { compact: true }) : '—',
    action: 'Open Dashboard',
  };

  const landingVaults = [heroVaultCard, ...placeholderLandingVaults];
  const isWrongNetwork = isConnected && chainId !== NETWORK.id;

  if (view === 'demo') {
    return (
      <div className="page dashboard">
        <div className="glow glow-left" />
        <div className="glow glow-right" />
        <div className="content dashboard-content">
          <nav className="demo-nav">
            <button className="icon-button" onClick={goToLanding} aria-label="Back to landing">
              ← Back
            </button>
            <div className="nav-actions">
              <ConnectButton />
              <button className="btn btn-secondary" onClick={() => setShowSimulation(true)}>
                Simulate Payout
              </button>
            </div>
          </nav>

          {isWrongNetwork && (
            <div className="network-warning">
              <p>Switch to {NETWORK.name} to interact with the vault.</p>
              <button className="btn btn-secondary" onClick={() => switchChainAsync?.({ chainId: NETWORK.id })}>
                Switch Network
              </button>
            </div>
          )}

          <header className="demo-header">
            <p>Configure how your vault&apos;s yield supports ecosystem growth</p>
          </header>

          <section className="demo-panel">
            <div className="vault-summary">
              <p className="vault-label">Dragon Vault L1</p>
              <h2>Dragon Vault L1</h2>
              <p className="stat-label">Principal</p>
              <p className="stat-value">{formatCurrency(managedAssetsValue)}</p>
              <p className="stat-label">APY</p>
              <p className="stat-value apy">{DISPLAY_APY.toFixed(1)}%</p>
              <p className="stat-label">Projected Monthly Yield</p>
              <p className="stat-value">{formatCurrency(projectedMonthlyYield)}</p>

              <div className="yield-sources">
                <p className="section-label">Yield Sources</p>
                <ul>
                  {yieldSources.map((source) => (
                    <li key={source}>{source}</li>
                  ))}
                </ul>
              </div>
            </div>

            <div className="vault-analytics">
              <div className="donut-chart" aria-label="Yield allocation chart" role="img">
                <div className="donut-hole" />
              </div>
              <div className="allocation-card">
                <p className="section-label">Yield Allocation</p>
                <ul>
                  {allocationDisplay.map((entry) => (
                    <li key={entry.id}>
                      <span>{entry.label}</span>
                      <strong>{entry.value}</strong>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </section>

          <section className="actions-grid">
            <article className="stat-card">
              <h4>Vault Metrics</h4>
              <div className="stat-row">
                <span>TVL</span>
                <strong>{formatCurrency(tvl)}</strong>
              </div>
              <div className="stat-row">
                <span>Your Shares</span>
                <strong>{isConnected ? formatCurrency(userShareValue) : 'Connect wallet'}</strong>
              </div>
              <div className="stat-row">
                <span>Queued Yield</span>
                <strong>{formatCurrency(routerBalanceValue)}</strong>
              </div>
            </article>

            <article className="form-card">
              <h4>Deposit</h4>
              <label htmlFor="deposit-input">Amount ({assetSymbol})</label>
              <input
                id="deposit-input"
                type="number"
                min="0"
                step="0.01"
                value={depositAmount}
                onChange={(event) => setDepositAmount(event.target.value)}
                placeholder="0.00"
              />
              <p className="form-helper">
                Wallet balance: {formatCurrency(walletBalanceValue)}{' '}
                {walletBalanceValue === 0 && (
                  <a
                    href="https://app.aave.com/faucet/"
                    target="_blank"
                    rel="noreferrer"
                    className="link"
                  >
                    (Get test USDC)
                  </a>
                )}
              </p>
              {needsApproval && (
                <button
                  className="btn btn-ghost"
                  onClick={handleApprove}
                  disabled={pendingAction !== null}
                >
                  Approve {assetSymbol}
                </button>
              )}
              <button
                className="btn btn-secondary"
                onClick={handleDeposit}
                disabled={!depositAmountUnits || pendingAction !== null || needsApproval}
              >
                {pendingAction === 'Deposit' ? 'Processing…' : 'Deposit'}
              </button>
            </article>

            <article className="form-card">
              <h4>Withdraw</h4>
              <label htmlFor="withdraw-input">Amount ({assetSymbol})</label>
              <input
                id="withdraw-input"
                type="number"
                min="0"
                step="0.01"
                value={withdrawAmount}
                onChange={(event) => setWithdrawAmount(event.target.value)}
                placeholder="0.00"
              />
              <p className="form-helper">Available: {formatCurrency(userShareValue)}</p>
              <button
                className="btn btn-secondary"
                onClick={handleWithdraw}
                disabled={!withdrawAmountUnits || pendingAction !== null}
              >
                {pendingAction === 'Withdraw' ? 'Processing…' : 'Withdraw'}
              </button>
            </article>
          </section>

          {feedback && <p className="feedback-banner">{feedback}</p>}

          <section className="allocation-panel">
            <header className="allocation-header">
              <div>
                <h3>Allocation Controls</h3>
                <p>Adjust target weighting in basis points (max 100%).</p>
              </div>
              <p>Sum: {allocationSum.toFixed(1)}%</p>
            </header>
            {programs.length === 0 && <p className="form-helper">Add programs in the router to edit allocations.</p>}
            {programs.map((program, idx) => (
              <div key={program.id} className="allocation-row">
                <div>
                  <p className="allocation-title">{programTitle(program)}</p>
                  <p className="form-helper">Recipient: {program.recipient}</p>
                </div>
                <div className="slider-field">
                  <input
                    type="range"
                    min={0}
                    max={100}
                    step={0.5}
                    value={allocationDraft[idx] ?? program.bps / 100}
                    onChange={(event) => {
                      const next = Number(event.target.value);
                      setAllocationDraft((draft) => {
                        const clone = [...draft];
                        clone[idx] = next;
                        return clone;
                      });
                    }}
                  />
                  <span>{(allocationDraft[idx] ?? program.bps / 100).toFixed(1)}%</span>
                </div>
              </div>
            ))}
            <div className="allocation-actions">
              <button className="btn btn-ghost" onClick={() => setAllocationDraft(programs.map((program) => program.bps / 100))}>
                Reset
              </button>
              <button
                className="btn btn-secondary"
                onClick={handleSaveAllocations}
                disabled={!programs.length || allocationSum > 100 || allocationsMatchOnChain || pendingAction !== null}
              >
                Save Allocations
              </button>
            </div>
          </section>

          <section className="routing-review">
            <div className="routing-card">
              <header>
                <div>
                  <p className="section-label">Yield Routing Review</p>
                  <h3>Active Programs</h3>
                </div>
              </header>
              <ul>
                {(impactPrograms.length ? impactPrograms : simulationPrograms).map((program) => (
                  <li key={program.id}>
                    <div className="program-row">
                      <strong>{program.title}</strong>
                      <span>{program.percent.toFixed(1)}%</span>
                    </div>
                    <p>{program.description}</p>
                    <p className="program-amount">{formatCurrency(program.amount ?? 0)}</p>
                  </li>
                ))}
              </ul>
            </div>
            <div className="routing-card total-card">
              <p className="section-label">Funds Queued in Router</p>
              <p className="total-value">{formatCurrency(routerBalanceValue)}</p>
              <button className="btn btn-secondary" onClick={handleRoute} disabled={pendingAction !== null}>
                {pendingAction === 'Route' ? 'Routing…' : 'Route Yield'}
              </button>
            </div>
          </section>
        </div>
        {showSimulation && (
          <SimulationModal
            projectedYield={projectedMonthlyYield}
            totalRouted={routerBalanceValue}
            programs={simulationPrograms}
            onClose={() => setShowSimulation(false)}
          />
        )}
      </div>
    );
  }

  return (
    <div className="page">
      <div className="glow glow-left" />
      <div className="glow glow-right" />
      <div className="content">
        <header className="header">
          <div className="brand">
            <div className="brand-icon" aria-hidden>
              <span />
            </div>
            <p className="brand-eyebrow">oCtant Mini</p>
          </div>
          <div className="header-actions">
            <ConnectButton />
            <button className="btn btn-secondary" onClick={() => setView('demo')}>
              Launch Demo
            </button>
          </div>
        </header>

        <main>
          <section className="hero">
            <h1>
              Power Your Ecosystem With
              <br />
              Automated Yield Funding
            </h1>
            <p className="hero-body">
              Turn idle treasury assets into <span>continuous</span>, transparent funding streams without your{' '}
              <span>principal</span>.
            </p>
          </section>

          <section className="vaults">
            {landingVaults.map((vault) => (
              <article key={vault.id} className={`vault-card ${vault.variant}`}>
                <div className="vault-card__body">
                  <p className="vault-label">{renderVaultLabel(vault.name)}</p>
                  <h3>{vault.name}</h3>
                  <div className="stat-block">
                    <div>
                      <p className="stat-label">Principal</p>
                      <p className="stat-value">{vault.principal}</p>
                    </div>
                    <div>
                      <p className="stat-label">APY</p>
                      <p className="stat-value apy">{vault.apy}</p>
                    </div>
                  </div>
                </div>
                <div className="vault-card__footer">
                  <p className="stat-label">{vault.topFundedLabel}</p>
                  <p className="vault-highlight">{vault.topFundedValue}</p>
                  {vault.action && (
                    <button className="btn btn-ghost" onClick={() => setView('demo')}>
                      {vault.action}
                    </button>
                  )}
                </div>
              </article>
            ))}
          </section>

          <section className="flows">
            {flows.map((flow) => (
              <article key={flow.id} className={`flow-card ${flow.id}`}>
                <div className="flow-icon">{iconMap[flow.id]}</div>
                <h4>{flow.title}</h4>
                <p className="flow-description">{flow.description}</p>
                {flow.note && <p className="flow-note">{flow.note}</p>}
              </article>
            ))}
          </section>
        </main>
      </div>
    </div>
  );
}

export default App;
