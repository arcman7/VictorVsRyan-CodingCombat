
/* disable_uniformity_analysis */
const PIXELS_PER_ROW: i32 = 13; // Assumption about the csv file
 // Index where we need to begin parsing pixel by pixel
const UNKNOWN_START_IND: i32 = 27;
// const UNKNOWN_START_PIXEL: i32 = 6; // 27 / 4u


//  YM   e/i  coun cus     hs9        q1   q2     yen
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
const COUNTRY_A = array<u32,9>(9,10,11,0,0,0,0,0,0);
const CUSTOMS_A= array<u32,9>(13,14,15,0,0,0,0,0,0);
const HS9_A = array<u32,9>(17,18,19,20,21,22,23,24,25);
const Q1_A = array<u32,9>(26,0,0,0,0,0,0,0,0);
const UNKNOWN_A = array<u32,9>(0,0,0,0,0,0,0,0,0);

const YM: u32 = 0;
const EI: u32 = 1;
const COUNTRY: u32 = 2;
const CUSTOMS: u32 = 3;
const HS9: u32 = 4;
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
    case COUNTRY: {
      let info: ColumnIndsInfo = ColumnIndsInfo(COUNTRY_A, 3, 9);
      return info;
    }
    case CUSTOMS: {
      let info: ColumnIndsInfo = ColumnIndsInfo(CUSTOMS_A, 3, 13);
      return info;
    }
    case HS9: {
      let info: ColumnIndsInfo = ColumnIndsInfo(HS9_A, 9, 17);
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
const NOT_FOUND: u32 = 4;
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

fn getNumVal(charCode: u32) -> u32 {
  return charCode - 48;
}

const RETURNLINE: u32 = 13;
const NEWLINE: u32 = 10;
const COMMA: u32 = 44;

const DESCENDING: u32 = 0;
const ASCENDING: u32 = 1;

const QUERY_ROWS = u32(/*QUERY_ROWS*/);
// TODO: Write this value in with js

struct Query {
  indexByColumn: u32,
  quantityColumn: u32,
  indexColumnRangeStart: u32,
  indexColumnRangeEnd: u32,
  sortBy: u32,
  keep: u32,
  // valsList: array<atomic<u32>, QUERY_ROWS>
  valsList: array<array<atomic<u32>, 50>, QUERY_ROWS>
}

const CURRENT_YEAR: u32 = 2023;


@group(0) @binding(0) var<storage, read_write> query: Query;
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



  var channelOffset = channelOf(pixel, NEWLINE);
  if (channelOffset == NOT_FOUND) {
    // No new line at this pixel
    return;
  }
  var texPos = vec3<u32>(
    GlobalInvocationID.x, GlobalInvocationID.y,  GlobalInvocationID.z
  );
  var rowStartPixelIndex = getFlatIndex(texPos);
  var rowStartIndex = rowStartPixelIndex * 4u;

  channelOffset += 1u; // actual start of new row
  rowStartIndex += channelOffset;
  atomicAdd(&rowCount, 1u);
  // rowStartInds[atomicAdd(&rowCount, 1u)] = rowStartIndex;

  // Read in the YM column, assumed to be 3 pixels max
  let ymColInfo = getIndicesOfColumn(YM);
  let ymPixelInd1 = (rowStartIndex + ymColInfo.start) / 4u;
  let ymPixelInd2 = (rowStartIndex + ymColInfo.start + 4u) / 4u;
  let ymPixelInd3 = (rowStartIndex + ymColInfo.start + 8u) / 4u;
  var ymTexPos = getPosition(ymPixelInd1);
  let ym_pixel_1: vec4<u32> = textureLoad(
    csvTexture,
    vec2(ymTexPos.x, ymTexPos.y),
    ymTexPos.z,
    0
  );
  ymTexPos = getPosition(ymPixelInd2);
  let ym_pixel_2: vec4<u32> = textureLoad(
    csvTexture,
    vec2(ymTexPos.x, ymTexPos.y),
    ymTexPos.z,
    0
  );
  ymTexPos = getPosition(ymPixelInd3);
  let ym_pixel_3: vec4<u32> = textureLoad(
    csvTexture,
    vec2(ymTexPos.x, ymTexPos.y),
    ymTexPos.z,
    0
  );
  let ymValues = array<u32, 12>(
    ym_pixel_1.r, ym_pixel_1.g, ym_pixel_1.a, ym_pixel_1.b,
    ym_pixel_2.r, ym_pixel_2.g, ym_pixel_2.a, ym_pixel_2.b,
    ym_pixel_3.r, ym_pixel_3.g, ym_pixel_3.a, ym_pixel_3.b,
  );
  var yOffset = channelOf(ym_pixel_1, NEWLINE);
  if (yOffset == NOT_FOUND) {
    yOffset = 0;
  } else {
    yOffset += 1;
  }
  var ymVal: u32 = 0;
  ymVal += getNumVal(ymValues[yOffset + 0]) * 1000;
  ymVal += getNumVal(ymValues[yOffset + 1]) * 100;
  ymVal += getNumVal(ymValues[yOffset + 2]) * 10;
  ymVal += getNumVal(ymValues[yOffset + 3]);
  // for (var i: u32 = yOffset; i < 4 + yOffset; i++) {
  //   ymVal += getNumVal(ymValues[i]) * u32(pow(10.0, f32(3 - i - yOffset)));
  // }

  let eiColInfo = getIndicesOfColumn(EI);
  let eiPixelInd = (rowStartIndex + eiColInfo.start) / 4u;
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

  let cColInfo = getIndicesOfColumn(COUNTRY);
  let countryPixel1Ind = (rowStartIndex + cColInfo.start)/4;
  let countryPixel2Ind = (rowStartIndex + cColInfo.start + 4)/4;

  var countryTexPos = getPosition(countryPixel1Ind);
  let country_pixel_1 = textureLoad(
    csvTexture,
    vec2(countryTexPos.x, countryTexPos.y),
    countryTexPos.z,
    0
  );
  // var country_pixel_2 = vec4<u32>(COMMA, 0, 0, 0);
  // if (countryPixel1Ind != countryPixel2Ind) {
  countryTexPos = getPosition(countryPixel2Ind);
  let country_pixel_2 = textureLoad(
    csvTexture,
    vec2(countryTexPos.x, countryTexPos.y),
    countryTexPos.z,
    0
  );
  // }

  let countryPixelVals = array<u32, 8>(
    country_pixel_1.r, country_pixel_1.g, country_pixel_1.b, country_pixel_1.a, 
    country_pixel_2.r, country_pixel_2.g, country_pixel_2.b, country_pixel_2.a, 
  );

  var commaOffset = channelOf(country_pixel_1, COMMA);

  var cOffset: u32 = 0; //channelOffset;
  if (commaOffset != NOT_FOUND) {
    cOffset = commaOffset + 1;
  }

  var countryVal: u32 = 0;
  // let cOffset = (channelOffset + cColInfo.start) % 4;
  countryVal += getNumVal(countryPixelVals[cOffset + 0]) * 100;
  countryVal += getNumVal(countryPixelVals[cOffset + 1]) * 10;
  countryVal += getNumVal(countryPixelVals[cOffset + 2]);
  let yearCol = CURRENT_YEAR - ymVal;

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


  var q1Offset = channelOf(q1_pixel_1, COMMA);
  if (q1Offset == NOT_FOUND) {
    q1Offset = 0;
  } else {
    q1Offset += 1;
  }

  var comma1: u32 = 0;
  var comma2: u32 = 0;
  var first = true;
  for (var i: u32 = q1Offset; i < 24; i++) {
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
  for (var i: u32 = q1Offset; i < comma1; i++) {
    if (qVals[i] == COMMA) {
      q1Val = 420;
      atomicAdd(&query.valsList[countryVal][yearCol], q1Val);
      return;
    }
    q1Val += getNumVal(qVals[i]) * u32(pow(10.0, f32(comma1 - i - 1 - q1Offset)));
  }
  var q2Val: u32 = 0;
  for (var i: u32 = comma1 + 1; i < comma2; i++) {
    if (qVals[i] == COMMA) {
      q1Val = 0;
      q2Val = 420;
      atomicAdd(&query.valsList[countryVal][yearCol], q1Val + q2Val);
      return;
    }
    q2Val += getNumVal(qVals[i]) * u32(pow(10.0, f32(comma2 - i - 1)));
  }

  
  // atomicAdd(&query.valsList[countryVal][yearCol], q1Val + q2Val);
  // atomicExchange(&query.valsList[ countryVal % 242][yearCol], countryVal);
  // if (GlobalInvocationID.z != 12 ) {
  //   return;
  // }
  // if (GlobalInvocationID.z != 7 && GlobalInvocationID.z != 10 && GlobalInvocationID.z != 11 && GlobalInvocationID.z != 15 ) {
  //   return;
  // }
  if (GlobalInvocationID.z > 15) {
    return;
  }
  // atomicExchange(&query.valsList[countryVal][yearCol], countryVal);

  atomicAdd(&query.valsList[countryVal][yearCol], q1Val + q2Val);
  // if (GlobalInvocationID.z <= 12 && GlobalInvocationID.z >=12) {
  //   return;
  // }
  // atomicStore(&query.valsList[countryVal][yearCol], rowStartIndex);
  // atomicExchange(&query.valsList[ countryVal][yearCol], ymVal);
}
