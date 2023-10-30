use std::{
    fs::File,
    os::unix::prelude::FileExt,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc,
    },
};

use crate::{error::Error, ResultsMap, READ_BUFFER_SIZE};

// ASCII
const NEW_LINE: u8 = 10;
const CARRIAGE_RETURN: u8 = 13;
const COMMA: u8 = 44;
const ZERO: u8 = 48;
const ONE: u8 = 49;
const TWO: u8 = 50;

// If we don't hit end of line perfectly, we will read it anyway, even though it goes beyond the block.
// That way, if we start reading a block not at the beginning of a line, we can skip the first line.
pub(crate) fn parse_block(
    cpu: usize,
    file: File,
    mut offset: u64,
    end: Arc<AtomicU64>,
    prev: Option<Arc<AtomicU64>>,
    years: &mut ResultsMap,
) {
    let mut skip = true;
    loop {
        if offset >= (end.load(Ordering::Acquire)) {
            break;
        }

        let mut buf = [0; READ_BUFFER_SIZE];
        let bytes = file.read_at(&mut buf, offset).expect("failed to read");

        let mut start = 0;
        // skip to next line to make sure we don't split a line in half
        if cpu != 0 && skip {
            let mut idx = 0;
            while idx < bytes {
                if buf[idx] == NEW_LINE {
                    break;
                }
                idx += 1;
            }
            if let Some(prev) = &prev {
                prev.fetch_add(idx as u64, Ordering::Release);
            }
            skip = false;
            start = idx;
        }

        // Nothing more to read.
        if bytes == 0 {
            break;
        }

        match parse_lines(&buf, start, years) {
            Ok(_) => {
                offset += bytes as u64;
            }
            Err(Error::NotFullLine(off)) => {
                offset += off;
            }
            Err(Error::PartialValue(off)) => {
                offset += off;
            }
            Err(err) => {
                panic!("cpu {} error: {:?}", cpu, err);
            }
        }
    }
}

fn parse_lines(line: &[u8], start: usize, years: &mut ResultsMap) -> Result<(), Error> {
    let mut off = start;
    while off <= line.len() {
        if off < line.len() && line[off] == NEW_LINE {
            off += 1;
        }

        // ym(Year + month), exp_imp(export: 1, import: 2), Country, Customs, hs9(HS code), Q1,Q2(quantity), Value(in thousands of yen)
        let (year, next_off) = parse_value(line, off, off)?;
        let (exp_imp, next_off) = parse_value(line, off, next_off)?;
        let (country, next_off) = parse_value(line, off, next_off)?;
        let (_customs, next_off) = parse_value(line, off, next_off)?;
        let (_hs9, next_off) = parse_value(line, off, next_off)?;
        let (_q1, next_off) = parse_value(line, off, next_off)?;
        let (_q2, next_off) = parse_value(line, off, next_off)?;
        let (value, next_off) = parse_value(line, off, next_off)?;

        off = next_off;

        let year = get_year(get_value_u16(&year[..4]))?;
        let year = &mut years[usize::from(year)];

        let country = get_value_u16(country);
        let country_lookup = country_to_u8(country)?;
        year.countries[usize::from(country_lookup)].value = country;
        let exp_imp = get_exp_imp(exp_imp[0]);
        if exp_imp {
            year.countries[usize::from(country_lookup)].exports += get_value_u32(value) as u64;
        } else {
            year.countries[usize::from(country_lookup)].imports += get_value_u32(value) as u64;
        }
    }
    Ok(())
}

fn parse_value(line: &[u8], start: usize, off: usize) -> Result<(&[u8], usize), Error> {
    let mut idx = off;
    loop {
        if idx >= line.len() {
            return Err(Error::PartialValue(start as u64));
        }

        if line[idx] == CARRIAGE_RETURN && idx + 1 > line.len() {
            return Err(Error::NotFullLine(start as u64));
        }

        if line[idx] == COMMA || line[idx] == CARRIAGE_RETURN {
            break;
        }

        idx += 1;
    }

    let mut next_off = 0;
    if line[idx] == COMMA {
        next_off = idx + 1;
    }

    if line[idx] == CARRIAGE_RETURN {
        next_off = idx + 2;
    }

    Ok((&line[off..idx], next_off))
}

fn get_year(year: u16) -> Result<u8, Error> {
    if !(1988..=2020).contains(&year) {
        return Err(Error::InvalidYear(year));
    }
    Ok((year - 1988) as u8)
}

fn get_value_u16(value: &[u8]) -> u16 {
    let mut val = 0;
    for byte in value {
        val *= 10;
        val += u16::from(byte - ZERO);
    }
    val
}

fn get_value_u32(value: &[u8]) -> u32 {
    let mut val = 0;
    for byte in value {
        val *= 10;
        val += u32::from(byte - ZERO);
    }
    val
}

fn get_exp_imp(exp_imp: u8) -> bool {
    match exp_imp {
        ONE => true,
        TWO => false,
        _ => panic!("invalid exp_imp"),
    }
}

fn country_to_u8(country: u16) -> Result<u8, Error> {
    let val = match country {
        103 => 0,
        104 => 1,
        105 => 2,
        106 => 3,
        107 => 4,
        108 => 5,
        110 => 6,
        111 => 7,
        112 => 8,
        113 => 9,
        116 => 10,
        117 => 11,
        118 => 12,
        120 => 13,
        121 => 14,
        122 => 15,
        123 => 16,
        124 => 17,
        125 => 18,
        126 => 19,
        127 => 20,
        128 => 21,
        129 => 22,
        130 => 23,
        131 => 24,
        132 => 25,
        133 => 26,
        134 => 27,
        135 => 28,
        136 => 29,
        137 => 30,
        138 => 31,
        140 => 32,
        141 => 33,
        142 => 34,
        143 => 35,
        144 => 36,
        145 => 37,
        146 => 38,
        147 => 39,
        148 => 40,
        149 => 41,
        150 => 42,
        151 => 43,
        152 => 44,
        153 => 45,
        154 => 46,
        155 => 47,
        156 => 48,
        157 => 49,
        158 => 50,
        201 => 51,
        202 => 52,
        203 => 53,
        204 => 54,
        205 => 55,
        206 => 56,
        207 => 57,
        208 => 58,
        209 => 59,
        210 => 60,
        211 => 61,
        212 => 62,
        213 => 63,
        214 => 64,
        215 => 65,
        216 => 66,
        217 => 67,
        218 => 68,
        219 => 69,
        220 => 70,
        221 => 71,
        222 => 72,
        223 => 73,
        224 => 74,
        225 => 75,
        226 => 76,
        227 => 77,
        228 => 78,
        229 => 79,
        230 => 80,
        231 => 81,
        232 => 82,
        233 => 83,
        234 => 84,
        235 => 85,
        236 => 86,
        237 => 87,
        238 => 88,
        239 => 89,
        240 => 90,
        241 => 91,
        242 => 92,
        243 => 93,
        244 => 94,
        245 => 95,
        246 => 96,
        247 => 97,
        248 => 98,
        249 => 99,
        250 => 100,
        301 => 101,
        302 => 102,
        303 => 103,
        304 => 104,
        305 => 105,
        306 => 106,
        307 => 107,
        308 => 108,
        309 => 109,
        310 => 110,
        311 => 111,
        312 => 112,
        313 => 113,
        314 => 114,
        315 => 115,
        316 => 116,
        317 => 117,
        319 => 118,
        320 => 119,
        321 => 120,
        322 => 121,
        323 => 122,
        324 => 123,
        325 => 124,
        326 => 125,
        327 => 126,
        328 => 127,
        329 => 128,
        330 => 129,
        331 => 130,
        332 => 131,
        333 => 132,
        334 => 133,
        335 => 134,
        336 => 135,
        337 => 136,
        338 => 137,
        401 => 138,
        402 => 139,
        403 => 140,
        404 => 141,
        405 => 142,
        406 => 143,
        407 => 144,
        408 => 145,
        409 => 146,
        410 => 147,
        411 => 148,
        412 => 149,
        413 => 150,
        414 => 151,
        415 => 152,
        501 => 153,
        502 => 154,
        503 => 155,
        504 => 156,
        505 => 157,
        506 => 158,
        507 => 159,
        508 => 160,
        509 => 161,
        510 => 162,
        511 => 163,
        512 => 164,
        513 => 165,
        514 => 166,
        515 => 167,
        516 => 168,
        517 => 169,
        518 => 170,
        519 => 171,
        520 => 172,
        521 => 173,
        522 => 174,
        523 => 175,
        524 => 176,
        525 => 177,
        526 => 178,
        527 => 179,
        528 => 180,
        529 => 181,
        530 => 182,
        531 => 183,
        532 => 184,
        533 => 185,
        534 => 186,
        535 => 187,
        536 => 188,
        537 => 189,
        538 => 190,
        539 => 191,
        540 => 192,
        541 => 193,
        542 => 194,
        543 => 195,
        544 => 196,
        545 => 197,
        546 => 198,
        547 => 199,
        548 => 200,
        549 => 201,
        550 => 202,
        551 => 203,
        552 => 204,
        553 => 205,
        554 => 206,
        555 => 207,
        556 => 208,
        557 => 209,
        558 => 210,
        559 => 211,
        560 => 212,
        601 => 213,
        602 => 214,
        605 => 215,
        606 => 216,
        607 => 217,
        608 => 218,
        609 => 219,
        610 => 220,
        611 => 221,
        612 => 222,
        613 => 223,
        614 => 224,
        615 => 225,
        616 => 226,
        617 => 227,
        618 => 228,
        619 => 229,
        620 => 230,
        621 => 231,
        622 => 232,
        623 => 233,
        624 => 234,
        625 => 235,
        626 => 236,
        627 => 237,
        628 => 238,
        701 => 239,
        702 => 240,
        703 => 241,
        _ => return Err(Error::InvalidCountry(country)),
    };

    Ok(val)
}
