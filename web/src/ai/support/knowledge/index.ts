import exhibitsV1 from "@/ai/support/knowledge/exhibits.v1.json";
import troublesV1 from "@/ai/support/knowledge/troubles.v1.json";
import type { ExhibitKnowledgePack, TroubleKnowledgePack } from "@/ai/support/types";

export const exhibitsPack = exhibitsV1 as ExhibitKnowledgePack;
export const troublesPack = troublesV1 as TroubleKnowledgePack;

export function getExhibitBySpotName(spotName: string) {
  return exhibitsPack.exhibits.find((e) => e.spotName === spotName);
}

export function findExhibitsByQuery(query: string) {
  const q = query.trim();
  if (!q) return exhibitsPack.exhibits;
  return exhibitsPack.exhibits.filter((e) =>
    (e.title + " " + e.spotName).toLowerCase().includes(q.toLowerCase())
  );
}

export function getTroubleFlow(flowId: string) {
  return troublesPack.flows.find((f) => f.id === flowId);
}

export function getTroubleNode(flowId: string, nodeId: string) {
  const flow = getTroubleFlow(flowId);
  return flow?.nodes.find((n) => n.id === nodeId);
}

