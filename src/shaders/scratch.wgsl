// Assume the atlas texture is of size 256x256 and contains 16x16 characters.
// Each character cell is thus 16x16 pixels in size.

// Atlas texture
[[group(0), binding(0)]] var atlas_texture: texture_2d<f32>;

// Sampler
[[group(0), binding(1)]] var sampler: sampler;

fn get_uv(char_val: u32) -> vec2<f32> {
    // Compute the row and column of the character in the atlas
    let column = char_val % 16u;
    let row = char_val / 16u;
    
    // Compute the UV coordinates for the top-left of the character cell
    let u = f32(column) / 16.0;
    let v = f32(row) / 16.0;

    return vec2<f32>(u, v);
}

fn sample_atlas(char_val: u32, offset: vec2<f32>) -> vec4<f32> {
    let base_uv = get_uv(char_val);
    
    // Incorporate the offset to sample within the character cell
    // This can be used to traverse through the 16x16 character cell
    let sample_uv = base_uv + (offset / 16.0);
    
    return textureSample(atlas_texture, sampler, sample_uv);
}

//Usage:
// When you want to sample a specific ASCII character, say A (which has an ASCII value of 65), you'd call sample_atlas(65u, vec2<f32>(x, y)) where x and y are the offsets within the 16x16 cell.
// Note: The above code assumes the texture is arranged in a 16x16 grid. Adjust as necessary for different configurations.





fn parseCSV(data: texture_format, width: u32, height: u32) -> array<f32, N> {
    var result: array<f32, N> = array<f32, N>();
    
    for (var i: u32 = 0u; i < height; i = i + 1u) {
        for (var j: u32 = 0u; j < width; j = j + 1u) {
            // Sample the texture or read from the buffer at (i, j) and parse the number.
            var value: f32 = // ... Sample or read the value here.
            result[i * width + j] = value;
        }
    }
    
    return result;
}




fn isDelimiter(character: char, delimiter: char) -> bool {
  return character == delimiter;
}

fn findDelimiters(row: string, delimiter: char) -> array<u32, N> {
  var delimiterIndices: array<u32, N> = array<u32, N>();
  var delimiterCount: u32 = 0u;

  for (var i: u32 = 0u; i < row.length(); i = i + 1u) {
    if (isDelimiter(row[i], delimiter)) {
      delimiterIndices[delimiterCount] = i;
       delimiterCount = delimiterCount + 1u;
    }
  }

  // Add an index for the end of the row to handle the last token.
  delimiterIndices[delimiterCount] = row.length();

  return delimiterIndices;
}