export function setupFileDropListener(processFilesCB: (files: FileList) => void) {
  const dragover = (e: DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    // Additional UI changes (e.g., highlight drop zone) can be made here
  }
  
  const drop = (e: DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    const files = e.dataTransfer!.files;
    processFilesCB(files);
  }

  document.body.addEventListener('dragover', dragover);
  document.body.addEventListener('drop', drop);
}

export const findNearestNewLine = (file: File, startIndex: number, maxDistance = 400) => {
  return new Promise((resolve, reject) => {
    // Calculate the end index (limiting it to the file size)
    let endIndex = Math.min(startIndex + maxDistance, file.size);

    // Read the specified slice of the file
    let blob = file.slice(startIndex, endIndex);
    let reader = new FileReader();

    reader.onload = function(event: ProgressEvent<FileReader>) {
      let text = event.target!.result! as string;
      let newlineIndex = text.indexOf('\r');
      console.log(text, { text }); //json: JSON.stringify(text)});
      if (newlineIndex !== -1) {
        // Adjust the index relative to the file
        resolve(startIndex + newlineIndex);
        console.log(
          'new line character at : ', startIndex + newlineIndex, '\n',
          newlineIndex, 'characters from mid point\n',
        )
      } else {
        // Newline not found within the range
        resolve(-1);
      }
    };

    reader.onerror = function() {
      reject("Error reading file.");
    };

    reader.readAsText(blob);
  });
}

export function blobToArrayBuffer(blob: Blob): Promise<ArrayBuffer> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      resolve(reader.result as ArrayBuffer);
    };
    reader.onerror = reject;
    reader.readAsArrayBuffer(blob);
  });
}

export function sliceBlob(blob: Blob, size: number) {
  let start = 0;
  let chunks = [];
  while (start < blob.size) {
    let end = Math.min(blob.size, start + size);
    chunks.push(blob.slice(start, end));
    start = end;
  }
  return chunks;
}

export function alignToFourBytes(size: number) {
  // return size - (size % 4);
  return size - (size % 20);
}

export const countOccurrences = (str: string, subString: string) => {
  // Use a regular expression to find all occurrences
  const matches = str.match(new RegExp(subString, 'g'));
  return matches ? matches.length : 0;
}

export const uint8ArrayToText = (uint8Array: Uint8Array) => {
  let decoder = new TextDecoder('utf-8');
  return decoder.decode(uint8Array);
}

// export const readBuffer = async (device: GPUDevice, encoder: GPUCommandEncoder, buffer: GPUBuffer, ) => {
//   const size = buffer.size;
//   const gpuReadBuffer = device.createBuffer({size, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
//   encoder.copyBufferToBuffer(buffer, 0, gpuReadBuffer, 0, size);
//   // const copyCommands = encoder.finish();
//   // device.queue.submit([copyCommands]);
//   await gpuReadBuffer.mapAsync(GPUMapMode.READ);
//   return gpuReadBuffer.getMappedRange();
// }


export const expandBuffer = (
  sourceBuffer: ArrayBuffer, newSizeBytes: number
) => {
  if (sourceBuffer.byteLength > newSizeBytes) {
    throw new Error('New buffer size must be larger than the original.')
  }
  // Create a new buffer of the required size
  let newBuffer = new ArrayBuffer(newSizeBytes);

  // Create views for copying data
  let sourceView = new Uint8Array(sourceBuffer);
  let newView = new Uint8Array(newBuffer);

  // Copy data from the source buffer to the new buffer
  newView.set(sourceView, 0);
  // console.log(uint8ArrayToText(newView.slice(0, 5000)))
  // console.log('last:')
  // console.log(uint8ArrayToText(newView.slice(sourceView.length - 5000, sourceView.length)))

  // The rest of the new buffer will be initialized to 0s
  return newBuffer;
}




export const get8kTexturesForBlob = (device: GPUDevice, file: File) => {
  const texSize = 4 * (8192 ** 2);
  const numTextures = Math.ceil(file.size / texSize);

  const texture = device.createTexture({
    size: {
      width: 8192,
      height: 8192,
      depthOrArrayLayers: numTextures
    },
    
    // format: 'rgba8unorm', // Assuming you're working with RGBA data
    format: 'rgba8uint', // Assuming you're working with RGBA data 
    usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST 
  });

  return { texture, layers: numTextures };
};

export function updateTextureLayer(
  device: GPUDevice, texture: GPUTexture, buffer: BufferSource,
  layer: number, textureWidth: number, textureHeight: number
) {
  const bytesPerRow = 4 * textureWidth; // 4 bytes per pixel (RGBA)

  device.queue.writeTexture(
    { texture, origin: { x: 0, y: 0, z: layer } }, // Destination texture and layer
    buffer, // Source buffer
    {
      offset: 0,
      bytesPerRow: bytesPerRow,
      rowsPerImage: textureHeight
    },
    { width: textureWidth, height: textureHeight, depthOrArrayLayers: 1 } // Size of the region to copy
  );
}

export const writeBlobToTexturelayers = async (
  device: GPUDevice, file: File) => {
  const start = performance.now();
  const { texture: textureLayers, layers } = get8kTexturesForBlob(device, file);

  const proms: Promise<void>[] = Array(layers);
  const dataSliceSize = 4 * (8192 ** 2);
  const blobSlices = sliceBlob(file, dataSliceSize);
  for (let i = 0; i < blobSlices.length; i++) {
    const blob = blobSlices[i];
    proms[i] = blob.arrayBuffer().then((arrayBuffer) => {
      // console.log({arrayBuffer})
      let usedArrayBuffer = arrayBuffer;
      if (arrayBuffer.byteLength < dataSliceSize) {
        usedArrayBuffer = expandBuffer(arrayBuffer, dataSliceSize);
      }
      updateTextureLayer(
        device, textureLayers,
        usedArrayBuffer, i, 8192, 8192
      );
    });
  }
  // console.log('kick off job time: ', performance.now() - start);
  await Promise.all(proms);
  console.log('Texture upload time: ', performance.now() - start);

  const sampler = device.createSampler({
    magFilter: "nearest",
    minFilter: "nearest",
    mipmapFilter: "nearest",
    addressModeU: "repeat",
    addressModeV: "repeat",
    addressModeW: "repeat",
    maxAnisotropy: 1
  });
  const textureView = textureLayers.createView({
    format: textureLayers.format,
    mipLevelCount: 1,
    baseArrayLayer: 0,
    arrayLayerCount: layers,
  });
  return { stacked2DTexture: textureLayers, textureView, sampler, layers, };
};

export const blobTo8kArrayBuffers = async (file: File) => {
  const blobSlices = sliceBlob(file, 4 * (8192 **2 ));
  const proms: Promise<ArrayBuffer>[] = Array(blobSlices.length);
  for (let i = 0; i < blobSlices.length; i++) {
    const blob = blobSlices[i];
    proms[i] = blob.arrayBuffer().then((arrayBuffer) => {
      // console.log({arrayBuffer})
      return arrayBuffer;
    });
  }
  return Promise.all(proms);
};

export const writeBlobToTexturelayers2 = async (device: GPUDevice, file: File) => {
  const start = performance.now();
  const { texture: textureLayers, layers } = get8kTexturesForBlob(device, file);
  const abs = await blobTo8kArrayBuffers(file);
  console.log('kick off job time: ', performance.now() - start);

  for (let i = 0; i < abs.length; i++) {
    const arrayBuffer = abs[i];
    updateTextureLayer(device, textureLayers, arrayBuffer, i, 8192, 8192);
  }
  console.log('total time: ', performance.now() - start);

  const sampler = device.createSampler({
    magFilter: "nearest",
    minFilter: "nearest",
    mipmapFilter: "nearest",
    addressModeU: "repeat",
    addressModeV: "repeat",
    addressModeW: "repeat",
    maxAnisotropy: 1
  });
  const textureView = textureLayers.createView({
    format: textureLayers.format,
    mipLevelCount: 0,
    baseArrayLayer: 0,
    arrayLayerCount: layers,
  });
  return { stacked2DTexture: textureLayers, textureView, sampler, layers, };
};

export type ShaderResource = GPUSampler
| GPUTextureView
| GPUBuffer
| GPUExternalTexture;
export type ShaderResourceInfo = { resource: ShaderResource, name: string };
export const addShaderResourcesToPipeline = (
  addShaderResourceParams: {
    device: GPUDevice, pipeline: GPUComputePipeline,
    resources: ShaderResourceInfo[],
    computePass?: GPUComputePassEncoder,
    encoder?: GPUCommandEncoder,
    bindGroupName?: string
  }
) => {
  const { device, pipeline, resources, bindGroupName } = addShaderResourceParams;
  let {computePass, encoder } = addShaderResourceParams;

  const entries: GPUBindGroupEntry[] = [];
  resources.forEach(({resource, name }) => {
    resource.label = name;
    const binding = entries.length;
    if (resource instanceof GPUBuffer) {
      const bufferBinding: GPUBufferBinding = { buffer: resource };
      entries.push({ binding, resource: bufferBinding });
    } else if (resource instanceof GPUTextureView) {
      entries.push({ binding, resource });
    } else if (resource instanceof GPUSampler) {
      entries.push({ binding, resource });
    } else if (resource instanceof GPUExternalTexture) {
      entries.push({ binding, resource });
    }
  });
  const bindGroup = device.createBindGroup({
    label: bindGroupName || `bindGroup for ${resources.map((sr) => sr.name ).join(' | ')}`,
    layout: pipeline.getBindGroupLayout(0),
    entries,
  });
  // Encode commands to do the computation
  encoder ||=  device.createCommandEncoder({
    label: `${bindGroup.label} encoder`,
  });
  computePass ||= encoder.beginComputePass({
    label: `${bindGroup.label} compute pass`,
  });
  computePass.setPipeline(pipeline);
  computePass.setBindGroup(0, bindGroup);
  return { computePass, encoder, bindGroup };
}

