// countries with most exports
// avg import money change per year, by country
// profit per year export - import

// format
// ym(Year + month), exp_imp(export: 1, import: 2), Country, Customs, hs9(HS code), Q1,Q2(quantity), Value(in thousands of yen)
// 198801,1,103,100,000000190,0,35843,34353

// NOTES:
// years are 1988 - 2020 which is 32 years, or 1 u8
// we don't care about months
//
// countries range from 103 - 703, which is 600, or 1 u16
// however in terms of unique values there are less than 256, or 1 u8
// so we will make a map of country code to u8
//
// we also need to measure the value of the exports and imports which is in thousands of yen,
// so maybe u32 is enough?

use std::{
    fmt::{Debug, Formatter},
    fs::File,
    sync::{atomic::AtomicU64, Arc},
};

use crate::csv::parse_block;

mod csv;
mod error;

const READ_BUFFER_SIZE: usize = 1024 * 1024;

type ResultsMap = [Results; 33];

#[derive(Copy, Clone)]
struct Results {
    countries: [Country; 256],
}

impl Debug for Results {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Results")
            .field(
                "countries",
                &self
                    .countries
                    .iter()
                    .filter(|c| c.value > 0)
                    .collect::<Vec<_>>(),
            )
            .finish()
    }
}

#[derive(Copy, Clone)]
struct Year {
    // 0 = 1988 & 32 = 2020
    value: u8,

    // Countries we did business with
    countries: [Country; 256],
}

impl Debug for Year {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Year")
            .field("value", &self.value)
            .field(
                "countries",
                &self
                    .countries
                    .iter()
                    .filter(|c| c.value > 0)
                    .collect::<Vec<_>>(),
            )
            .finish()
    }
}

#[derive(Copy, Clone, Debug, Default)]
struct Country {
    value: u16,
    imports: u64,
    exports: u64,
}

struct Boundary {
    min: Arc<AtomicU64>,
}

fn main() {
    let cpus = num_cpus::get();

    let file = File::open("custom_1988_2020.csv").expect("failed to open file");
    let file_size = file.metadata().expect("failed to get metadata").len();
    let blocks = file_size / cpus as u64;

    // I know, I know, this is an allocation... Oh No! lol
    let mut handles = Vec::with_capacity(cpus);

    // parse_block(file, 0, file_size as usize);

    let mut boundaries = vec![];

    for cpu in 0..=cpus {
        let offset = blocks * cpu as u64;
        boundaries.push(Boundary {
            min: Arc::new(AtomicU64::new(offset)),
        });
    }

    for cpu in 0..cpus {
        let offset = blocks * cpu as u64;
        let end = boundaries[cpu + 1].min.clone();
        let prev = if cpu == 0 {
            None
        } else {
            Some(boundaries[cpu].min.clone())
        };

        let handle = std::thread::Builder::new()
            .name(format!("cpu{cpu}"))
            .spawn(move || {
                let file = File::open("custom_1988_2020.csv").expect("failed to open file");

                let mut years = [Results {
                    countries: [Country {
                        value: 0,
                        exports: 0,
                        imports: 0,
                    }; 256],
                }; 33];
                parse_block(cpu, file, offset, end, prev, &mut years);
                years
            })
            .expect("spawn");

        handles.push(handle);
    }

    let mut results = [Results {
        countries: [Country {
            value: 0,
            exports: 0,
            imports: 0,
        }; 256],
    }; 33];

    for handle in handles {
        let res = handle.join();
        match res {
            Ok(years) => {
                for (i, year) in years.iter().enumerate() {
                    for (j, country) in year.countries.iter().enumerate() {
                        let result_year = &mut results[i];
                        let result_country = &mut result_year.countries[j];
                        if country.value == 0 {
                            continue;
                        }

                        result_country.value = country.value;
                        result_country.exports += country.exports;
                        result_country.imports += country.imports;
                    }
                }
            }
            Err(err) => println!("thread panicked: {:?}", err),
        }
    }

    let max_export_country = {
        results.iter().enumerate().map(|(yr, results)| {
            let (country, exports) = results
                .countries
                .iter()
                .map(|c| (c.value, c.exports))
                .max_by_key(|c| c.1)
                .unwrap_or_default();
            (yr as u16 + 1988, country, exports)
        })
    };

    print_table(max_export_country);
}

fn print_table(itr: impl Iterator<Item = (u16, u16, u64)>) {
    let mut table = vec![];

    for (year, country, value) in itr {
        table.push((year, country, value));
    }

    table.sort_by_key(|(year, _, _)| *year);

    for (year, country, value) in table {
        println!("{year}: Japan -> {country} was {value}");
    }
}
