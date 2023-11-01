
/* disable_uniformity_analysis */
const PIXELS_PER_ROW: i32 = 13; // Assumption about the csv file
 // Index where we need to begin parsing pixel by pixel
const UNKNOWN_START_IND: i32 = 27;
// const UNKNOWN_START_PIXEL: i32 = 6; // 27 / 4u


//  YM   e/i  hs9  country cus        q1   q2     yen
//      5  7  9    13      17         27
// 198801, 1, 103, 100,    000000190, 0,  35843, 34353
// 198801, 1, 103, 100,    120991000, 0,  1590,  4154
// 198801, 1, 103, 100,    210390900, 0,  4500,  2565
// 198801, 1, 103, 100,    220890200, 0,  3000,  757
// 198801, 1, 103, 100,    240220000, 0,  26000, 40668
// 198801, 1, 103, 100,    250410000, 0,  5,     8070
// 198801, 1, 103, 100,    271000700, 0,  374,   2485
// 198801, 1, 103, 100,    271220000, 0,  400,   616

const YM_A = array<u32,9>(0,1,2,3,4,5,0,0,0);
const EI_A = array<u32,9>(7,0,0,0,0,0,0,0,0);
const HS9_A = array<u32,9>(9,10,11,0,0,0,0,0,0);
const COUNTRY_A = array<u32,9>(13,14,15,0,0,0,0,0,0);
const CUSTOMS_A = array<u32,9>(17,18,19,20,21,22,23,24,25);
const Q1_A = array<u32,9>(26,0,0,0,0,0,0,0,0);
const UNKNOWN_A = array<u32,9>(0,0,0,0,0,0,0,0,0);

const YM: u32 = 0;
const EI: u32 = 1;
const HS9: u32 = 2;
const COUNTRY: u32 = 3;
const CUSTOMS: u32 = 4;
const Q1: u32 = 5;
const Q2: u32 = 6;
const YEN: u32 = 7;

struct ColumnIndsInfo {
  inds: array<u32, 9>,
  length: u32,
  start: u32,
}

fn getIndicesOfColumn(column: u32) -> ColumnIndsInfo {
  switch (column) {
    case YM: {
      let info: ColumnIndsInfo = ColumnIndsInfo(YM_A, 5, 0);
      return info;
    }
    case EI: {
      let info: ColumnIndsInfo = ColumnIndsInfo(EI_A, 1, 7);
      return info;
    }
    case HS9: {
      let info: ColumnIndsInfo = ColumnIndsInfo(HS9_A, 3, 9);
      return info;
    }
    case COUNTRY: {
      let info: ColumnIndsInfo = ColumnIndsInfo(COUNTRY_A, 3, 13);
      return info;
    }
    case CUSTOMS: {
      let info: ColumnIndsInfo = ColumnIndsInfo(CUSTOMS_A, 9, 17);
      return info;
    }
    case Q1: {
      let info: ColumnIndsInfo = ColumnIndsInfo(Q1_A, 0, 27);
      return info;
    }
    case Q2: {
      let info: ColumnIndsInfo = ColumnIndsInfo(UNKNOWN_A, 0, 0);
      return info;
    }
    case YEN: {
      let info: ColumnIndsInfo = ColumnIndsInfo(UNKNOWN_A, 0, 0);
      return info;
    }
    default: {
      let info: ColumnIndsInfo = ColumnIndsInfo(UNKNOWN_A, 0, 0);
      return info;
    }
  }
}

const TEXWIDTH: u32 = 8192;
const TEXWIDTH_F: f32 = 8192;
const TEXWIDTH_SQ: u32 = 8192 * 8192;
const LAYERS = 17;

const R: u32 = 0;
const G: u32 = 1;
const B: u32 = 2;
const A: u32 = 3;

// const NOT_FOUND: u32 = 5;
const NOT_FOUND: u32 = 999;
fn channelOf(pixel: vec4<u32>, char: u32) -> u32 {
  if (pixel.r == char) {
    return R;
  }
  if (pixel.g == char) {
    return G;
  }
  if (pixel.b == char) {
    return B;
  }
  if (pixel.a == char) {
    return A;
  }
  return NOT_FOUND;
}

fn applyOffsetToPosition(pos: vec3<u32>, offset: u32) -> vec3<u32> {
  // Convert 3D position to 1D index
  var index = pos.z * (TEXWIDTH_SQ) + pos.y * TEXWIDTH + pos.x;

  // Apply offset
  index = index + offset;

  // Convert back to 3D position
  let newX = index % TEXWIDTH;
  let newY = (index / TEXWIDTH) % TEXWIDTH;
  let newZ = index / (TEXWIDTH_SQ);

  return vec3<u32>(newX, newY, newZ);
}

fn getPosition(index: u32) -> vec3<u32> {
    // Convert to 3D position
  let indexX = index % TEXWIDTH;
  let indexY = (index / TEXWIDTH) % TEXWIDTH;
  let indexZ = index / (TEXWIDTH_SQ);

  return vec3<u32>(indexX, indexY, indexZ);
}

fn getFlatIndex(pos: vec3<u32>) -> u32 {
  // Convert 3D position to 1D index
  return pos.z * (TEXWIDTH_SQ) + pos.y * TEXWIDTH + pos.x;
}

const ZERO: u32 = 48;
const ONE: u32 = 49;
const TWO: u32 = 50;

fn isExport(pixel: vec4<u32>) -> bool {
  if (pixel.r == ONE) {
    return true;
  }
  if (pixel.g == ONE) {
    return true;
  }
  if (pixel.b == ONE) {
    return true;
  }
  if (pixel.a == ONE) {
    return true;
  }
  return false;
}

const RETURNLINE: u32 = 13;
const NEWLINE: u32 = 10;
const COMMA: u32 = 44;

const MAX_GROUPS: u32 = 8; // Maximum number of groups we expect (columns)
const MAX_GROUP_SIZE: u32 = 12; // Maximum number of elements in each group

// The outputArray needs to be a 2D array (or an equivalent representation)
// where the first dimension represents groups and the second dimension represents the elements in each group.
// fn extractGroups(values: array<u32>, outputArray: ptr<array<array<u32, MAX_GROUP_SIZE>, MAX_GROUPS>>) {
//     var groupIndex: u32 = 0;
//     var elementIndex: u32 = 0;

//   for (var i: u32 = 0; i < arrayLength(&values); i++) {
//     if (values[i] == COMMA) {
//       // Move to the next group
//       groupIndex = groupIndex + 1;
//       elementIndex = 0;
//       if (groupIndex >= MAX_GROUPS) {
//         break; // Exceeded the maximum number of groups
//       }
//     } else {
//       // Add the value to the current group
//       if (elementIndex < MAX_GROUP_SIZE) {
//         (*outputArray)[groupIndex][elementIndex] = values[i];
//         elementIndex = elementIndex + 1;
//       }
//     }
//   }
// }


@group(0) @binding(0) var<storage, read_write> rowStartInds: array<u32>;
@group(0) @binding(1) var<storage, read_write> rowCount: atomic<u32>;
@group(0) @binding(2) var csvTexture : texture_2d_array<u32>;
@compute @workgroup_size(32, 32)
fn main(
  @builtin(global_invocation_id) GlobalInvocationID : vec3<u32>
) {
  let pixel: vec4<u32> = textureLoad(
    csvTexture, 
    vec2(GlobalInvocationID.x, GlobalInvocationID.y),
    GlobalInvocationID.z,
    0
  );

  var texPos = vec3<u32>(
    GlobalInvocationID.x, GlobalInvocationID.y,  GlobalInvocationID.z
  );
  var rowStartPixelIndex = getFlatIndex(texPos);
  var rowStartIndex = rowStartPixelIndex * 4;

  let channelOffset = channelOf(pixel, NEWLINE);
  if (channelOffset == NOT_FOUND) {
    // No new line at this pixel
    return;
  }
  rowStartIndex += channelOffset;
  rowStartInds[atomicAdd(&rowCount, 1u)] = rowStartIndex; 

      
  let colInfo = getIndicesOfColumn(EI);
  let eiPixelInd = (rowStartIndex + colInfo.start) / 4u;
  let eiTexPos = getPosition(eiPixelInd);
  let ei_pixel: vec4<u32> = textureLoad(
    csvTexture, 
    vec2(eiTexPos.x, eiTexPos.y),
    eiTexPos.z,
    0
  );

  if (isExport(ei_pixel) == false) {
    // We don't care about this row
    return;
  }

  /* Shitty code start */

  // Read in q1 one pixel at a time (assuming 3 pixels max)
  // 1st Pixel
  var q1Info = getIndicesOfColumn(Q1);
  var q1Ind = rowStartIndex + q1Info.start;
  var q1PixelInd = q1Ind / 4u;
  var q1TexPos = getPosition(q1PixelInd);
  let q1_pixel_1: vec4<u32> = textureLoad(
    csvTexture, 
    vec2(q1TexPos.x, q1TexPos.y),
    q1TexPos.z,
    0
  );
  // 2nd pixel
  q1PixelInd += 1;
  q1TexPos = getPosition(q1PixelInd);
  let q1_pixel_2: vec4<u32> = textureLoad(
    csvTexture,
    vec2(q1TexPos.x, q1TexPos.y),
    q1TexPos.z,
    0
  );
  // 3rd pixel
  q1PixelInd += 1;
  q1TexPos = getPosition(q1PixelInd);
  let q1_pixel_3: vec4<u32> = textureLoad(
    csvTexture,
    vec2(q1TexPos.x, q1TexPos.y),
    q1TexPos.z,
    0
  );


  // Read in q2 one pixel at a time (assuming 3 pixels max)
  // 1st Pixel
  var q2PixelInd: u32 = q1PixelInd + 1;
  var q2TexPos = getPosition(q2PixelInd);
  let q2_pixel_1: vec4<u32> = textureLoad(
    csvTexture, 
    vec2(q2TexPos.x, q2TexPos.y),
    q2TexPos.z,
    0
  );
  // 2nd pixel
  q2PixelInd += 1;
  q2TexPos = getPosition(q2PixelInd);
  let q2_pixel_2: vec4<u32> = textureLoad(
    csvTexture,
    vec2(q2TexPos.x, q2TexPos.y),
    q2TexPos.z,
    0
  );
  // 3rd pixel
  q2PixelInd += 1;
  q2TexPos = getPosition(q2PixelInd);
  let q2_pixel_3: vec4<u32> = textureLoad(
    csvTexture,
    vec2(q2TexPos.x, q2TexPos.y),
    q2TexPos.z,
    0
  );

  let qVals = array<u32, 24>(
    q1_pixel_1.r, q1_pixel_1.g, q1_pixel_1.b, q1_pixel_1.a,
    q1_pixel_2.r, q1_pixel_2.g, q1_pixel_2.b, q1_pixel_2.a,
    q1_pixel_3.r, q1_pixel_3.g, q1_pixel_3.b, q1_pixel_3.a,

    q2_pixel_1.r, q2_pixel_1.g, q2_pixel_1.b, q2_pixel_1.a,
    q2_pixel_2.r, q2_pixel_2.g, q2_pixel_2.b, q2_pixel_2.a,
    q2_pixel_3.r, q2_pixel_3.g, q2_pixel_3.b, q2_pixel_3.a,
  );
  var comma1: u32 = 0;
  var comma2: u32 = 0;
  var first = true;
  for (var i: u32 = 0; i < 24; i++) {
    if (qVals[i] == COMMA) {
      if (first) {
        comma1 = i;
        first = false;
      } else {
        comma2 = i;
        break;
      }
    }
  }


  var q1Val: u32 = 0;
  for (var i: u32 = 0; i < comma1; i++) {
    q1Val += qVals[i] * u32(pow(10.0, f32(comma1 - i - 1)));
  }
  var q2Val: u32 = 0;
  for (var i: u32 = comma1 + 1; i < comma2; i++) {
    q2Val += qVals[i] * u32(pow(10.0, f32(comma2 - (comma1 + i) - 1)));
  }
 
  return;
}
