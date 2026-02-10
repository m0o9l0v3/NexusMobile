import { useEffect, useMemo, useState } from "react";
import { AnimatePresence, motion } from "motion/react";
import { ArrowLeft, HelpCircle, MapPin, Search, X } from "lucide-react";
import {
  exhibitsPack,
  findExhibitsByQuery,
  getExhibitBySpotName,
  getTroubleFlow,
  getTroubleNode,
  troublesPack,
} from "@/ai/support/knowledge";
import { logSupportEvent } from "@/ai/support/logger";
import type {
  FallbackReason,
  HandoffPayload,
  SupportAction,
  SupportCategory,
  TroubleUrgency,
} from "@/ai/support/types";
import {
  getOperationsHeadquartersSpotIds,
  getRoomsForQuickPick,
  resolveRoomToSpotId,
} from "@/app/map/rooms";

type SupportSheetProps = {
  isOpen: boolean;
  onClose: () => void;
  onStartMapPick: () => void;
  onOpenSpotOnMap: (target: { spotId?: string; spotName?: string }) => void;
  pickedSpotName?: string;
};

type View =
  | { kind: "home" }
  | { kind: "exhibit"; exhibitId?: string }
  | { kind: "troubleMenu" }
  | { kind: "troubleFlow"; flowId: string; nodeId: string }
  | { kind: "fallback"; reason: FallbackReason; details: string[] }
  | { kind: "handoff"; payload: HandoffPayload; emergencyHint: boolean };

const emergencyKeywords = [
  "意識がない",
  "呼吸が苦しい",
  "激しい胸痛",
  "けいれん",
  "大量出血",
];

const panelStyle = {
  backgroundColor: "var(--surface)",
  boxShadow: "var(--elev-2)",
} as const;

function newConversationId() {
  return `conv-${Date.now().toString(36)}-${Math.random()
    .toString(36)
    .slice(2, 8)}`;
}

function inferCategory(reason: string): SupportCategory {
  if (reason.startsWith("device")) return "device";
  if (reason.startsWith("lost")) return "lost";
  if (reason.startsWith("health")) return "health";
  return "other";
}

function summaryTemplate(category: SupportCategory) {
  if (category === "device") return "端末不具合の一次対応を実施済み。運営で端末確認をお願いします。";
  if (category === "lost") return "迷子/現在地不明の相談。場所案内が必要です。";
  if (category === "health") return "体調不良の相談。安全確保を優先してください。";
  return "未対応カテゴリの相談。内容確認をお願いします。";
}

export function SupportSheet({
  isOpen,
  onClose,
  onStartMapPick,
  onOpenSpotOnMap,
  pickedSpotName,
}: SupportSheetProps) {
  const [view, setView] = useState<View>({ kind: "home" });
  const [conversationId, setConversationId] = useState(newConversationId);
  const [query, setQuery] = useState("");
  const [awaitingMapPick, setAwaitingMapPick] = useState(false);
  const [nearbyRoomText, setNearbyRoomText] = useState("");
  const [healthText, setHealthText] = useState("");
  const [selectionTrail, setSelectionTrail] = useState<string[]>([]);

  const operationsSpotId = getOperationsHeadquartersSpotIds()[0];
  const quickRooms = useMemo(() => getRoomsForQuickPick().slice(0, 6), []);
  const exhibits = useMemo(() => findExhibitsByQuery(query), [query]);
  const selectedExhibit = useMemo(() => {
    if (view.kind !== "exhibit" || !view.exhibitId) return undefined;
    return exhibitsPack.exhibits.find((item) => item.id === view.exhibitId);
  }, [view]);
  const flow = view.kind === "troubleFlow" ? getTroubleFlow(view.flowId) : undefined;
  const node = view.kind === "troubleFlow" ? getTroubleNode(view.flowId, view.nodeId) : undefined;

  useEffect(() => {
    if (!isOpen) return;
    setConversationId(newConversationId());
    logSupportEvent("support_opened");
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen || !awaitingMapPick || !pickedSpotName) return;
    const exhibit = getExhibitBySpotName(pickedSpotName);
    if (!exhibit) {
      triggerFallback("missing_required_info", [`pickedSpot:${pickedSpotName}`]);
      setAwaitingMapPick(false);
      return;
    }
    setView({ kind: "exhibit", exhibitId: exhibit.id });
    setAwaitingMapPick(false);
  }, [isOpen, awaitingMapPick, pickedSpotName]);

  const openMapGuidance = (target: { spotId?: string; spotName?: string }, reason: string) => {
    logSupportEvent("map_guidance_opened", { reason, spotId: target.spotId, spotName: target.spotName });
    onOpenSpotOnMap(target);
    onClose();
  };

  const triggerFallback = (reason: FallbackReason, details: string[] = []) => {
    logSupportEvent("fallback_triggered", { reason, details });
    setView({ kind: "fallback", reason, details });
  };

  const buildHandoff = (
    category: SupportCategory,
    urgency: TroubleUrgency,
    reason: string,
    details: string[]
  ) => {
    const emergencyHint = category === "health" && emergencyKeywords.some((kw) => healthText.includes(kw));
    if (category === "health" || emergencyHint) {
      logSupportEvent("fallback_triggered", { reason: "health_or_emergency" });
    }
    const payload: HandoffPayload = {
      conversationId,
      category,
      summary: summaryTemplate(category),
      details: details.filter(Boolean),
      location: {
        spotId: nearbyRoomText ? resolveRoomToSpotId(nearbyRoomText) : undefined,
        nearbyRoomText: nearbyRoomText || undefined,
      },
      urgency: category === "health" ? "high" : urgency,
      timestamp: new Date().toISOString(),
    };
    logSupportEvent("handoff_sent", { mode: "copy_prompt", category: payload.category, reason });
    setView({ kind: "handoff", payload, emergencyHint });
  };

  const executeAction = (action: SupportAction, labels: string[] = []) => {
    if (action.type === "openSpot") {
      openMapGuidance({ spotName: action.spotName }, "action_open_spot");
      return;
    }
    if (action.type === "startMapPick") {
      setAwaitingMapPick(true);
      onStartMapPick();
      onClose();
      return;
    }
    if (action.type === "handoff") {
      buildHandoff(inferCategory(action.reason), action.urgency, action.reason, labels);
      return;
    }
    setView({ kind: "home" });
    setSelectionTrail([]);
    setNearbyRoomText("");
    setHealthText("");
    setAwaitingMapPick(false);
  };

  const openFlow = (flowId: string) => {
    const target = getTroubleFlow(flowId);
    if (!target) {
      triggerFallback("unknown_intent", [`flow:${flowId}`]);
      return;
    }
    logSupportEvent("category_selected", { category: flowId });
    setSelectionTrail([]);
    setView({ kind: "troubleFlow", flowId: target.id, nodeId: target.startNodeId });
  };

  const resolveLostRoom = () => {
    const room = nearbyRoomText.trim();
    if (!room) {
      logSupportEvent("fallback_triggered", {
        reason: "missing_required_info",
        details: ["lost:empty_room"],
      });
      buildHandoff("lost", "normal", "lost_missing_room", ["lost:empty_room"]);
      return;
    }
    const spotId = resolveRoomToSpotId(room);
    if (!spotId) {
      logSupportEvent("fallback_triggered", {
        reason: "missing_required_info",
        details: [`lost:unresolved:${room}`],
      });
      buildHandoff("lost", "normal", "lost_unresolved_room", [
        `lost:unresolved:${room}`,
      ]);
      return;
    }
    openMapGuidance({ spotId }, "lost_room_resolved");
  };

  const copyPayload = async (payload: HandoffPayload) => {
    try {
      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));
      logSupportEvent("handoff_sent", { mode: "copied", category: payload.category });
    } catch {
      // ignore clipboard errors
    }
  };

  const fallbackMessage =
    view.kind !== "fallback"
      ? ""
      : view.reason === "unknown_intent"
      ? "内容を分類できません。選択式メニューへ切り替えます。"
      : view.reason === "missing_required_info"
      ? "必要情報が不足しています。運営導線へ切り替えます。"
      : "安全優先で運営に引継ぎます。";

  const headerTitle =
    view.kind === "home"
      ? "サポート"
      : view.kind === "exhibit"
      ? "展示QA"
      : view.kind === "handoff"
      ? "運営引継ぎ"
      : "困ったとき";

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div className="absolute inset-0 z-50 bg-black/20" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose} />
          <motion.div
            className="absolute bottom-0 left-0 right-0 z-[60] rounded-t-3xl overflow-hidden"
            style={{ backgroundColor: "var(--surface)", boxShadow: "var(--elev-3)", maxHeight: "78vh" }}
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", damping: 30, stiffness: 300 }}
          >
            <div className="flex justify-center pt-3 pb-2"><div className="w-10 h-1 rounded-full" style={{ backgroundColor: "var(--outline)" }} /></div>
            <div className="flex items-center justify-between px-4 pb-3 border-b" style={{ borderColor: "var(--outline)" }}>
              <div className="flex items-center gap-2">
                {view.kind === "home" ? (
                  <div className="w-9 h-9 rounded-full flex items-center justify-center" style={{ backgroundColor: "var(--muted)", color: "var(--primary)" }}><HelpCircle size={18} /></div>
                ) : (
                  <button onClick={() => setView({ kind: "home" })} className="w-9 h-9 rounded-full flex items-center justify-center" title="戻る"><ArrowLeft size={20} /></button>
                )}
                <div>
                  <div className="text-sm font-medium" style={{ color: "var(--text)" }}>{headerTitle}</div>
                  <div className="text-[11px]" style={{ color: "var(--muted-foreground)" }}>固定テンプレ中心で案内し、必要時は運営へ引継ぎます。</div>
                </div>
              </div>
              <button onClick={onClose} className="w-9 h-9 rounded-full flex items-center justify-center" title="閉じる"><X size={20} /></button>
            </div>

            <div className="px-4 pb-5 overflow-y-auto" style={{ maxHeight: "calc(78vh - 88px)" }}>
              {view.kind === "home" && (
                <div className="pt-4 space-y-3">
                  <button onClick={() => setView({ kind: "exhibit" })} className="w-full p-4 rounded-2xl text-left" style={{ backgroundColor: "var(--muted)" }}>展示について聞く</button>
                  <button onClick={() => setView({ kind: "troubleMenu" })} className="w-full p-4 rounded-2xl text-left" style={{ backgroundColor: "var(--muted)" }}>困ったとき</button>
                  <button onClick={() => triggerFallback("unknown_intent", ["home:other"])} className="w-full p-4 rounded-2xl text-left" style={{ backgroundColor: "var(--muted)" }}>その他（未対応）</button>
                </div>
              )}

              {view.kind === "exhibit" && (
                <div className="pt-4 space-y-3">
                  <div className="flex gap-2">
                    <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="展示名/教室名で検索" className="flex-1 px-3 py-2.5 rounded-2xl text-sm outline-none" style={{ backgroundColor: "var(--muted)" }} />
                    <button onClick={() => executeAction({ type: "startMapPick", mode: "exhibit" })} className="px-3 py-2.5 rounded-2xl text-sm" style={panelStyle}><MapPin size={14} /></button>
                  </div>
                  {exhibits.slice(0, 6).map((item) => (
                    <button key={item.id} onClick={() => setView({ kind: "exhibit", exhibitId: item.id })} className="w-full p-3 rounded-2xl text-left" style={{ backgroundColor: "var(--muted)" }}>
                      <div className="font-medium">{item.title}</div>
                      <div className="text-xs" style={{ color: "var(--muted-foreground)" }}>{item.spotName}</div>
                    </button>
                  ))}
                  {selectedExhibit && (
                    <div className="p-3 rounded-2xl space-y-2" style={panelStyle}>
                      <div className="font-medium">{selectedExhibit.title}</div>
                      <div className="text-sm">{selectedExhibit.overview}</div>
                      <div className="text-xs" style={{ color: "var(--muted-foreground)" }}>{selectedExhibit.cta}</div>
                      <div className="flex gap-2">
                        <button onClick={() => openMapGuidance({ spotName: selectedExhibit.spotName }, "exhibit_map")} className="flex-1 py-2.5 rounded-2xl font-medium" style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}>場所を開く</button>
                        <button onClick={() => buildHandoff("other", "normal", "exhibit_question", [`exhibit:${selectedExhibit.title}`])} className="flex-1 py-2.5 rounded-2xl font-medium" style={{ backgroundColor: "var(--muted)" }}>運営へ</button>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {view.kind === "troubleMenu" && (
                <div className="pt-4 space-y-3">
                  {troublesPack.flows.map((item) => (
                    <button key={item.id} onClick={() => openFlow(item.id)} className="w-full p-4 rounded-2xl text-left" style={{ backgroundColor: "var(--muted)" }}>{item.title}</button>
                  ))}
                  <button onClick={() => triggerFallback("unknown_intent", ["trouble:other"])} className="w-full p-4 rounded-2xl text-left" style={{ backgroundColor: "var(--muted)" }}>その他（運営へ）</button>
                </div>
              )}

              {view.kind === "troubleFlow" && flow && node && (
                <div className="pt-4 space-y-3">
                  <div className="p-3 rounded-2xl space-y-3" style={panelStyle}>
                    <div className="text-sm">{node.message}</div>
                    {flow.id === "lost" && node.id === "lost.destination" && (
                      <>
                        <input value={nearbyRoomText} onChange={(e) => setNearbyRoomText(e.target.value)} placeholder="近くの教室名" className="w-full px-3 py-2.5 rounded-2xl text-sm outline-none" style={{ backgroundColor: "var(--muted)" }} />
                        <div className="flex gap-2 overflow-x-auto">
                          {quickRooms.map((room) => (
                            <button key={room.spotId} onClick={() => setNearbyRoomText(room.name)} className="px-3 py-1.5 rounded-full text-xs whitespace-nowrap" style={{ backgroundColor: "var(--muted)" }}>{room.name}</button>
                          ))}
                        </div>
                        <button onClick={resolveLostRoom} className="w-full py-2.5 rounded-2xl font-medium" style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}>地図で案内</button>
                      </>
                    )}
                    {flow.id === "health" && (
                      <input value={healthText} onChange={(e) => setHealthText(e.target.value)} placeholder="症状メモ（任意）" className="w-full px-3 py-2.5 rounded-2xl text-sm outline-none" style={{ backgroundColor: "var(--muted)" }} />
                    )}
                    {node.options.map((opt) => (
                      <button
                        key={opt.id}
                        onClick={() => {
                          const nextTrail = [...selectionTrail, opt.label];
                          setSelectionTrail(nextTrail);
                          if (opt.action) return executeAction(opt.action, nextTrail);
                          if (opt.nextNodeId) return setView({ kind: "troubleFlow", flowId: flow.id, nodeId: opt.nextNodeId });
                          return triggerFallback("unknown_intent", [`node:${node.id}`]);
                        }}
                        className="w-full px-4 py-2.5 rounded-2xl text-left"
                        style={{ backgroundColor: "var(--muted)" }}
                      >
                        {opt.label}
                      </button>
                    ))}
                  </div>
                  <button onClick={() => buildHandoff(flow.id as SupportCategory, flow.id === "health" ? "high" : "normal", `${flow.id}_manual_handoff`, selectionTrail)} className="w-full py-3 rounded-2xl font-medium" style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}>運営につなぐ</button>
                </div>
              )}

              {view.kind === "fallback" && (
                <div className="pt-4 space-y-3">
                  <div className="p-3 rounded-2xl text-sm" style={panelStyle}>{fallbackMessage}</div>
                  <button onClick={() => openFlow("device")} className="w-full p-3 rounded-2xl text-left" style={{ backgroundColor: "var(--muted)" }}>端末不具合</button>
                  <button onClick={() => openFlow("lost")} className="w-full p-3 rounded-2xl text-left" style={{ backgroundColor: "var(--muted)" }}>迷子</button>
                  <button onClick={() => openFlow("health")} className="w-full p-3 rounded-2xl text-left" style={{ backgroundColor: "var(--muted)" }}>体調不良</button>
                  <button onClick={() => buildHandoff("other", "normal", "fallback_other", view.details)} className="w-full py-3 rounded-2xl font-medium" style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}>運営につなぐ</button>
                </div>
              )}

              {view.kind === "handoff" && (
                <div className="pt-4 space-y-3">
                  <div className="text-xs font-medium" style={{ color: "var(--muted-foreground)" }}>1) 場所誘導</div>
                  <button onClick={() => openMapGuidance({ spotId: operationsSpotId, spotName: "受付" }, "handoff_guidance")} className="w-full py-3 rounded-2xl font-medium" style={{ backgroundColor: "var(--primary)", color: "var(--primary-foreground)" }}>受付/運営本部へ誘導する</button>
                  <div className="text-xs font-medium" style={{ color: "var(--muted-foreground)" }}>2) AIからの引継ぎ</div>
                  <div className="p-3 rounded-2xl text-[11px] whitespace-pre-wrap break-all" style={panelStyle}>{JSON.stringify(view.payload, null, 2)}</div>
                  <button onClick={() => copyPayload(view.payload)} className="w-full py-3 rounded-2xl font-medium" style={{ backgroundColor: "var(--muted)" }}>引継ぎペイロードをコピー</button>
                  <div className="text-xs font-medium" style={{ color: "var(--muted-foreground)" }}>3) Webアプリ内チャット</div>
                  <div className="p-3 rounded-2xl text-sm" style={{ backgroundColor: "var(--muted)", color: "var(--muted-foreground)" }}>今後追加予定</div>
                  {view.emergencyHint && (
                    <div className="p-3 rounded-2xl text-sm" style={{ backgroundColor: "var(--muted)" }}>
                      周囲のスタッフへ助けを求めてください。緊急性が高い場合は119番を検討してください。
                    </div>
                  )}
                </div>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
