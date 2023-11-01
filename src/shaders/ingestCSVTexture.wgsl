 
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
  length: i32,
  start: i32,
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
      let info: ColumnIndsInfo = ColumnIndsInfo(Q1_A, -1, 27);
      return info;
    }
    case Q2: {
      let info: ColumnIndsInfo = ColumnIndsInfo(UNKNOWN_A, -1, -1);
      return info;
    }
    case YEN: {
      let info: ColumnIndsInfo = ColumnIndsInfo(UNKNOWN_A, -1, -1);
      return info;
    }
    default: {
      let info: ColumnIndsInfo = ColumnIndsInfo(UNKNOWN_A, -1, -1);
      return info;
    }
  }
}

const ZERO: i32 = 48;
const ONE: i32 = 49;
const TWO: i32 = 50;

const TEXWIDTH: u32 = 8192;
const TEXWIDTH_F: f32 = 8192;
const TEXWIDTH_SQ: u32 = 8192 * 8192;

const R: u32 = 0;
const G: u32 = 1;
const B: u32 = 2;
const A: u32 = 3;

const RETURNLINE: i32 = -13;
const NEWLINE: i32 = -10;

// It can be observed that ASCII value of digits [0 – 9] ranges from [48 – 57].

fn matchCodeToVal(code: u32) -> i32 {
  if (code < 48) {
    return i32(code) * -1;
  }
  if (code > 57) {
    return i32(code) * -1;
  }
  return i32(code - 48);
}

@group(0) @binding(0) var<storage, read_write> rowStartInds : array<u32>;
@group(0) @binding(1) var<storage, read_write> rowCount: atomic<u32>;
@group(0) @binding(2) var csvTexture : texture_2d_array<u32>;
//debug
// @group(0) @binding(3) var <storage, read_write> rowCountsPerLayer: array<atomic<u32>, 17>;
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

  let c0: i32 = matchCodeToVal(pixel.r);
  let c1: i32 = matchCodeToVal(pixel.g);
  let c2: i32 = matchCodeToVal(pixel.b);
  let c3: i32 = matchCodeToVal(pixel.a);

  let characterIndex = GlobalInvocationID.x + GlobalInvocationID.z * TEXWIDTH + GlobalInvocationID.z * TEXWIDTH_SQ;

  // var characterLocation = vec3<u32>(
  //   GlobalInvocationID.x, GlobalInvocationID.y,  GlobalInvocationID.z
  // );
  
  if (c0 == RETURNLINE) {
    rowStartInds[atomicAdd(&rowCount, 1u)] = characterIndex + R + 1; // \n character always comes after \r
    // atomicAdd(&rowCountsPerLayer[GlobalInvocationID.z], 1u);

    
    return;
  }
  if (c1 == RETURNLINE) {
    rowStartInds[atomicAdd(&rowCount, 1u)] = characterIndex + G + 1; // \n character always comes after \r
    // atomicAdd(&rowCountsPerLayer[GlobalInvocationID.z], 1u);
    return;
  }
  if (c2 == RETURNLINE) {
    rowStartInds[atomicAdd(&rowCount, 1u)] = characterIndex + B + 1; // \n character always comes after \r
    // atomicAdd(&rowCountsPerLayer[GlobalInvocationID.z], 1u);
    return;
  }
  if (c3 == RETURNLINE) {
    rowStartInds[atomicAdd(&rowCount, 1u)] = characterIndex + A + 1; // \n character always comes after \r
    // atomicAdd(&rowCountsPerLayer[GlobalInvocationID.z], 1u);
    return;
  }
}
