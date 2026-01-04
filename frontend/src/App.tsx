import { useEffect, useMemo, useState } from 'react';
import {
  useAccount,
  useChainId,
  usePublicClient,
  useReadContract,
  useReadContracts,
  useSwitchChain,
  useWriteContract,
} from 'wagmi';
import { formatUnits, maxUint256, parseUnits } from 'viem';
import { BENEFICIARIES, CONTRACTS, DISPLAY_APY, NETWORK, PROGRAM_METADATA } from './config/contracts';
import { vaultAbi } from './abi/vault';
import { routerAbi } from './abi/router';
import { erc20Abi } from './abi/erc20';
import { ConnectButton } from './components/ConnectButton';
import { formatCurrency } from './lib/format';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

type FlowCard = {
  id: string;
  title: string;
  description: string;
  note?: string;
};

type BeneficiaryConfig = {
  address: `0x${string}`;
  metadataURI: string;
};

const flows: FlowCard[] = [
  {
    id: 'deposit',
    title: 'Deposit',
    description:
      'Put treasury assets into a YieldRelay vault. Your principal stays safe while yield accrues.',
  },
  {
    id: 'generate',
    title: 'Generate',
    description: 'The vault supplies funds to a yield source and tracks accrued yield separately.',
    note: 'Yield is isolated from principal by design.',
  },
  {
    id: 'route',
    title: 'Route',
    description: 'Yield routes to registered beneficiaries using the split you define.',
    note: 'Compliance-aware, transparent, and auditable.',
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

const yieldSources = ['Mock Aave Pool', 'YieldRelay Router'];

const placeholderLandingVaults = [
  {
    id: 'create',
    name: 'Create Vault',
    variant: 'stable' as const,
    principal: 'Configure splits',
    apy: 'Choose beneficiaries',
    topFundedLabel: 'Status',
    topFundedValue: 'Ready to deploy',
  },
  {
    id: 'current',
    name: 'Current Vault',
    variant: 'experimental' as const,
    principal: '$ 0.00',
    apy: '0.0%',
    topFundedLabel: 'Beneficiaries',
    topFundedValue: 'Configured splits',
    action: 'View Dashboard',
  },
  {
    id: 'beneficiaries',
    name: 'Beneficiaries',
    variant: 'stable' as const,
    principal: 'Verify eligibility',
    apy: 'Claim yield',
    topFundedLabel: 'Compliance',
    topFundedValue: 'Registry-backed',
  },
];

const bnToNumber = (value?: bigint, decimals = 18) => {
  if (!value) return 0;
  return Number(formatUnits(value, decimals));
};

const beneficiaryTitle = (beneficiary: BeneficiaryConfig, index: number) =>
  PROGRAM_METADATA[beneficiary.metadataURI]?.title ?? `Beneficiary #${index + 1}`;

const beneficiaryDescription = (beneficiary: BeneficiaryConfig) =>
  PROGRAM_METADATA[beneficiary.metadataURI]?.description ?? 'Eligible ecosystem recipient';

function App() {
  const renderVaultLabel = (name: string) => name.split(' ').pop() ?? '';
  const [view, setView] = useState<'landing' | 'demo'>('landing');
  const [depositAmount, setDepositAmount] = useState('');
  const [mintAmount, setMintAmount] = useState('');
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

  const totalPrincipalQuery = useReadContract({
    address: CONTRACTS.vault,
    abi: vaultAbi,
    functionName: 'totalPrincipal',
    query: { refetchInterval: 15000 },
  });
  const accruedYieldQuery = useReadContract({
    address: CONTRACTS.vault,
    abi: vaultAbi,
    functionName: 'accruedYield',
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
  const userPrincipalQuery = useReadContract({
    address: CONTRACTS.vault,
    abi: vaultAbi,
    functionName: 'principalOf',
    args: [address ?? ZERO_ADDRESS],
    query: { enabled: Boolean(address), refetchInterval: 15000 },
  });
  const userPendingYieldQuery = useReadContract({
    address: CONTRACTS.vault,
    abi: vaultAbi,
    functionName: 'pendingYield',
    args: [address ?? ZERO_ADDRESS],
    query: { enabled: Boolean(address), refetchInterval: 15000 },
  });

  const beneficiaries = BENEFICIARIES as BeneficiaryConfig[];
  const claimableResults = useReadContracts({
    contracts: beneficiaries.map((beneficiary) => ({
      address: CONTRACTS.router,
      abi: routerAbi,
      functionName: 'claimable',
      args: [beneficiary.address],
    })),
    query: { refetchInterval: 15000 },
  });

  useEffect(() => {
    if (!beneficiaries.length) return;
    setAllocationDraft((prev) => {
      if (prev.length === beneficiaries.length && prev.some((value) => value > 0)) {
        return prev;
      }
      const evenSplit = Math.floor(1000 / beneficiaries.length) / 10;
      const remainder = 100 - evenSplit * (beneficiaries.length - 1);
      return beneficiaries.map((_, idx) => (idx === beneficiaries.length - 1 ? remainder : evenSplit));
    });
  }, [beneficiaries.length]);

  const tvl = bnToNumber(totalPrincipalQuery.data, assetDecimals);
  const accruedYieldValue = bnToNumber(accruedYieldQuery.data, assetDecimals);
  const walletBalanceValue = isConnected ? bnToNumber(walletBalanceQuery.data, assetDecimals) : 0;
  const allowanceValue = allowanceQuery.data ?? 0n;
  const userPrincipalValue = bnToNumber(userPrincipalQuery.data, assetDecimals);
  const userPendingYieldValue = bnToNumber(userPendingYieldQuery.data, assetDecimals);


  const depositAmountUnits = useMemo(() => {
    if (!depositAmount) return null;
    try {
      return parseUnits(depositAmount, assetDecimals);
    } catch {
      return null;
    }
  }, [depositAmount, assetDecimals]);

  const mintAmountUnits = useMemo(() => {
    if (!mintAmount) return null;
    try {
      return parseUnits(mintAmount, assetDecimals);
    } catch {
      return null;
    }
  }, [mintAmount, assetDecimals]);

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
  const allocationSumIsValid = Math.abs(allocationSum - 100) < 0.01;
  const allocationDisplay = beneficiaries.length
    ? beneficiaries.map((beneficiary, idx) => ({
        id: `beneficiary-${beneficiary.address}`,
        label: beneficiaryTitle(beneficiary, idx),
        value: `${(allocationDraft[idx] ?? 0).toFixed(1)}%`,
      }))
    : placeholderLandingVaults.map((vault) => ({
        id: vault.id,
        label: vault.name,
        value: vault.apy,
      }));

  const donutGradient = useMemo(() => {
    if (!beneficiaries.length) return undefined;
    const colors = ['#7f58ff', '#47f1b2', '#8e9bff', '#ffb86b', '#66d9ef'];
    const total = allocationSum > 0 ? allocationSum : 100;
    let cursor = 0;
    const stops = beneficiaries.map((_, idx) => {
      const value = allocationDraft[idx] ?? 0;
      const slice = (value / total) * 100;
      const start = cursor;
      const end = cursor + slice;
      cursor = end;
      return `${colors[idx % colors.length]} ${start.toFixed(2)}% ${end.toFixed(2)}%`;
    });
    if (!stops.length) return undefined;
    return `conic-gradient(${stops.join(', ')})`;
  }, [beneficiaries.length, allocationDraft, allocationSum]);

  const beneficiaryClaimables = beneficiaries.map((beneficiary, idx) => {
    const result = claimableResults.data?.[idx];
    const raw = result?.result as bigint | undefined;
    return {
      ...beneficiary,
      title: beneficiaryTitle(beneficiary, idx),
      description: beneficiaryDescription(beneficiary),
      claimable: bnToNumber(raw, assetDecimals),
    };
  });
  const connectedBeneficiaryIndex = beneficiaries.findIndex(
    (beneficiary) => beneficiary.address.toLowerCase() === address?.toLowerCase(),
  );
  const connectedClaimableRaw =
    connectedBeneficiaryIndex >= 0
      ? (claimableResults.data?.[connectedBeneficiaryIndex]?.result as bigint | undefined)
      : undefined;
  const connectedClaimableValue = bnToNumber(connectedClaimableRaw, assetDecimals);

  const refetchAll = async () => {
    await Promise.all([
      totalPrincipalQuery.refetch?.(),
      accruedYieldQuery.refetch?.(),
      walletBalanceQuery.refetch?.(),
      allowanceQuery.refetch?.(),
      userPrincipalQuery.refetch?.(),
      userPendingYieldQuery.refetch?.(),
      claimableResults.refetch?.(),
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
    const beneficiariesPayload = beneficiaries.map((item) => item.address);
    const bpsPayload = allocationDraft.map((percent) => Math.round(percent * 100));
    await runTransaction('Deposit', () =>
      writeContractAsync({
        address: CONTRACTS.vault,
        abi: vaultAbi,
        functionName: 'deposit',
        args: [depositAmountUnits, beneficiariesPayload, bpsPayload],
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
        functionName: 'withdrawPrincipal',
        args: [withdrawAmountUnits],
      }),
    );
    setWithdrawAmount('');
  };

  const handleMint = async () => {
    if (!mintAmountUnits || mintAmountUnits <= 0n) return;
    await runTransaction('Mint', () =>
      writeContractAsync({
        address: CONTRACTS.asset,
        abi: erc20Abi,
        functionName: 'mint',
        args: [address ?? ZERO_ADDRESS, mintAmountUnits],
      }),
    );
    setMintAmount('');
  };

  const handleSaveAllocations = async () => {
    if (!allocationDraft.length) return;
    const beneficiariesPayload = beneficiaries.map((item) => item.address);
    const bpsPayload = allocationDraft.map((percent) => Math.round(percent * 100));
    await runTransaction('Split updated', () =>
      writeContractAsync({
        address: CONTRACTS.vault,
        abi: vaultAbi,
        functionName: 'setSplitConfig',
        args: [beneficiariesPayload, bpsPayload],
      }),
    );
  };

  const handleAllocateYield = async () => {
    await runTransaction('Allocate Yield', () =>
      writeContractAsync({
        address: CONTRACTS.vault,
        abi: vaultAbi,
        functionName: 'allocateYield',
        args: [address ?? ZERO_ADDRESS],
      }),
    );
  };

  const handleClaimYield = async () => {
    if (connectedBeneficiaryIndex < 0) return;
    await runTransaction('Claim Yield', () =>
      writeContractAsync({
        address: CONTRACTS.router,
        abi: routerAbi,
        functionName: 'claimYield',
        args: [],
      }),
    );
  };

  const goToLanding = () => {
    setView('landing');
  };

  const heroVaultCard = {
    id: 'l1',
    name: 'YieldRelay Vault',
    variant: 'l1' as const,
    principal: tvl ? formatCurrency(tvl, { compact: true }) : '—',
    apy: `${DISPLAY_APY.toFixed(1)}%`,
    topFundedLabel: 'Accrued Yield',
    topFundedValue: accruedYieldValue ? formatCurrency(accruedYieldValue, { compact: true }) : '—',
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
            <p>Configure how your vault&apos;s yield supports verified beneficiaries</p>
          </header>

          <section className="demo-panel">
            <div className="vault-summary">
              <p className="vault-label">YieldRelay Vault</p>
              <h2>YieldRelay Vault</h2>
              <p className="stat-label">Principal</p>
              <p className="stat-value">{formatCurrency(tvl)}</p>
              <p className="stat-label">APY</p>
              <p className="stat-value apy">{DISPLAY_APY.toFixed(1)}%</p>
              <p className="stat-label">Accrued Yield</p>
              <p className="stat-value">{formatCurrency(accruedYieldValue)}</p>

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
              <div
                className="donut-chart"
                aria-label="Yield allocation chart"
                role="img"
                style={donutGradient ? { background: donutGradient } : undefined}
              >
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
                <span>Your Principal</span>
                <strong>{isConnected ? formatCurrency(userPrincipalValue) : 'Connect wallet'}</strong>
              </div>
              <div className="stat-row">
                <span>Your Pending Yield</span>
                <strong>{isConnected ? formatCurrency(userPendingYieldValue) : 'Connect wallet'}</strong>
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
              <p className="form-helper">Uses the current beneficiary splits (must total 100%).</p>
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
                disabled={!depositAmountUnits || pendingAction !== null || needsApproval || !allocationSumIsValid}
              >
                {pendingAction === 'Deposit' ? 'Processing…' : 'Deposit'}
              </button>
            </article>

            <article className="form-card">
              <h4>Mint Test Tokens</h4>
              <label htmlFor="mint-input">Amount ({assetSymbol})</label>
              <input
                id="mint-input"
                type="number"
                min="0"
                step="0.01"
                value={mintAmount}
                onChange={(event) => setMintAmount(event.target.value)}
                placeholder="0.00"
              />
              <p className="form-helper">Mints mock tokens to your connected wallet.</p>
              <button
                className="btn btn-secondary"
                onClick={handleMint}
                disabled={!mintAmountUnits || pendingAction !== null || !isConnected}
              >
                {pendingAction === 'Mint' ? 'Minting…' : 'Mint Tokens'}
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
              <p className="form-helper">Available: {formatCurrency(userPrincipalValue)}</p>
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
                <h3>Beneficiary Splits</h3>
                <p>Adjust split percentages (must sum to 100%).</p>
              </div>
              <p>Sum: {allocationSum.toFixed(1)}%</p>
            </header>
            {beneficiaries.length === 0 && <p className="form-helper">Add beneficiaries to configure splits.</p>}
            {beneficiaries.map((beneficiary, idx) => (
              <div key={beneficiary.address} className="allocation-row">
                <div>
                  <p className="allocation-title">{beneficiaryTitle(beneficiary, idx)}</p>
                  <p className="form-helper">Recipient: {beneficiary.address}</p>
                </div>
                <div className="slider-field">
                  <input
                    type="range"
                    min={0}
                    max={100}
                    step={0.5}
                    value={allocationDraft[idx] ?? 0}
                    onChange={(event) => {
                      const next = Number(event.target.value);
                      setAllocationDraft((draft) => {
                        const total = 100;
                        const clone = [...draft];
                        const prev = clone[idx] ?? 0;
                        const delta = next - prev;
                        if (delta === 0) return clone;

                        clone[idx] = next;
                        if (clone.length === 1) {
                          clone[idx] = total;
                          return clone;
                        }

                        const others = clone
                          .map((value, index) => ({ value: value ?? 0, index }))
                          .filter((item) => item.index !== idx);

                        const otherTotal = others.reduce((sum, item) => sum + item.value, 0);
                        let remainingDelta = delta;
                        const adjusted = [...clone];

                        const ordered = delta > 0
                          ? [...others].sort((a, b) => b.value - a.value)
                          : [...others].sort((a, b) => a.value - b.value);

                        for (const item of ordered) {
                          if (remainingDelta === 0) break;
                          const current = adjusted[item.index] ?? 0;
                          if (delta > 0) {
                            const available = current;
                            const take = Math.min(available, remainingDelta);
                            adjusted[item.index] = current - take;
                            remainingDelta -= take;
                          } else {
                            const available = total - current;
                            const give = Math.min(available, -remainingDelta);
                            adjusted[item.index] = current + give;
                            remainingDelta += give;
                          }
                        }

                        if (Math.abs(remainingDelta) > 0.0001 && otherTotal > 0) {
                          const scale = (otherTotal - delta) / otherTotal;
                          for (const item of others) {
                            adjusted[item.index] = Math.max(0, Math.min(100, (adjusted[item.index] ?? 0) * scale));
                          }
                        }

                        const sum = adjusted.reduce((sum, value) => sum + (value ?? 0), 0);
                        if (sum !== total) {
                          const target = others.length ? others[others.length - 1].index : idx;
                          adjusted[target] = Math.max(0, Math.min(100, (adjusted[target] ?? 0) + (total - sum)));
                        }

                        return adjusted;
                      });
                    }}
                  />
                  <span>{(allocationDraft[idx] ?? 0).toFixed(1)}%</span>
                </div>
              </div>
            ))}
            <div className="allocation-actions">
              <button
                className="btn btn-ghost"
                onClick={() => {
                  const evenSplit = Math.floor(1000 / beneficiaries.length) / 10;
                  const remainder = 100 - evenSplit * (beneficiaries.length - 1);
                  setAllocationDraft(
                    beneficiaries.map((_, idx) => (idx === beneficiaries.length - 1 ? remainder : evenSplit)),
                  );
                }}
              >
                Reset
              </button>
              <button
                className="btn btn-secondary"
                onClick={handleSaveAllocations}
                disabled={!beneficiaries.length || !allocationSumIsValid || pendingAction !== null}
              >
                Save Splits
              </button>
            </div>
          </section>

          <section className="routing-review">
            <div className="routing-card">
              <header>
                <div>
                  <p className="section-label">Beneficiaries</p>
                  <h3>Claimable Yield</h3>
                </div>
              </header>
              <ul>
                {beneficiaryClaimables.map((beneficiary) => (
                  <li key={beneficiary.address}>
                    <div className="program-row">
                      <strong>{beneficiary.title}</strong>
                      <span>{formatCurrency(beneficiary.claimable)}</span>
                    </div>
                    <p>{beneficiary.description}</p>
                    <p className="program-amount">{beneficiary.address}</p>
                  </li>
                ))}
              </ul>
            </div>
            <div className="routing-card total-card">
              <p className="section-label">Yield Actions</p>
              <p className="total-value">{formatCurrency(accruedYieldValue)}</p>
              <button
                className="btn btn-secondary"
                onClick={handleAllocateYield}
                disabled={pendingAction !== null || !isConnected}
              >
                {pendingAction === 'Allocate Yield' ? 'Allocating…' : 'Allocate Yield'}
              </button>
              <button
                className="btn btn-ghost"
                onClick={handleClaimYield}
                disabled={pendingAction !== null || connectedBeneficiaryIndex < 0}
              >
                {pendingAction === 'Claim Yield' ? 'Claiming…' : 'Claim Yield'}
              </button>
              {connectedBeneficiaryIndex < 0 && (
                <p className="form-helper">Connect with a beneficiary wallet to claim.</p>
              )}
              {connectedBeneficiaryIndex >= 0 && (
                <p className="form-helper">
                  Claimable for you: {formatCurrency(connectedClaimableValue)}
                </p>
              )}
            </div>
          </section>
        </div>
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
            <p className="brand-eyebrow">YieldRelay</p>
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
