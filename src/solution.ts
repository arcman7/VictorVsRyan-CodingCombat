import * as UTILS from './utils';
import ingestCSVTexture from './shaders/ingestCSVTexture.wgsl';
import parseCSVTexture from './shaders/parseCSVTexture.wgsl';

type CreateComputeShaderPipelineParams = {
  device: GPUDevice,
  shaderProgram: string,
  name: string,
  includes?: string, 
  entryPoint?: string,
};

const createComputeShaderPipeline = (params:CreateComputeShaderPipelineParams) => {
  const { device, shaderProgram, name, includes, entryPoint } = params;
  const module = device.createShaderModule({
    label: `${name} compute module`,
    code: `${includes || ''}\n${shaderProgram}`
  });
  const pipeline = device.createComputePipeline({
    label: `${name} compute pipeline`,
    layout: 'auto',
    compute: {
      module,
      entryPoint: entryPoint || 'main',
    }
  });
  return pipeline;
}

export const main = async(
  adapter: GPUAdapter,
  device: GPUDevice,
  canvas: HTMLCanvasElement,
  context: GPUCanvasContext
) => { //@ts-ignore
  window.t = {
    adapter, device, canvas, context
  };

  // const module1 = device.createShaderModule({
  //   label: 'ingest csv compute module',
  //   code: ingestCSVTexture,
  // });
  // const pipeline1 = device.createComputePipeline({
  //   label: 'ingest csv compute pipeline',
  //   layout: 'auto',
  //   compute: {
  //     module: module1,
  //     entryPoint: 'main',
  //   },
  // });

  // const module2 = device.createShaderModule({
  //   label: 'parse csv compute module',
  //   code: parseCSVTexture,
  // });
  // const pipeline2 = device.createComputePipeline({
  //   label: 'parse csv compute pipeline',
  //   layout: 'auto',
  //   compute: {
  //     module: module2,
  //     entryPoint: 'main',
  //   },
  // });

  const startIngestionOfFile = async (
    device: GPUDevice,
    // pipeline: GPUComputePipeline,
    ingestCSVTextureShader: string,
    parseCSVTextureShader: string,
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
    
    /* Note: Assuming ~ 50 characters per line
    * (1) MB = 1024 ** 2
    * (1) GB = 1024 ** 3 
    * (50 x uint8 characters per line) for a 4.5GB File:
    * (4.5 * 1024 ** 3) / 50 = 96636764.16
    * 96636764 / (1024 * 1024) = 92 MB
    * Add on an extra 30% as a margin of error:
    * 90 + 30 MB needed to store the row start indices
    */
    const MB = Math.pow(1024, 2);
    const size = 120 * MB; 
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
    // const debugRowsPerLayerGPUBuffer = device.createBuffer({
    //   label: 'debug - row counts per layer',
    //   size: 4 * 17, // 17 layers
    //   usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    // });
    // const readDebugGPUBuffer = device.createBuffer({
    //   label: 'read debug rows per layer GPU buffer',
    //   size: 4 * 17,
    //   usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ
    // });

    const ingestionComputePipeline = createComputeShaderPipeline({
      device, shaderProgram: ingestCSVTextureShader,
      name: 'ingest csv',
    });

    const { computePass, encoder } = UTILS.addShaderResourcesToPipeline({
      bindGroupName: 'csv ingestion bindgroup',
      pipeline: ingestionComputePipeline,
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
        {
          name: 'stacked2DTexture View',
          resource: textureView,
        },
        // {
        //   name: 'debug - atomic rowCounts per layer',
        //   resource: debugRowsPerLayerGPUBuffer,
        // }
      ],
    });
    /* Note: Workgroup size is defined in ingestCSVTexture.wgsl */
    let wgSizeDims = { x: 32, y: 32, z: 1 }; // 32 * 32 = 1024 total concurrent jobs per workgroup 

    /* Note: Supposedly, there's no measurable benefit
    * in performance by making compute passes in 2D or 3D,
    * as oposed to 1D. Need to confirm this.
    * 
    * However, we should alawys keep the number of
    * works groups per dimension at a minimum to
    * encourage cross hardware compatibility
    */ 
    let numWorkGroupsX = textureWidth / wgSizeDims.x;
    let numWorkGroupsY = textureHeight / wgSizeDims.y;
    let numWorkGroupsZ = layers;
 
    let start = performance.now();
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

    // Debug
    // await readDebugGPUBuffer.mapAsync(GPUMapMode.READ);
    // const rowCountsPerLayer = new Uint32Array(readDebugGPUBuffer.getMappedRange());
    // console.log('row counts per layer: ', rowCountsPerLayer)

    // encoder.copyBufferToBuffer(
    //   debugRowsPerLayerGPUBuffer, 0,
    //   readDebugGPUBuffer, 0,
    //   debugRowsPerLayerGPUBuffer.size
    // );

    // Finish encoding and submit the commands
    let commandBuffer = encoder.finish();
    device.queue.submit([commandBuffer]);
    console.log('job execution time: ', performance.now() - start);

    start = performance.now();
    // Read the results
    await readCounterGPUBuffer.mapAsync(GPUMapMode.READ);
    const result = new Uint32Array(readCounterGPUBuffer.getMappedRange());
    const numRows = result[0];
    console.log('time to read data: ', performance.now() - start);
    console.log('number of rows: ', numRows);

    // // Setup and start the next compute pass for parsing the csv file
    // const exportCountGPUBuffer = device.createBuffer({
    //   label: 'atomic index counter gpu buffer',
    //   size: 259 * 4, // 259 countries x 4 bytes per Uint32 value
    //   usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    // });

    // /* Ingest csv file as 1 row per workgroup. 
    // * Assuming 50 characters per row, 
    // * where each pixel is 4 bytes/characters.
    // */ 
    // wgSizeDims = { x: 13, y: 1, z: 1 }; 
    // // Determine shape and amount of total work groups
    // const MAX_WG_NUMBER_1D = device.limits.maxComputeWorkgroupsPerDimension; 
    // /* Keep the number of works groups per
    // * dimension at a minimum to encourage
    // * cross hardware compatibility
    // */ 
    // const numWorkGroupsPerDim = Math.ceil(numRows ** (1/3));
    // numWorkGroupsX = numWorkGroupsPerDim;
    // numWorkGroupsY = numWorkGroupsPerDim;
    // numWorkGroupsZ = numWorkGroupsPerDim;
    // if (numWorkGroupsX > MAX_WG_NUMBER_1D) {
    //   throw new Error(`Required work groups per dimension (${numWorkGroupsX}) exceeds the maximum (${MAX_WG_NUMBER_1D}) allowed. Splitting the workloads across multiple compute passes is needed.`);
    // }

    // console.log({ numWorkGroupsX, numWorkGroupsY, numWorkGroupsZ });
    // console.log(`dispatching ${numWorkGroupsX * numWorkGroupsY * numWorkGroupsZ} workgroups, each with ${wgSizeDims.x * wgSizeDims.y * wgSizeDims.z} compute invocations`);

    // const parseComputePipeline = createComputeShaderPipeline({
    //   device, shaderProgram: parseCSVTextureShader, name: 'parse csv', includes: `
    //   const wg_per_dim: u32 = ${numWorkGroupsPerDim};
    //   const wg_per_dim_sq: u32 = ${numWorkGroupsPerDim ** 2};
    //   `,
    // })

    // const { computePass: computePass2, encoder: encoder2 } = UTILS.addShaderResourcesToPipeline({
    //   bindGroupName: 'csv parsing bindgroup',
    //   pipeline: parseComputePipeline,
    //   device,
    //   resources: [
    //     /* Note: The order of these resource bindings must
    //     * match the order used in the parseCSVTexture.wgsl file.
    //     */
    //     {
    //       name: 'row indices array gpu buffer binding - csv parsing',
    //       resource: rowIndicesGPUBuffer,
    //     },
    //     {
    //       name: 'atomic array export counter gpu buffer binding',
    //       resource: exportCountGPUBuffer,
    //     },
    //     {
    //       name: 'stacked2DTexture View - csv parsing',
    //       resource: textureView,
    //     },
    //   ],
    // });

    // start = performance.now();
    // computePass2.dispatchWorkgroups(
    //   numWorkGroupsX, numWorkGroupsY, numWorkGroupsZ,
    // );
    // computePass2.end();

    // commandBuffer = encoder2.finish();
    // device.queue.submit([commandBuffer]);
    // console.log('job execution time: ', performance.now() - start);
  }

  UTILS.setupFileDropListener((files) => {
    startIngestionOfFile(
      device, ingestCSVTexture,
      parseCSVTexture, files
    );
  });
};