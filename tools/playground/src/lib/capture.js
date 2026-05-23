import { GIFEncoder, applyPalette, quantize } from 'gifenc';

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function downloadCanvasFrame(canvas, filename = 'substrate-frame.png') {
  return new Promise((resolve, reject) => {
    if (!canvas) {
      reject(new Error('The render canvas is not available yet.'));
      return;
    }

    canvas.toBlob((blob) => {
      if (!blob) {
        reject(new Error('The browser could not encode this canvas as PNG.'));
        return;
      }
      downloadBlob(blob, filename);
      resolve();
    }, 'image/png');
  });
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function nextFrame() {
  return new Promise((resolve) => requestAnimationFrame(resolve));
}

async function readCanvasFrame(source, target, context) {
  context.clearRect(0, 0, target.width, target.height);

  try {
    const bitmap = await createImageBitmap(source);
    context.drawImage(bitmap, 0, 0, target.width, target.height);
    bitmap.close();
  } catch {
    // Firefox can reject createImageBitmap for a WebGPU canvas. The 2D draw
    // path still works in browsers that expose the canvas as an image source.
    context.drawImage(source, 0, 0, target.width, target.height);
  }

  return context.getImageData(0, 0, target.width, target.height).data;
}

export async function downloadCanvasGif(
  canvas,
  {
    duration = 3000,
    fps = 12,
    maxWidth = 640,
    onProgress = () => {},
  } = {},
) {
  if (!canvas) throw new Error('The render canvas is not available yet.');
  if (!canvas.width || !canvas.height) throw new Error('The render canvas has no pixels yet.');

  const scale = Math.min(1, maxWidth / canvas.width);
  const width = Math.max(1, Math.round(canvas.width * scale));
  const height = Math.max(1, Math.round(canvas.height * scale));
  const frameDelay = 1000 / fps;
  const frameCount = Math.max(2, Math.round(duration / frameDelay));
  const target = document.createElement('canvas');
  target.width = width;
  target.height = height;
  const context = target.getContext('2d', { willReadFrequently: true });
  if (!context) throw new Error('The browser could not create a GIF capture surface.');

  const gif = GIFEncoder();
  for (let frame = 0; frame < frameCount; frame++) {
    if (frame > 0) await wait(frameDelay);
    await nextFrame();

    const rgba = await readCanvasFrame(canvas, target, context);
    const palette = quantize(rgba, 256, { format: 'rgb565' });
    const index = applyPalette(rgba, palette, 'rgb565');
    gif.writeFrame(index, width, height, {
      palette,
      delay: frameDelay,
      repeat: 0,
    });
    onProgress((frame + 1) / frameCount);
  }

  gif.finish();
  downloadBlob(new Blob([gif.bytes()], { type: 'image/gif' }), 'substrate-animation.gif');
}
