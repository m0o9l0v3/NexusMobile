export type KnowledgeMeta = {
  version: string;
  updatedAt: string; // YYYY-MM-DD
  owner: string;
  source: string;
};

export type Exhibit = {
  id: string;
  title: string;
  spotName: string;
  overview: string;
  highlights: string[];
  askOnsite: string[];
  cta: string;
};

export type ExhibitKnowledgePack = KnowledgeMeta & {
  exhibits: Exhibit[];
};

export type TroubleUrgency = "normal" | "high";

export type SupportCategory = "device" | "lost" | "health" | "other";

export type FallbackReason =
  | "unknown_intent"
  | "missing_required_info"
  | "health_or_emergency";

export type SupportAction =
  | { type: "openSpot"; spotName: string }
  | { type: "startMapPick"; mode: "exhibit" }
  | { type: "handoff"; urgency: TroubleUrgency; reason: string }
  | { type: "restart" };

export type TroubleOption = {
  id: string;
  label: string;
  nextNodeId?: string;
  action?: SupportAction;
};

export type TroubleNode = {
  id: string;
  message: string;
  options: TroubleOption[];
};

export type TroubleFlow = {
  id: string;
  title: string;
  startNodeId: string;
  nodes: TroubleNode[];
};

export type TroubleKnowledgePack = KnowledgeMeta & {
  flows: TroubleFlow[];
};

export type HandoffPayload = {
  conversationId: string;
  category: SupportCategory;
  summary: string;
  details: string[];
  location: {
    spotId?: string;
    nearbyRoomText?: string;
  };
  urgency: TroubleUrgency;
  timestamp: string;
};

export type SupportEventName =
  | "support_opened"
  | "category_selected"
  | "fallback_triggered"
  | "handoff_sent"
  | "map_guidance_opened";

