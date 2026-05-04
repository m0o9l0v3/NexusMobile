import { useState } from 'react';
import { Check, ChevronRight, Download, Plus, Save, Send, Trash2 } from 'lucide-react';

const steps = [
  { id: 1, name: 'Basics', desc: 'Date and audience' },
  { id: 2, name: 'Events', desc: 'Sessions and timing' },
  { id: 3, name: 'Rules', desc: 'Expiry and volume' },
  { id: 4, name: 'Review', desc: 'Confirm and publish' },
];

type Exhibition = {
  id: number;
  name: string;
  location: string;
  time: string;
  tags: string[];
};

export function QRIssue() {
  const [currentStep, setCurrentStep] = useState(1);
  const [exhibitions, setExhibitions] = useState<Exhibition[]>([
    { id: 1, name: 'Trial Class', location: 'PC Room', time: '10:00-12:00', tags: ['intro', 'faculty'] },
  ]);

  const addExhibition = () => {
    setExhibitions((current) => [...current, { id: Date.now(), name: '', location: '', time: '', tags: [] }]);
  };

  const removeExhibition = (id: number) => {
    setExhibitions((current) => current.filter((item) => item.id !== id));
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold text-foreground">QR Issue</h2>
        <p className="mt-1 text-sm text-muted-foreground">Configure and publish event QR codes.</p>
      </div>

      <div className="rounded-2xl border border-border bg-card p-6 shadow-sm">
        <div className="flex flex-wrap items-center gap-4">
          {steps.map((step, index) => (
            <div key={step.id} className="flex flex-1 items-center gap-4">
              <div className="flex items-center gap-3">
                <div
                  className={`flex h-10 w-10 items-center justify-center rounded-full border-2 ${
                    currentStep > step.id
                      ? 'border-primary bg-primary text-primary-foreground'
                      : currentStep === step.id
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-border bg-muted text-muted-foreground'
                  }`}
                >
                  {currentStep > step.id ? <Check className="h-5 w-5" /> : step.id}
                </div>
                <div>
                  <div className="text-sm font-medium">{step.name}</div>
                  <div className="text-xs text-muted-foreground">{step.desc}</div>
                </div>
              </div>
              {index < steps.length - 1 && <div className="hidden h-0.5 flex-1 bg-border xl:block" />}
            </div>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-12">
        <div className="xl:col-span-7">
          <div className="rounded-2xl border border-border bg-card p-6 shadow-sm">
            {currentStep === 1 && (
              <div className="space-y-6">
                <h3 className="text-lg font-semibold">Basic Settings</h3>
                <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                  <div>
                    <label className="mb-2 block text-sm font-medium">Event date</label>
                    <input type="date" defaultValue="2026-02-15" className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm" />
                  </div>
                  <div>
                    <label className="mb-2 block text-sm font-medium">Time window</label>
                    <input type="text" defaultValue="09:00-17:00" className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm" />
                  </div>
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium">Departments</label>
                  <div className="grid grid-cols-1 gap-2 md:grid-cols-2">
                    {['IT', 'Design', 'Business', 'Game'].map((dept) => (
                      <label key={dept} className="flex items-center gap-2 text-sm">
                        <input type="checkbox" defaultChecked={dept === 'IT'} className="h-4 w-4" />
                        <span>{dept}</span>
                      </label>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {currentStep === 2 && (
              <div className="space-y-6">
                <div className="flex items-center justify-between">
                  <h3 className="text-lg font-semibold">Event List</h3>
                  <button onClick={addExhibition} className="flex items-center gap-2 rounded-lg bg-primary px-3 py-1.5 text-sm text-primary-foreground hover:bg-primary/90">
                    <Plus className="h-4 w-4" />
                    Add
                  </button>
                </div>

                <div className="space-y-4">
                  {exhibitions.map((item, index) => (
                    <div key={item.id} className="rounded-lg border border-border bg-muted/30 p-4">
                      <div className="mb-3 flex items-center justify-between">
                        <span className="text-sm font-medium">Event {index + 1}</span>
                        {exhibitions.length > 1 && (
                          <button onClick={() => removeExhibition(item.id)} className="text-destructive hover:text-destructive/80">
                            <Trash2 className="h-4 w-4" />
                          </button>
                        )}
                      </div>
                      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                        <input type="text" defaultValue={item.name} placeholder="Name" className="rounded-lg border border-border bg-card px-3 py-2 text-sm" />
                        <input type="text" defaultValue={item.location} placeholder="Location" className="rounded-lg border border-border bg-card px-3 py-2 text-sm" />
                        <input type="text" defaultValue={item.time} placeholder="10:00-12:00" className="rounded-lg border border-border bg-card px-3 py-2 text-sm" />
                        <input type="text" defaultValue={item.tags.join(', ')} placeholder="Tags" className="rounded-lg border border-border bg-card px-3 py-2 text-sm" />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {currentStep === 3 && (
              <div className="space-y-6">
                <h3 className="text-lg font-semibold">Distribution Rules</h3>
                <div>
                  <label className="mb-2 block text-sm font-medium">Expiry</label>
                  <input type="text" defaultValue="2026-02-15 23:59" className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm" />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium">Volume</label>
                  <input type="number" defaultValue="500" className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm" />
                </div>
              </div>
            )}

            {currentStep === 4 && (
              <div className="space-y-6">
                <h3 className="text-lg font-semibold">Review</h3>
                <div className="rounded-lg bg-muted/30 p-4 text-sm">
                  <div className="flex justify-between py-1">
                    <span className="text-muted-foreground">Date</span>
                    <span>2026-02-15</span>
                  </div>
                  <div className="flex justify-between py-1">
                    <span className="text-muted-foreground">Window</span>
                    <span>09:00-17:00</span>
                  </div>
                  <div className="flex justify-between py-1">
                    <span className="text-muted-foreground">Events</span>
                    <span>{exhibitions.length}</span>
                  </div>
                </div>
                <div className="flex flex-wrap gap-3">
                  <button className="flex items-center gap-2 rounded-lg border border-border px-4 py-2 text-sm hover:bg-accent">
                    <Save className="h-4 w-4" />
                    Save Draft
                  </button>
                  <button className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground hover:bg-primary/90">
                    <Send className="h-4 w-4" />
                    Publish
                  </button>
                  <button className="flex items-center gap-2 rounded-lg border border-border px-4 py-2 text-sm hover:bg-accent">
                    <Download className="h-4 w-4" />
                    PDF
                  </button>
                </div>
              </div>
            )}

            <div className="mt-8 flex items-center justify-between border-t border-border pt-6">
              <button
                onClick={() => setCurrentStep((value) => Math.max(1, value - 1))}
                disabled={currentStep === 1}
                className="rounded-lg border border-border bg-card px-4 py-2 text-sm font-medium hover:bg-accent disabled:cursor-not-allowed disabled:opacity-50"
              >
                Back
              </button>
              <button
                onClick={() => setCurrentStep((value) => Math.min(4, value + 1))}
                disabled={currentStep === 4}
                className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Next
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        <div className="xl:col-span-5">
          <div className="sticky top-24 rounded-2xl border border-border bg-card p-6 shadow-sm">
            <h3 className="font-semibold">Preview</h3>
            <p className="mt-1 text-sm text-muted-foreground">Preview of the generated QR card.</p>
            <div className="mt-6 flex justify-center rounded-xl bg-gradient-to-br from-blue-50 to-slate-100 p-8">
              <div className="rounded-2xl bg-white p-6 shadow-lg">
                <div className="h-48 w-48 rounded-lg bg-[linear-gradient(90deg,#000_1px,transparent_1px),linear-gradient(0deg,#000_1px,transparent_1px)] bg-[length:12px_12px] bg-white" />
                <div className="mt-4 text-center">
                  <div className="text-sm font-medium">Nexus Open Campus 2026</div>
                  <div className="mt-1 text-xs text-muted-foreground">nexus.example/oc/abc123</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
