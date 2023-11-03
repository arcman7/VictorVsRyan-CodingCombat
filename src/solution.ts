import * as UTILS from './utils';
import ingestCSVTexture from './shaders/ingestCSVTexture.wgsl';
// import parseCSVTexture from './shaders/parseCSVTexture.wgsl';

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

const YM = 0;
const EI = 1;
const COUNTRY = 2;
const CUSTOMS = 3;
const HS9 = 4;
const Q1 = 5;
const Q2 = 6;
const YEN = 7;

const DESCENDING = 0;
const ASCENDING = 1;

const COUNTRIES_RANGE = 1000;
const YEARS_RANGE = 50;

export const main = async(
  adapter: GPUAdapter,
  device: GPUDevice,
  canvas: HTMLCanvasElement,
  context: GPUCanvasContext
) => { //@ts-ignore
  window.t = {
    adapter, device, canvas, context
  };

  const startIngestionOfFile = async (
    device: GPUDevice,
    ingestCSVTextureShader: string,
    files: FileList,
  ) => {
    const encoder = device.createCommandEncoder({
      label: 'csv gpu ingestion encoder'
    });

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
    const queryGPUBuffer = device.createBuffer({
      label: 'query struct gpu buffer',
      size: 6 * 4 + (YEARS_RANGE * COUNTRIES_RANGE * 4),
      usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    });
    const queryData = new Uint32Array(6);
    const CRANGE_START = 0;
    const KEEP = 1;
    queryData.set([COUNTRY, Q1, CRANGE_START, COUNTRIES_RANGE, DESCENDING, KEEP]);
    device.queue.writeBuffer(queryGPUBuffer, 0, queryData);

    const counterGPUBuffer = device.createBuffer({
      label: 'atomic row counter gpu buffer',
      size: 20, // Min size is 20 bytes
      usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    });
    const readCounterGPUBuffer = device.createBuffer({
      label: 'read GPU buffer for the atomic index counter',
      size: counterGPUBuffer.size,
      usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ
    });
    const readQueryStructGPUBuffer = device.createBuffer({
      label: 'read query GPU buffer for the atomic sum values',
      size: queryGPUBuffer.size, 
      usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ
    });
    const readTimeQueryGPUBuffer = device.createBuffer({
      label: 'read time query GPU buffer for timing dispatch',
      size: 8 * capacity,
      usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ
    })
    // Timing
    const querySet = device.createQuerySet({
      type: "timestamp",
      count: capacity,
    });
    const timeQueryGPUBuffer = device.createBuffer({
      size: 8 * capacity,
      usage: GPUBufferUsage.QUERY_RESOLVE 
        | GPUBufferUsage.STORAGE
        | GPUBufferUsage.COPY_SRC
        | GPUBufferUsage.COPY_DST,
    });

    timestamp(encoder, querySet, 'read csv texture pixels - start');

    const ingestionComputePipeline = createComputeShaderPipeline({
      name: 'ingest csv', device, //@ts-ignore
      shaderProgram: ingestCSVTextureShader.replaceAll(
        '/*QUERY_ROWS*/',
        `${COUNTRIES_RANGE}`,
      ),
    });


    const { computePass } = UTILS.addShaderResourcesToPipeline({
      bindGroupName: 'csv ingestion bindgroup',
      pipeline: ingestionComputePipeline,
      device,
      encoder,
      resources: [
        /* Note: The order of these resource bindings must
        * match the order used in the <shader name>.wgsl file.
        */
        {
          name: 'query struct gpu buffer binding',
          resource: queryGPUBuffer,
        },
        {
          name: 'atomic index counter gpu buffer binding',
          resource: counterGPUBuffer,
        },
        {
          name: 'stacked2DTexture View',
          resource: textureView,
        },
      ],
    });
    /* Note: Workgroup size is defined in ingestCSVTexture.wgsl */
    let wgSizeDims = { x: 32, y: 32, z: 1 }; 

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
 


    // Add timestamps in between GPU commands
    // encoder.writeTimestamp(querySet, 0);// Initial timestamp
    // let start = performance.now();
    computePass.dispatchWorkgroups(
      numWorkGroupsX, numWorkGroupsY, numWorkGroupsZ,
    );
    computePass.end();

    // encoder.writeTimestamp(querySet, 1);
    timestamp(encoder, querySet, 'read csv texture pixels - end');
    
    /* Verify that the correct number of rows
    * has been detected in the CSV File.
    */
    // encoder.copyBufferToBuffer(
    //   // Encode a command to copy the counter buffer to a mappable buffer.
    //   counterGPUBuffer, 0,
    //   readCounterGPUBuffer, 0, 
    //   counterGPUBuffer.size
    // );

    encoder.copyBufferToBuffer(
      // Encode a command to copy the counter buffer to a mappable buffer.
      queryGPUBuffer, 0,
      readQueryStructGPUBuffer, 0, 
      queryGPUBuffer.size
    );

    encoder.copyBufferToBuffer(
      timeQueryGPUBuffer, 0,
      readTimeQueryGPUBuffer, 0,
      timeQueryGPUBuffer.size,
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

    encoder.resolveQuerySet(
      querySet, 
      0,// index of first query to resolve 
      capacity,//number of queries to resolve
      timeQueryGPUBuffer, 
      0
    );// destination offset


    // Finish encoding and submit the commands
    const commandBuffer = encoder.finish();
    device.queue.submit([commandBuffer]);


    // console.log('job execution time: ', performance.now() - start);

    // const readStart = performance.now();

    // Read the results
    // await readCounterGPUBuffer.mapAsync(GPUMapMode.READ);
    // const counterResult = new Uint32Array(readCounterGPUBuffer.getMappedRange());
    // const numRows = counterResult[0];
    // console.log('number of rows: ', numRows);

    await readQueryStructGPUBuffer.mapAsync(GPUMapMode.READ);
    const qdata = readQueryStructGPUBuffer.getMappedRange()
    // const qdata = await UTILS.readBuffer(device, readQueryStructGPUBuffer);
    const queryStructResult = new Uint32Array(qdata);
    // const finish = performance.now();
    // console.log('time to read data: ', finish - readStart);
    // console.log('total time: ', finish - start);

    await readTimeQueryGPUBuffer.mapAsync(GPUMapMode.READ);
    const timeQueryArrayBuffer = readTimeQueryGPUBuffer.getMappedRange();
    // await UTILS.readBuffer(device, timeQueryGPUBuffer);
    const timingsNanoseconds = new BigInt64Array(timeQueryArrayBuffer);
    printTimestampsWithLabels(timingsNanoseconds, queryLabelMap);

    //  console.log(queryStructResult)
    const queryStruct = {
      indexByColumn: queryStructResult[0],
      quantityColumn: queryStructResult[1],
      indexColumnRangeStart: queryStructResult[2],
      indexColumnRangeEnd: queryStructResult[3],
      sortBy: queryStructResult[4],
      keep: queryStructResult[5],
      valsList: [...queryStructResult.slice(6)]
    }
    console.log(queryStruct);
    //@ts-ignore
    queryStruct.valsList.size =  queryStruct.valsList.length;
    //@ts-ignore
    const byCountryByYear = UTILS.sliceBlob(queryStruct.valsList, 50) as number[][];
    const byCountry = byCountryByYear.map(exports => exports.reduce((a, b) => a + b, 0));
    const maxExports = Math.max(...byCountry);
    const countryCode = byCountry.indexOf(maxExports);
    console.log(countryCode, ' exports: ', maxExports);
    console.log({ byCountry, byCountryByYear })

    window.test = (a = 0, offset = 0, mul = 1) => {
      byCountryByYear[a].forEach((val) => {
        if (val === 0) return;
        file.slice((val * mul) + offset, (val * mul) + offset + 50).text().then((res) => {
          console.log('testing row start:\n', res)
        })
      })
    }
  }

  UTILS.setupFileDropListener((files) => {
    startIngestionOfFile(device, ingestCSVTexture, files);
  });
};





let queryIndex = 0;
const maxNumberOfQueries = 8;
const capacity = 2;//Max number of timestamps we chose to store
const queryLabelMap: {[key: number]: string } = {};

export const timestamp = (
  encoder: GPUCommandEncoder, querySet: GPUQuerySet, label: string
) => {
  encoder.writeTimestamp(querySet, queryIndex);
  queryLabelMap[queryIndex] = label
  queryIndex++;
  if (queryIndex >= maxNumberOfQueries) queryIndex = 0;
}

export const printTimestampsWithLabels = (timingsNanoseconds: BigInt64Array, labelMap: {[key: number]: string }) => {
  console.log("==========")
  // Convert list of nanosecond timestamps to diffs in milliseconds
  const timeDiffs = []
  for (let i = 1; i < timingsNanoseconds.length; i++) {
    let diff = Number(timingsNanoseconds[i] - timingsNanoseconds[i - 1])
    diff /= 1_000_000
    timeDiffs.push(diff)
  }

  // Print each diff with its associated label
  for (let i = 0; i < timeDiffs.length; i++) {
    const time = timeDiffs[i];
    const label = labelMap[i + 1]
    if (label) {
      console.log(label, time + "ms"); //.toFixed(2) + "ms")
    } else {
      console.log(i, time + "ms"); //.toFixed(2) + "ms")
    }
  }
  console.log("==========")
}