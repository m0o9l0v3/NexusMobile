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

