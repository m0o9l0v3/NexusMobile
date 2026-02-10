import roomsPack from "@/app/map/rooms.v1.json";

type RoomEntry = {
  spotId: string;
  name: string;
  aliases: string[];
};

type RoomsPack = {
  version: string;
  updatedAt: string;
  owner: string;
  source: string;
  operations: {
    headquartersSpotIds: string[];
    staffSpotIds: string[];
    aidSpotIds: string[];
  };
  rooms: RoomEntry[];
};

const normalizedPack = roomsPack as RoomsPack;

function normalize(value: string) {
  return value.trim().toLowerCase().replace(/\s+/g, "");
}

export function resolveRoomToSpotId(input: string): string | undefined {
  const query = normalize(input);
  if (!query) return undefined;

  const exact = normalizedPack.rooms.find((room) => {
    if (normalize(room.name) === query) return true;
    return room.aliases.some((alias) => normalize(alias) === query);
  });
  if (exact) return exact.spotId;

  const partial = normalizedPack.rooms.find((room) => {
    if (normalize(room.name).includes(query)) return true;
    return room.aliases.some((alias) => normalize(alias).includes(query));
  });
  return partial?.spotId;
}

export function getRoomsForQuickPick() {
  return normalizedPack.rooms.map((room) => ({
    spotId: room.spotId,
    name: room.name,
  }));
}

export function getOperationsHeadquartersSpotIds() {
  return normalizedPack.operations.headquartersSpotIds;
}
