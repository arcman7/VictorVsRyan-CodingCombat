#![feature(ascii_char)]

use memmap2::Mmap;
use std::{fs::File, thread};

const MIN_YEAR: u16 = 1988;
const YEAR_BITS: usize = 6;
const MAX_COUNTRIES: usize = 1000;
const MAX_YEARS: usize = 1 << YEAR_BITS;

fn country_year_index(country: u16, year: u16) -> usize {
    (country as usize) << YEAR_BITS | (year - MIN_YEAR) as usize
}

fn index_to_country_year(index: usize) -> (u16, u16) {
    let year = (index & ((1 << YEAR_BITS) - 1)) + MIN_YEAR as usize;
    let country = index >> YEAR_BITS;
    (country as u16, year as u16)
}

struct Results {
    totals: [u64; MAX_YEARS * MAX_COUNTRIES],
}

impl Default for Results {
    fn default() -> Self {
        Self {
            totals: [0; MAX_YEARS * MAX_COUNTRIES],
        }
    }
}

fn process(data: &[u8]) -> Results {
    let mut ret = Results::default();

    let mut pos = 0;
    let data_len = data.len();

    while pos < data_len {
        // pos is the start of a line

        if data[pos + 7] == b'1' {
            // this is an export

            let value_start = {
                // the first 5 fields are fixed-length
                let mut start = pos + 28;
                // we're now looking at the second character of the sixth field

                // skip over 2 commas to get to the eighth field

                while data[start] != b',' {
                    start += 1;
                }
                start += 2;

                while data[start] != b',' {
                    start += 1;
                }
                start += 1;

                start
            };

            let year = (data[pos] - b'0') as u16 * 1000
                + (data[pos + 1] - b'0') as u16 * 100
                + (data[pos + 2] - b'0') as u16 * 10
                + (data[pos + 3] - b'0') as u16;

            let country = (data[pos + 9] - b'0') as u16 * 100
                + (data[pos + 10] - b'0') as u16 * 10
                + (data[pos + 11] - b'0') as u16;

            let mut value = 0;
            pos = value_start;
            while data[pos] != b'\r' {
                value = value * 10 + (data[pos] - b'0') as u64;
                pos += 1;
            }
            pos += 2;

            let index = country_year_index(country, year);
            ret.totals[index] += value;
        } else {
            pos += 32;

            while data[pos] != b'\r' {
                pos += 1;
            }

            pos += 2;
        }
    }

    ret
}

fn split_at_newlines<'a>(data: &'a [u8], count: usize) -> Vec<&'a [u8]> {
    let mut result = Vec::with_capacity(count);
    let data_len = data.len();
    let estimated_part_size = data_len / count;

    let mut offset = 0;
    while offset < data_len {
        let mut end = offset + estimated_part_size;
        while end < data_len {
            if data[end] == b'\n' {
                end += 1;
                break;
            }
            end += 1;
        }
        if end >= data_len || result.len() == count - 1 {
            // last part
            result.push(&data[offset..]);
            break;
        } else {
            result.push(&data[offset..end]);
            offset = end + 1;
        }
    }

    return result;
}

fn main() {
    let f = File::open("../data/custom_1988_2020.csv").unwrap();
    let mmap = unsafe { Mmap::map(&f) }.unwrap();

    let parallelism = thread::available_parallelism().unwrap().get();

    thread::scope(|s| {
        let parts = split_at_newlines(&mmap, parallelism);

        let join_handles = parts
            .into_iter()
            .map(|part| s.spawn(move || process(part)))
            .collect::<Vec<_>>();

        let mut results = Results::default();

        for join_handle in join_handles {
            let part_results = join_handle.join().unwrap();
            for (i, total) in part_results.totals.iter().enumerate() {
                results.totals[i] += total;
            }
        }

        let (best_index, best_total) = results
            .totals
            .iter()
            .enumerate()
            .max_by_key(|(_, total)| *total)
            .unwrap();

        let (best_country, best_year) = index_to_country_year(best_index);

        println!(
            "Japan -> {} in {}, total value: {}\n",
            best_country, best_year, best_total
        );
    });
}
