export const formatCurrency = (value: number, { compact = false }: { compact?: boolean } = {}) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: compact ? 1 : 2,
    notation: compact ? 'compact' : 'standard',
  }).format(Number.isFinite(value) ? value : 0);
};

export const formatPercent = (value: number, digits = 1) => `${value.toFixed(digits)}%`;
