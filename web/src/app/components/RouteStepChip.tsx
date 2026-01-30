type RouteStepChipProps = {
  label: string;
};

export function RouteStepChip({ label }: RouteStepChipProps) {
  return (
    <div
      className="inline-flex items-center px-3 py-1.5 rounded-full text-xs font-medium"
      style={{
        backgroundColor: 'var(--surface)',
        color: 'var(--primary)',
        border: '1px solid var(--primary-weak)',
      }}
    >
      {label}
    </div>
  );
}
