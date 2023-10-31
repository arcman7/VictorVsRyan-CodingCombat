import * as UTILS from './utils';
import ingestCSVTexture from './shaders/ingestCSVTexture.wgsl'

export const main = async(
  adapter: GPUAdapter,
  device: GPUDevice,
  canvas: HTMLCanvasElement,
  context: GPUCanvasContext
) => { //@ts-ignore
  window.t = {
    adapter, device, canvas, context
  };

  const module = device.createShaderModule({
    label: 'ingest csv compute module',
    code: ingestCSVTexture,
  });
  const pipeline = device.createComputePipeline({
    label: 'ingest csv compute pipeline',
    layout: 'auto',
    compute: {
      module,
      entryPoint: 'main',
    },
  });

  const startIngestionOfFile = async (
    device: GPUDevice,
    pipeline: GPUComputePipeline,
    files: FileList,
  ) => {
    const file = files[0]; //@ts-ignore
    window.file = file;
    // Size of the CSV file in bytes
    const fileSize = file.size;
    const bytesPerPixel = 4; // For RGBA format
  
    /* Note: Hardware dependent. */
    const maxWidth = 4096 * 2; // pixels
    let textureWidth = maxWidth;
    let textureHeight = maxWidth;//Math.ceil(fileSize / (textureWidth * bytesPerPixel));
  
    // Calculate the actual number of bytes needed for this texture
    const totalTextureBytes = textureWidth * textureHeight * bytesPerPixel;
    console.log(files, fileSize);
    console.log({ textureWidth, textureHeight, totalTextureBytes });
  
    const {    
      // stacked2DTexture,
      // sampler,
      layers,
      textureView,
    } = await UTILS.writeBlobToTexturelayers(device, file);
    
    const MB = Math.pow(1024, 2);
    /* Note: Aassuming ~ 50 characters per line
    * (50 x uint8) for a 4.5GB File
    */
    const size = 48 * MB; 
    const rowIndicesGPUBuffer = device.createBuffer({
      label: 'row indicies array gpu buffer',
      size,
      usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    });
    const counterGPUBuffer = device.createBuffer({
      label: 'atomic index counter gpu buffer',
      size: 20, // Min size is 20 bytes
      usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    });
    const readCounterGPUBuffer = device.createBuffer({
      label: 'read GPU buffer for the atomic index counter',
      size: 20, // Min size is 20 bytes
      usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ
    });

    const { computePass, encoder } = UTILS.addShaderResourcesToPipeline({
      bindGroupName: 'csv ingestion bindgroup',
      pipeline,
      device,
      resources: [
        /* Note: The order of these resource bindings must
        * match the order used in the <shader name>.wgsl file.
        */
        {
          name: 'row indices array gpu buffer binding',
          resource: rowIndicesGPUBuffer,
        },
        {
          name: 'atomic index counter gpu buffer binding',
          resource: counterGPUBuffer,
        },
        // Sampler needs to be added first
        // TODO: Confirm
        // {
        //   name: 'stacked2dTexture Sampler',
        //   resource: sampler,
        // },
        {
          name: 'stacked2DTexture View',
          resource: textureView,
        },
      ],
    });
    /* Note: workgroup size is defined in <compute shader file>.wgsl) */
    const wgSizeDims = { x: 32, y: 32, z: 1 }; // 32 * 32 = 1024 total concurrent jobs per workgroup 
    // const workGroupSize = wgSizeDims.x *  wgSizeDims.y * wgSizeDims.z;
    // const numWorkGroupsPerRow = textureWidth / workGroupSize;
    // const numWorkGroupsTotal =  numWorkGroupsPerRow * textureHeight;

    const numWorkGroupsX = textureWidth / wgSizeDims.x;
    const numWorkGroupsY = textureHeight / wgSizeDims.y;
    const numWorkGroupsZ = layers;
    /* Note: no real benefit to making compute passes in 2D,
    * 3D, etc as oposed to 1D.
    * Note: Confirm.
    */
    // const numWorkGroupsX = Math.ceil(Math.sqrt(numWorkGroupsTotal));
    // const numWorkGroupsY = numWorkGroupsX;
    console.log({ numWorkGroupsX, numWorkGroupsY, numWorkGroupsZ })
    console.log(`dispatching ${numWorkGroupsX * numWorkGroupsY * numWorkGroupsZ} workgroups, each with ${wgSizeDims.x * wgSizeDims.y * wgSizeDims.z} compute invocations`)

    computePass.dispatchWorkgroups(
      numWorkGroupsX, numWorkGroupsY, numWorkGroupsZ,
    );
    computePass.end();

    /* Verify that the correct number of rows
    * has been detected in the CSV File.
    */
    encoder.copyBufferToBuffer(
      // Encode a command to copy the counter buffer to a mappable buffer.
      counterGPUBuffer, 0,
      readCounterGPUBuffer, 0, 
      counterGPUBuffer.size
    );

    // Finish encoding and submit the commands
    const commandBuffer = encoder.finish();
    device.queue.submit([commandBuffer]);

    // Read the results
    await readCounterGPUBuffer.mapAsync(GPUMapMode.READ);
    const result = new Uint32Array(readCounterGPUBuffer.getMappedRange());
    console.log('number of rows: ', result[0]);
  }

  UTILS.setupFileDropListener((files) => {
    startIngestionOfFile(device, pipeline, files);
  });
};