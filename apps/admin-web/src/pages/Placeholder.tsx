import { Construction } from 'lucide-react';

interface PlaceholderProps {
  title: string;
  description: string;
}

export function Placeholder({ title, description }: PlaceholderProps) {
  return (
    <div className="flex min-h-[600px] items-center justify-center">
      <div className="text-center">
        <div className="mb-4 inline-flex h-16 w-16 items-center justify-center rounded-full bg-primary/10 text-primary">
          <Construction className="h-8 w-8" />
        </div>
        <h2 className="text-2xl font-semibold text-foreground mb-2">{title}</h2>
        <p className="text-muted-foreground">{description}</p>
        <div className="mt-6">
          <button className="rounded-lg bg-primary px-6 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90">
            開発中
          </button>
        </div>
      </div>
    </div>
  );
}
