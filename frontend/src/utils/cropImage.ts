import i18n from "../i18n/config";

interface PixelCrop {
  width: number;
  height: number;
  x: number;
  y: number;
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.crossOrigin = "anonymous";
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(i18n.t("profile.cropLoadError")));
    image.src = src;
  });
}

export async function getCroppedImageBlob(imageSource: string, pixelCrop: PixelCrop): Promise<Blob> {
  const image = await loadImage(imageSource);
  const canvas = document.createElement("canvas");

  canvas.width = pixelCrop.width;
  canvas.height = pixelCrop.height;

  const context = canvas.getContext("2d");
  if (!context) {
    throw new Error(i18n.t("profile.cropCanvasError"));
  }

  context.drawImage(
    image,
    pixelCrop.x,
    pixelCrop.y,
    pixelCrop.width,
    pixelCrop.height,
    0,
    0,
    pixelCrop.width,
    pixelCrop.height,
  );

  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (!blob) {
        reject(new Error(i18n.t("profile.cropGenerateError")));
        return;
      }

      resolve(blob);
    }, "image/jpeg", 0.92);
  });
}
