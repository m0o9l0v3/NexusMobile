import { useState } from 'react';
import { Check, ChevronRight, Plus, Trash2, Download, Save, Send } from 'lucide-react';

const steps = [
  { id: 1, name: '基本情報', desc: 'イベント基本設定' },
  { id: 2, name: '展示/イベント情報', desc: '詳細コンテンツ' },
  { id: 3, name: '配布設定', desc: 'QRコード設定' },
  { id: 4, name: '確認 & 発行', desc: 'プレビュー' },
];

export function QRIssue() {
  const [currentStep, setCurrentStep] = useState(1);
  const [exhibitions, setExhibitions] = useState([
    { id: 1, name: 'トータルモビリティ工学科説明会', location: 'PC教室', time: '10:00-12:00', tags: ['説明会', '工学科'] },
  ]);

  const addExhibition = () => {
    setExhibitions([
      ...exhibitions,
      { id: Date.now(), name: '', location: '', time: '', tags: [] },
    ]);
  };

  const removeExhibition = (id: number) => {
    setExhibitions(exhibitions.filter((ex) => ex.id !== id));
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h2 className="text-2xl font-semibold text-foreground">QRコード発行</h2>
        <p className="text-sm text-muted-foreground mt-1">
          来場者用QRコードを作成・発行します
        </p>
      </div>

      {/* Stepper */}
      <div className="rounded-2xl border border-border bg-card p-6 shadow-sm">
        <div className="flex items-center justify-between">
          {steps.map((step, idx) => (
            <div key={step.id} className="flex flex-1 items-center">
              <div className="flex flex-col items-center">
                <div
                  className={`flex h-10 w-10 items-center justify-center rounded-full border-2 transition-colors ${
                    currentStep > step.id
                      ? 'border-primary bg-primary text-primary-foreground'
                      : currentStep === step.id
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-border bg-muted text-muted-foreground'
                  }`}
                >
                  {currentStep > step.id ? <Check className="h-5 w-5" /> : step.id}
                </div>
                <div className="mt-2 text-center">
                  <div className="text-sm font-medium">{step.name}</div>
                  <div className="text-xs text-muted-foreground">{step.desc}</div>
                </div>
              </div>
              {idx < steps.length - 1 && (
                <div
                  className={`mx-4 h-0.5 flex-1 ${
                    currentStep > step.id ? 'bg-primary' : 'bg-border'
                  }`}
                ></div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Content Area */}
      <div className="grid grid-cols-12 gap-6">
        {/* Form Section */}
        <div className="col-span-7">
          <div className="rounded-2xl border border-border bg-card p-6 shadow-sm">
            {/* Step 1: Basic Info */}
            {currentStep === 1 && (
              <div className="space-y-6">
                <div>
                  <h3 className="text-lg font-semibold mb-4">基本情報</h3>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="mb-2 block text-sm font-medium">オープンキャンパス日付</label>
                    <input
                      type="date"
                      defaultValue="2026-02-15"
                      className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                    />
                  </div>
                  <div>
                    <label className="mb-2 block text-sm font-medium">開催時間</label>
                    <div className="flex gap-2">
                      <input
                        type="time"
                        defaultValue="09:00"
                        className="flex-1 rounded-lg border border-border bg-input-background px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                      <span className="flex items-center text-muted-foreground">～</span>
                      <input
                        type="time"
                        defaultValue="17:00"
                        className="flex-1 rounded-lg border border-border bg-input-background px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                  </div>
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium">対象学科</label>
                  <div className="grid grid-cols-2 gap-3">
                    {['トータルモビリティ工学科', '整備科', 'CA/GS科', 'グランドハンドリング学科', '全学科'].map((dept) => (
                      <label key={dept} className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          className="h-4 w-4 rounded border-border text-primary focus:ring-primary"
                          defaultChecked={dept === 'トータルモビリティ工学科'}
                        />
                        <span className="text-sm">{dept}</span>
                      </label>
                    ))}
                  </div>
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium">注意事項</label>
                  <textarea
                    rows={4}
                    className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                    placeholder="来場者への注意事項を入力してください..."
                    defaultValue="・受付は開催時間の30分前から開始します&#10;・キャンパス内は禁煙です&#10;・駐車場は台数に限りがあります"
                  ></textarea>
                  <p className="mt-1 text-xs text-muted-foreground">QRコードに埋め込まれます</p>
                </div>
              </div>
            )}

            {/* Step 2: Exhibitions */}
            {currentStep === 2 && (
              <div className="space-y-6">
                <div className="flex items-center justify-between">
                  <h3 className="text-lg font-semibold">展示/イベント情報</h3>
                  <button
                    onClick={addExhibition}
                    className="flex items-center gap-2 rounded-lg bg-primary px-3 py-1.5 text-sm text-primary-foreground hover:bg-primary/90"
                  >
                    <Plus className="h-4 w-4" />
                    追加
                  </button>
                </div>

                <div className="space-y-4">
                  {exhibitions.map((ex, idx) => (
                    <div key={ex.id} className="rounded-lg border border-border bg-muted/30 p-4">
                      <div className="mb-3 flex items-center justify-between">
                        <span className="text-sm font-medium">イベント {idx + 1}</span>
                        {exhibitions.length > 1 && (
                          <button
                            onClick={() => removeExhibition(ex.id)}
                            className="text-destructive hover:text-destructive/80"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        )}
                      </div>

                      <div className="grid grid-cols-2 gap-3">
                        <div className="col-span-2">
                          <label className="mb-1 block text-xs font-medium">イベント名</label>
                          <input
                            type="text"
                            defaultValue={ex.name}
                            className="w-full rounded-lg border border-border bg-card px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                            placeholder="例: 工学部説明会"
                          />
                        </div>
                        <div>
                          <label className="mb-1 block text-xs font-medium">場所</label>
                          <input
                            type="text"
                            defaultValue={ex.location}
                            className="w-full rounded-lg border border-border bg-card px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                            placeholder="例: 工学部棟A"
                          />
                        </div>
                        <div>
                          <label className="mb-1 block text-xs font-medium">時間</label>
                          <input
                            type="text"
                            defaultValue={ex.time}
                            className="w-full rounded-lg border border-border bg-card px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                            placeholder="例: 10:00-12:00"
                          />
                        </div>
                        <div className="col-span-2">
                          <label className="mb-1 block text-xs font-medium">タグ</label>
                          <input
                            type="text"
                            defaultValue={ex.tags.join(', ')}
                            className="w-full rounded-lg border border-border bg-card px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                            placeholder="カンマ区切りで入力"
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Step 3: Distribution Settings */}
            {currentStep === 3 && (
              <div className="space-y-6">
                <div>
                  <h3 className="text-lg font-semibold mb-4">配布設定</h3>
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium">QR有効期限</label>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <input
                        type="date"
                        defaultValue="2026-02-15"
                        className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                    <div>
                      <input
                        type="time"
                        defaultValue="23:59"
                        className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                  </div>
                  <p className="mt-1 text-xs text-muted-foreground">この日時以降はQRコードが無効になります</p>
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium">発行数</label>
                  <input
                    type="number"
                    defaultValue="500"
                    className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                    placeholder="発行するQRコードの数"
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium">リンク形式</label>
                  <div className="space-y-2">
                    <label className="flex items-center gap-2">
                      <input
                        type="radio"
                        name="linkType"
                        className="h-4 w-4 border-border text-primary focus:ring-primary"
                        defaultChecked
                      />
                      <span className="text-sm">動的QRコード（データベース連携）</span>
                    </label>
                    <label className="flex items-center gap-2">
                      <input
                        type="radio"
                        name="linkType"
                        className="h-4 w-4 border-border text-primary focus:ring-primary"
                      />
                      <span className="text-sm">静的QRコード（情報埋め込み）</span>
                    </label>
                  </div>
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium">表示文言</label>
                  <input
                    type="text"
                    defaultValue="Nexus オープンキャンパス 2026"
                    className="w-full rounded-lg border border-border bg-input-background px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                  />
                </div>

                <div>
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      className="h-4 w-4 rounded border-border text-primary focus:ring-primary"
                      defaultChecked
                    />
                    <span className="text-sm font-medium">短縮URLを生成</span>
                  </label>
                  <p className="ml-6 mt-1 text-xs text-muted-foreground">
                    例: nexus.ac.jp/oc/abc123
                  </p>
                </div>
              </div>
            )}

            {/* Step 4: Preview & Issue */}
            {currentStep === 4 && (
              <div className="space-y-6">
                <div>
                  <h3 className="text-lg font-semibold mb-4">確認 & 発行</h3>
                  <p className="text-sm text-muted-foreground">
                    設定内容を確認して、QRコードを発行してください
                  </p>
                </div>

                <div className="rounded-lg border border-border bg-muted/30 p-4">
                  <div className="space-y-3 text-sm">
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">開催日時:</span>
                      <span className="font-medium">2026年2月15日 09:00-17:00</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">対象学科:</span>
                      <span className="font-medium">トータルモビリティ工学科説明会</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">イベント数:</span>
                      <span className="font-medium">{exhibitions.length}件</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">発行数:</span>
                      <span className="font-medium">500枚</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">有効期限:</span>
                      <span className="font-medium">2026年2月15日 23:59まで</span>
                    </div>
                  </div>
                </div>

                <div className="flex gap-3">
                  <button className="flex flex-1 items-center justify-center gap-2 rounded-lg border border-border bg-card px-4 py-2.5 text-sm font-medium hover:bg-accent">
                    <Save className="h-4 w-4" />
                    下書き保存
                  </button>
                  <button className="flex flex-1 items-center justify-center gap-2 rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:bg-primary/90">
                    <Send className="h-4 w-4" />
                    発行
                  </button>
                  <button className="flex items-center gap-2 rounded-lg border border-border bg-card px-4 py-2.5 text-sm font-medium hover:bg-accent">
                    <Download className="h-4 w-4" />
                    PDF
                  </button>
                </div>
              </div>
            )}

            {/* Navigation Buttons */}
            <div className="mt-8 flex items-center justify-between border-t border-border pt-6">
              <button
                onClick={() => setCurrentStep(Math.max(1, currentStep - 1))}
                disabled={currentStep === 1}
                className="rounded-lg border border-border bg-card px-4 py-2 text-sm font-medium hover:bg-accent disabled:opacity-50 disabled:cursor-not-allowed"
              >
                戻る
              </button>
              <button
                onClick={() => setCurrentStep(Math.min(4, currentStep + 1))}
                disabled={currentStep === 4}
                className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                次へ
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        {/* Preview Panel */}
        <div className="col-span-5">
          <div className="sticky top-24 rounded-2xl border border-border bg-card p-6 shadow-sm">
            <div className="mb-4">
              <h3 className="font-semibold">プレビュー</h3>
              <p className="text-sm text-muted-foreground">QRコードと埋め込みデータ</p>
            </div>

            {/* QR Code Preview */}
            <div className="mb-6 flex justify-center rounded-xl bg-gradient-to-br from-blue-50 to-slate-100 p-8">
              <div className="rounded-2xl bg-white p-6 shadow-lg">
                {/* Simulated QR Code */}
                <div className="h-48 w-48 rounded-lg bg-[linear-gradient(90deg,#000_1px,transparent_1px),linear-gradient(0deg,#000_1px,transparent_1px)] bg-[length:12px_12px] bg-white"></div>
                <div className="mt-4 text-center">
                  <div className="text-sm font-medium">Nexus オープンキャンパス 2026</div>
                  <div className="text-xs text-muted-foreground mt-1">nexus.ac.jp/oc/abc123</div>
                </div>
              </div>
            </div>

            {/* Embedded Metadata */}
            <div className="space-y-3">
              <div className="text-sm font-medium">埋め込みメタデータ</div>
              <div className="rounded-lg bg-muted/50 p-3 font-mono text-xs">
                <div className="space-y-1">
                  <div><span className="text-primary">id:</span> nexus-oc-2026-02</div>
                  <div><span className="text-primary">date:</span> 2026-02-15</div>
                  <div><span className="text-primary">time:</span> 09:00-17:00</div>
                  <div><span className="text-primary">dept:</span> トータルモビリティ工学科</div>
                  <div><span className="text-primary">events:</span> [{exhibitions.length}]</div>
                  <div><span className="text-primary">expires:</span> 2026-02-15T23:59</div>
                </div>
              </div>
            </div>

            <div className="mt-6 rounded-lg border border-primary/20 bg-primary/5 p-3 text-xs">
              <div className="font-medium text-primary mb-1">💡 ヒント</div>
              <div className="text-muted-foreground">
                発行されたQRコードは来場者がスキャンすると、イベント情報とキャンパスマップが表示されます
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
