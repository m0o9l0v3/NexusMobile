import { useEffect, useMemo, useState } from "react";
import { AnimatePresence, motion } from "motion/react";
import {
  ArrowLeft,
  ExternalLink,
  HelpCircle,
  MapPin,
  MessageCircleWarning,
  Search,
  X,
} from "lucide-react";
import {
  exhibitsPack,
  findExhibitsByQuery,
  getExhibitBySpotName,
  getTroubleFlow,
  getTroubleNode,
  troublesPack,
} from "@/ai/support/knowledge";
import type { SupportAction, TroubleUrgency } from "@/ai/support/types";

type SupportSheetProps = {
  isOpen: boolean;
  onClose: () => void;
  onStartMapPick: () => void;
  onOpenSpotOnMap: (spotName: string) => void;
  pickedSpotName?: string;
};

type View =
  | { kind: "home" }
  | { kind: "exhibit"; exhibitId?: string }
  | { kind: "trouble"; flowId?: string; nodeId?: string }
  | { kind: "handoff"; urgency: TroubleUrgency; reason: string };

export function SupportSheet({
  isOpen,
  onClose,
  onStartMapPick,
  onOpenSpotOnMap,
  pickedSpotName,
}: SupportSheetProps) {
  const [view, setView] = useState<View>({ kind: "home" });
  const [exhibitQuery, setExhibitQuery] = useState("");
  const [awaitingMapPick, setAwaitingMapPick] = useState(false);

  const exhibits = useMemo(() => findExhibitsByQuery(exhibitQuery), [exhibitQuery]);

  const selectedExhibit = useMemo(() => {
    if (view.kind !== "exhibit" || !view.exhibitId) return undefined;
    return exhibitsPack.exhibits.find((e) => e.id === view.exhibitId);
  }, [view]);

  useEffect(() => {
    if (!isOpen) return;
    if (!awaitingMapPick) return;
    if (!pickedSpotName) return;

    const exhibit = getExhibitBySpotName(pickedSpotName);
    if (exhibit) {
      setView({ kind: "exhibit", exhibitId: exhibit.id });
      setExhibitQuery("");
    }
    setAwaitingMapPick(false);
  }, [isOpen, awaitingMapPick, pickedSpotName]);

  const executeAction = (action: SupportAction) => {
    switch (action.type) {
      case "openSpot":
        onOpenSpotOnMap(action.spotName);
        onClose();
        return;
      case "startMapPick":
        setAwaitingMapPick(true);
        onStartMapPick();
        onClose();
        return;
      case "handoff":
        setView({ kind: "handoff", urgency: action.urgency, reason: action.reason });
        return;
      case "restart":
        setView({ kind: "home" });
        setAwaitingMapPick(false);
        return;
    }
  };

  const troubleFlow = view.kind === "trouble" && view.flowId ? getTroubleFlow(view.flowId) : undefined;
  const troubleNode =
    view.kind === "trouble" && view.flowId && view.nodeId
      ? getTroubleNode(view.flowId, view.nodeId)
      : undefined;

  const openTroubleFlow = (flowId: string) => {
    const flow = getTroubleFlow(flowId);
    if (!flow) return;
    setView({ kind: "trouble", flowId: flow.id, nodeId: flow.startNodeId });
  };

  const headerTitle =
    view.kind === "home"
      ? "サポート"
      : view.kind === "exhibit"
      ? "展示について"
      : view.kind === "trouble"
      ? "困ったとき"
      : "運営に繋ぐ";

  const canGoBack = view.kind !== "home";
  const onBack = () => {
    if (view.kind === "handoff") return setView({ kind: "home" });
    if (view.kind === "trouble") return setView({ kind: "home" });
    if (view.kind === "exhibit") return setView({ kind: "home" });
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div
            className="absolute inset-0 z-50 bg-black/20"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />

          <motion.div
            className="absolute bottom-0 left-0 right-0 z-[60] rounded-t-3xl overflow-hidden"
            style={{
              backgroundColor: "var(--surface)",
              boxShadow: "var(--elev-3)",
              maxHeight: "78vh",
            }}
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", damping: 30, stiffness: 300 }}
          >
            <div className="flex justify-center pt-3 pb-2">
              <div className="w-10 h-1 rounded-full" style={{ backgroundColor: "var(--outline)" }} />
            </div>

            <div
              className="flex items-center justify-between px-4 pb-3 border-b"
              style={{ borderColor: "var(--outline)" }}
            >
              <div className="flex items-center gap-2">
                {canGoBack ? (
                  <button
                    onClick={onBack}
                    className="w-9 h-9 rounded-full flex items-center justify-center"
                    style={{ backgroundColor: "transparent", color: "var(--text)" }}
                    title="戻る"
                  >
                    <ArrowLeft size={20} />
                  </button>
                ) : (
                  <div
                    className="w-9 h-9 rounded-full flex items-center justify-center"
                    style={{ backgroundColor: "var(--muted)", color: "var(--primary)" }}
                  >
                    <HelpCircle size={18} />
                  </div>
                )}
                <div>
                  <div className="text-sm font-medium" style={{ color: "var(--text)" }}>
                    {headerTitle}
                  </div>
                  <div className="text-[11px]" style={{ color: "var(--muted-foreground)" }}>
                    回答は概要のみです。詳細は現地スタッフへ。
                  </div>
                </div>
              </div>

              <button
                onClick={onClose}
                className="w-9 h-9 rounded-full flex items-center justify-center"
                style={{ backgroundColor: "transparent", color: "var(--text)" }}
                title="閉じる"
              >
                <X size={20} />
              </button>
            </div>

            <div className="px-4 pb-5 overflow-y-auto" style={{ maxHeight: "calc(78vh - 88px)" }}>
              {view.kind === "home" && (
                <div className="pt-4 space-y-3">
                  <button
                    onClick={() => setView({ kind: "exhibit" })}
                    className="w-full p-4 rounded-2xl text-left"
                    style={{ backgroundColor: "var(--muted)", color: "var(--text)" }}
                  >
                    <div className="flex items-center gap-3">
                      <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center"
                        style={{ backgroundColor: "var(--surface)", boxShadow: "var(--elev-1)" }}
                      >
                        <Search size={18} style={{ color: "var(--primary)" }} />
                      </div>
                      <div className="flex-1">
                        <div className="font-medium">展示について聞く</div>
                        <div className="text-xs mt-1" style={{ color: "var(--muted-foreground)" }}>
                          展示の概要と、現地で聞くと良い質問を提示します
                        </div>
                      </div>
                    </div>
                  </button>

                  <button
                    onClick={() => setView({ kind: "trouble" })}
                    className="w-full p-4 rounded-2xl text-left"
                    style={{ backgroundColor: "var(--muted)", color: "var(--text)" }}
                  >
                    <div className="flex items-center gap-3">
                      <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center"
                        style={{ backgroundColor: "var(--surface)", boxShadow: "var(--elev-1)" }}
                      >
                        <MessageCircleWarning size={18} style={{ color: "var(--primary)" }} />
                      </div>
                      <div className="flex-1">
                        <div className="font-medium">困ったとき</div>
                        <div className="text-xs mt-1" style={{ color: "var(--muted-foreground)" }}>
                          迷子・端末不具合・体調不良を分岐で案内します
                        </div>
                      </div>
                    </div>
                  </button>

                  <div className="pt-2">
                    <button
                      onClick={() => setView({ kind: "handoff", urgency: "normal", reason: "manual" })}
                      className="w-full py-3 rounded-2xl font-medium"
                      style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}
                    >
                      運営に繋ぐ
                    </button>
                    <div className="text-[11px] mt-2" style={{ color: "var(--muted-foreground)" }}>
                      緊急時は近くのスタッフへ。体調不良は遠慮なく連絡してください。
                    </div>
                  </div>
                </div>
              )}

              {view.kind === "exhibit" && (
                <div className="pt-4 space-y-4">
                  <div className="space-y-2">
                    <div className="flex items-center gap-2">
                      <div className="flex-1">
                        <div className="text-xs font-medium" style={{ color: "var(--muted-foreground)" }}>
                          展示/教室名で選択
                        </div>
                        <div className="mt-1 flex items-center gap-2">
                          <input
                            value={exhibitQuery}
                            onChange={(e) => setExhibitQuery(e.target.value)}
                            placeholder="例: 実験室B / 図書館"
                            className="flex-1 px-3 py-2.5 rounded-2xl text-sm outline-none"
                            style={{ backgroundColor: "var(--muted)", color: "var(--text)" }}
                          />
                          <button
                            onClick={() => executeAction({ type: "startMapPick", mode: "exhibit" })}
                            className="px-3 py-2.5 rounded-2xl text-sm font-medium flex items-center gap-1"
                            style={{ backgroundColor: "var(--surface)", color: "var(--primary)", boxShadow: "var(--elev-1)" }}
                            title="マップで選択"
                          >
                            <MapPin size={16} />
                            <span>マップ</span>
                          </button>
                        </div>
                        {awaitingMapPick && (
                          <div className="text-[11px] mt-2" style={{ color: "var(--muted-foreground)" }}>
                            マップで展示をタップしてください（対応する展示がある場合に自動選択します）
                          </div>
                        )}
                      </div>
                    </div>

                    <div className="space-y-2">
                      {exhibits.slice(0, 6).map((exhibit) => (
                        <button
                          key={exhibit.id}
                          onClick={() => setView({ kind: "exhibit", exhibitId: exhibit.id })}
                          className="w-full p-3 rounded-2xl text-left"
                          style={{
                            backgroundColor: view.kind === "exhibit" && view.exhibitId === exhibit.id ? "var(--primary-weak)" : "var(--muted)",
                            color: "var(--text)",
                          }}
                        >
                          <div className="flex items-center justify-between gap-3">
                            <div className="min-w-0">
                              <div className="text-sm font-medium truncate">{exhibit.title}</div>
                              <div className="text-xs mt-1" style={{ color: "var(--muted-foreground)" }}>
                                {exhibit.spotName}
                              </div>
                            </div>
                            <ExternalLink size={16} style={{ color: "var(--muted-foreground)" }} />
                          </div>
                        </button>
                      ))}
                    </div>
                  </div>

                  {selectedExhibit && (
                    <div
                      className="p-4 rounded-2xl space-y-3"
                      style={{ backgroundColor: "var(--surface)", boxShadow: "var(--elev-2)" }}
                    >
                      <div>
                        <div className="text-sm font-medium" style={{ color: "var(--text)" }}>
                          {selectedExhibit.title}
                        </div>
                        <div className="text-xs mt-1 flex items-center gap-1" style={{ color: "var(--muted-foreground)" }}>
                          <MapPin size={12} />
                          <span>{selectedExhibit.spotName}</span>
                        </div>
                      </div>

                      <div>
                        <div className="text-xs font-medium" style={{ color: "var(--muted-foreground)" }}>
                          概要
                        </div>
                        <div className="text-sm mt-1" style={{ color: "var(--text)" }}>
                          {selectedExhibit.overview}
                        </div>
                      </div>

                      <div>
                        <div className="text-xs font-medium" style={{ color: "var(--muted-foreground)" }}>
                          見どころ
                        </div>
                        <ul className="mt-1 space-y-1">
                          {selectedExhibit.highlights.map((h, i) => (
                            <li key={i} className="text-sm" style={{ color: "var(--text)" }}>
                              ・{h}
                            </li>
                          ))}
                        </ul>
                      </div>

                      <div>
                        <div className="text-xs font-medium" style={{ color: "var(--muted-foreground)" }}>
                          現地で聞くと良い質問
                        </div>
                        <ul className="mt-1 space-y-1">
                          {selectedExhibit.askOnsite.map((q, i) => (
                            <li key={i} className="text-sm" style={{ color: "var(--text)" }}>
                              ・{q}
                            </li>
                          ))}
                        </ul>
                      </div>

                      <div
                        className="p-3 rounded-2xl"
                        style={{ backgroundColor: "var(--muted)", color: "var(--text)" }}
                      >
                        <div className="text-sm">{selectedExhibit.cta}</div>
                      </div>

                      <div className="flex gap-2">
                        <button
                          onClick={() => onOpenSpotOnMap(selectedExhibit.spotName)}
                          className="flex-1 py-3 rounded-2xl font-medium"
                          style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}
                        >
                          マップで場所を見る
                        </button>
                        <button
                          onClick={() => setView({ kind: "handoff", urgency: "normal", reason: "exhibit_question" })}
                          className="flex-1 py-3 rounded-2xl font-medium"
                          style={{ backgroundColor: "var(--muted)", color: "var(--text)" }}
                        >
                          運営に繋ぐ
                        </button>
                      </div>

                      <div className="text-[11px]" style={{ color: "var(--muted-foreground)" }}>
                        データ: exhibits@{exhibitsPack.version}（{exhibitsPack.updatedAt}）
                      </div>
                    </div>
                  )}
                </div>
              )}

              {view.kind === "trouble" && !troubleFlow && (
                <div className="pt-4 space-y-3">
                  {troublesPack.flows.map((flow) => (
                    <button
                      key={flow.id}
                      onClick={() => openTroubleFlow(flow.id)}
                      className="w-full p-4 rounded-2xl text-left"
                      style={{ backgroundColor: "var(--muted)", color: "var(--text)" }}
                    >
                      <div className="font-medium">{flow.title}</div>
                      <div className="text-xs mt-1" style={{ color: "var(--muted-foreground)" }}>
                        選択式で案内します
                      </div>
                    </button>
                  ))}
                  <div className="pt-2">
                    <button
                      onClick={() => setView({ kind: "handoff", urgency: "normal", reason: "trouble_manual" })}
                      className="w-full py-3 rounded-2xl font-medium"
                      style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}
                    >
                      すぐ運営に繋ぐ
                    </button>
                    <div className="text-[11px] mt-2" style={{ color: "var(--muted-foreground)" }}>
                      データ: troubles@{troublesPack.version}（{troublesPack.updatedAt}）
                    </div>
                  </div>
                </div>
              )}

              {view.kind === "trouble" && troubleFlow && troubleNode && (
                <div className="pt-4 space-y-4">
                  <div className="text-xs font-medium" style={{ color: "var(--muted-foreground)" }}>
                    {troubleFlow.title}
                  </div>
                  <div
                    className="p-4 rounded-2xl"
                    style={{ backgroundColor: "var(--surface)", boxShadow: "var(--elev-2)" }}
                  >
                    <div className="text-sm" style={{ color: "var(--text)" }}>
                      {troubleNode.message}
                    </div>
                    <div className="pt-3 space-y-2">
                      {troubleNode.options.map((opt) => (
                        <button
                          key={opt.id}
                          onClick={() => {
                            if (opt.action) return executeAction(opt.action);
                            if (opt.nextNodeId) return setView({ kind: "trouble", flowId: troubleFlow.id, nodeId: opt.nextNodeId });
                          }}
                          className="w-full px-4 py-3 rounded-2xl text-left"
                          style={{ backgroundColor: "var(--muted)", color: "var(--text)" }}
                        >
                          {opt.label}
                        </button>
                      ))}
                    </div>
                  </div>
                  <button
                    onClick={() => setView({ kind: "handoff", urgency: "normal", reason: "trouble_fallback" })}
                    className="w-full py-3 rounded-2xl font-medium"
                    style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}
                  >
                    運営に繋ぐ
                  </button>
                </div>
              )}

              {view.kind === "handoff" && (
                <div className="pt-4 space-y-3">
                  <div
                    className="p-4 rounded-2xl"
                    style={{ backgroundColor: "var(--muted)", color: "var(--text)" }}
                  >
                    <div className="font-medium">
                      {view.urgency === "high" ? "緊急度: 高" : "緊急度: 通常"}
                    </div>
                    <div className="text-sm mt-2" style={{ color: "var(--text)" }}>
                      近くのスタッフに声をかけてください。必要なら受付でも対応できます。
                    </div>
                    <div className="text-[11px] mt-2" style={{ color: "var(--muted-foreground)" }}>
                      理由: {view.reason}
                    </div>
                  </div>

                  <button
                    onClick={() => onOpenSpotOnMap("受付")}
                    className="w-full py-3 rounded-2xl font-medium"
                    style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}
                  >
                    受付をマップで開く
                  </button>
                  <button
                    onClick={() => setView({ kind: "home" })}
                    className="w-full py-3 rounded-2xl font-medium"
                    style={{ backgroundColor: "var(--muted)", color: "var(--text)" }}
                  >
                    サポートに戻る
                  </button>
                </div>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

