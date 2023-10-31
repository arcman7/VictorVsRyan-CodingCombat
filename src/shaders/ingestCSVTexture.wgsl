 
//  YM   e/i  hs9  cus, country,   q1, q2,    yen
// 198801, 1, 103, 100, 000000190, 0,  35843, 34353
// 198801, 1, 103, 100, 120991000, 0,  1590,  4154
// 198801, 1, 103, 100, 210390900, 0,  4500,  2565
// 198801, 1, 103, 100, 220890200, 0,  3000,  757
// 198801, 1, 103, 100, 240220000, 0,  26000, 40668
// 198801, 1, 103, 100, 250410000, 0,  5,     8070
// 198801, 1, 103, 100, 271000700, 0,  374,   2485
// 198801, 1, 103, 100, 271220000, 0,  400,   616


// [48 – 57]
// It can be observed that ASCII value of digits [0 – 9] ranges from [48 – 57].
const ZERO: i32 = 48;
const ONE: i32 = 49;
const TWO: i32 = 50;

const RETURNLINE: i32 = -13;
const NEWLINE: i32 = -10;

const TEXWIDTH: u32 = 8192;
const TEXWIDTH_F: f32 = 8192;
const TEXWIDTH_SQ: u32 = 8192 * 8192;

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
// @group(0) @binding(2) var csvTextureSampler : sampler;
// @group(0) @binding(3) var csvTexture : texture_2d_array<u32>;
// @group(0) @binding(2) var csvTexture : texture_storage_2d_array<rgba8uint, read>;
@group(0) @binding(2) var csvTexture : texture_2d_array<u32>;


// @compute @workgroup_size(50)
@compute @workgroup_size(32, 32)
fn main(@builtin(global_invocation_id) GlobalInvocationID : vec3<u32>) {
    // let heightMapColor: vec4<f32> = textureSampleLevel(heightMap, heightMapSampler, vec2(normalizedX, normalizedZ), 0.1);

  // let pixel: vec4<u32> = textureSample(
  //   csvTexture, csvTextureSampler, vec2(
  //     f32(GlobalInvocationID.x) / TEXWIDTH_F, f32(GlobalInvocationID.y) / TEXWIDTH_F
  //   ),
  //   GlobalInvocationID.z
  // );

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
  
  if (c0 == RETURNLINE) {
    rowStartInds[atomicAdd(&rowCount, 1u)] = characterIndex + 0;
    return;
  }
  if (c1 == RETURNLINE) {
    rowStartInds[atomicAdd(&rowCount, 1u)] = characterIndex + 1;
    return;
  }
  if (c2 == RETURNLINE) {
    rowStartInds[atomicAdd(&rowCount, 1u)] = characterIndex + 2;
    return;
  }
  if (c3 == RETURNLINE) {
    rowStartInds[atomicAdd(&rowCount, 1u)] = characterIndex + 3;
    return;
  }
}
