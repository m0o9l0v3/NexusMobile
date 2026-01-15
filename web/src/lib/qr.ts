import QrScanner from "qr-scanner";

export type QrHandle = {
  stop: () => Promise<void>;
};

export const startQrScan = async (
  video: HTMLVideoElement,
  onResult: (text: string) => void,
  onError: (reason: string) => void,
): Promise<QrHandle | null> => {
  if (!navigator.mediaDevices?.getUserMedia) {
    onError("お使いの端末ではカメラが利用できません。");
    return null;
  }

  const hasPermission = await navigator.mediaDevices
    .getUserMedia({ video: { facingMode: "environment" } })
    .then((stream) => {
      stream.getTracks().forEach((track) => track.stop());
      return true;
    })
    .catch(() => false);

  if (!hasPermission) {
    onError("カメラへのアクセスが拒否されました。手入力をご利用ください。");
    return null;
  }

  const scanner = new QrScanner(
    video,
    (result) => {
      onResult(result.data);
    },
    {
      maxScansPerSecond: 3,
      highlightScanRegion: true,
      highlightCodeOutline: true,
    },
  );
  await scanner.start();
  return {
    stop: async () => {
      await scanner.stop();
      scanner.destroy();
    },
  };
};
