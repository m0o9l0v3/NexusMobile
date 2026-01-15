import { isNativeRuntime } from "./runtime";

type Position = {
  latitude: number;
  longitude: number;
  accuracy?: number;
};

export const getCurrentPosition = async (): Promise<Position> => {
  if (isNativeRuntime) {
    const { Geolocation } = await import("@capacitor/geolocation");
    const perm = await Geolocation.requestPermissions();
    if (perm.location === "denied") throw new Error("位置情報が拒否されました");
    const pos = await Geolocation.getCurrentPosition({ enableHighAccuracy: true });
    return {
      latitude: pos.coords.latitude,
      longitude: pos.coords.longitude,
      accuracy: pos.coords.accuracy ?? undefined,
    };
  }

  if (!navigator.geolocation) throw new Error("位置情報が利用できません");
  return new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(
      (pos) =>
        resolve({
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
          accuracy: pos.coords.accuracy ?? undefined,
        }),
      (err) => reject(err),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 5000 },
    );
  });
};
