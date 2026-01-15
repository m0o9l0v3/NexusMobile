import { startQrScan } from "./qr";
import { isNativeRuntime } from "./runtime";

export type QrResultHandler = (text: string) => void;
export type QrErrorHandler = (reason: string) => void;
export type QrHandle = Awaited<ReturnType<typeof startQrScan>>;

/**
 * Web: 現行の getUserMedia + qr-scanner を利用。
 * Native: ひとまず Web と同じ方式で動作させ、将来 Capacitor Camera に差し替え可能な形にしてある。
 */
export const startQr = async (
  videoEl: HTMLVideoElement,
  onResult: QrResultHandler,
  onError: QrErrorHandler,
): Promise<QrHandle | null> => {
  if (isNativeRuntime) {
    // TODO: 将来的に @capacitor/camera を使った読み取りに差し替え
    return startQrScan(videoEl, onResult, onError);
  }
  return startQrScan(videoEl, onResult, onError);
};
