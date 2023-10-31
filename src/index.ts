// import { main } from './examples/part1';
// import { main } from './examples/part2';
import { main } from './solution';
import * as UTILS from './utils';
//@ts-ignore
window.UTILS = UTILS;

/* On page load */
async function init(main: (
  adapter: GPUAdapter,
  device: GPUDevice,
  canvas: HTMLCanvasElement,
  context: GPUCanvasContext
) => Promise<void>) {
  const adapter = await navigator.gpu?.requestAdapter();
  const device = await adapter?.requestDevice({
    // requiredFeatures: [ ],
    requiredLimits: {
      maxBufferSize: 1024 * 1024 * 1024, // 1GB
      maxComputeInvocationsPerWorkgroup: 1024,
      maxComputeWorkgroupSizeX: 1024,
      maxComputeWorkgroupSizeY: 1024,
      maxComputeWorkgroupSizeZ: 64,
    },
  });
  if (!device) {
    alert('need a browser that supports WebGPU');
    return;
  }
  // Get a WebGPU context from the canvas and configure it
  const canvas = document.querySelector('canvas');
  const context = canvas!.getContext('webgpu')!;
  const presentationFormat = navigator.gpu.getPreferredCanvasFormat();
  context.configure({
    device,
    format: presentationFormat,
  });
  main(
    adapter as GPUAdapter, device,
    canvas as HTMLCanvasElement, context
  );
}
init(main);