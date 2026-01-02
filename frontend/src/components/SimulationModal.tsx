import { formatCurrency } from '../lib/format';

type ProgramProjection = {
  id: number;
  title: string;
  percent: number;
  amount: number;
  description: string;
};

interface SimulationModalProps {
  projectedYield: number;
  totalRouted: number;
  programs: ProgramProjection[];
  onClose: () => void;
}

export function SimulationModal({ projectedYield, totalRouted, programs, onClose }: SimulationModalProps) {
  return (
    <div className="modal-overlay" role="dialog" aria-modal="true" aria-label="Simulate payout">
      <div className="modal">
        <header className="modal-header">
          <div>
            <h2>Simulate Payout</h2>
            <p>Preview how this month&apos;s yield would be distributed across your programs.</p>
          </div>
          <button className="icon-button close" onClick={onClose} aria-label="Close simulation">
            ×
          </button>
        </header>
        <div className="modal-body">
          <p className="section-label">Projected Monthly Yield</p>
          <p className="projected-value">{formatCurrency(projectedYield)}</p>
          <p className="modal-subtext">
            This amount is based on your vault&apos;s current TVL and configured APY.
          </p>
          <div className="program-list">
            {programs.map((program) => (
              <article key={program.id} className="program-card">
                <div>
                  <h3>
                    {program.title}
                    <span className="program-percent">{program.percent.toFixed(1)}%</span>
                  </h3>
                  <p>{program.description}</p>
                </div>
                <strong>{formatCurrency(program.amount)}</strong>
              </article>
            ))}
          </div>
          <div className="modal-total">
            <span>Total Routed This Month</span>
            <strong>{formatCurrency(totalRouted)}</strong>
          </div>
        </div>
        <footer className="modal-actions">
          <button className="btn btn-danger" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn-secondary" onClick={onClose}>
            Apply Simulation
          </button>
        </footer>
      </div>
    </div>
  );
}
