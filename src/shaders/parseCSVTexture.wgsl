//  YM   e/i  hs9  cus, country,   q1, q2,    yen
// 198801, 1, 103, 100, 000000190, 0,  35843, 34353
// 198801, 1, 103, 100, 120991000, 0,  1590,  4154
// 198801, 1, 103, 100, 210390900, 0,  4500,  2565
// 198801, 1, 103, 100, 220890200, 0,  3000,  757
// 198801, 1, 103, 100, 240220000, 0,  26000, 40668
// 198801, 1, 103, 100, 250410000, 0,  5,     8070
// 198801, 1, 103, 100, 271000700, 0,  374,   2485
// 198801, 1, 103, 100, 271220000, 0,  400,   616

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

var <workgroup> characters: array<u32, 50>;

@group(0) @binding(0) var<storage, read_write> rowStartInds : array<u32>;
@group(0) @binding(0) var<storage, read_write> exportCount: array<atomic<u32>, 259>; // 259 country codes
@group(0) @binding(2) var csvTexture : texture_2d_array<u32>;

@compute @workgroup_size(13)
fn main(
  @builtin(global_invocation_id) GlobalInvocationID : vec3<u32>,
  @builtin(workgroup_invocation_id) WorkgroupInvocationID: vec3<u32>,
  @builtin(local_invocation_id) LocalInvocationID: vec3<u32>
) {

  let wgIndex = WorkgroupInvocationID.x + WorkgroupInvocationID.y * wg_per_dim + WorkgroupInvocationID.z * wg_per_dim_sq;

  rowStart

  let characterIndex = GlobalInvocationID.x + GlobalInvocationID.y * TEXWIDTH + GlobalInvocationID.z * TEXWIDTH_SQ;
  let characterOffset = LocalInvocationID.x;

  let pixel: vec4<u32> = textureLoad(
    csvTexture, 
    vec2(GlobalInvocationID.x, GlobalInvocationID.y),
    GlobalInvocationID.z,
    0
  );

  
}
