use std::fmt::{Display, Formatter, Result};

#[derive(thiserror::Error, Debug)]
pub(crate) enum Error {
    InvalidCountry(u16),
    InvalidYear(u16),
    NotFullLine(u64),
    PartialValue(u64),
}

impl Display for Error {
    fn fmt(&self, f: &mut Formatter<'_>) -> Result {
        match self {
            Error::InvalidCountry(country) => write!(f, "InvalidCountry {country} error"),
            Error::InvalidYear(year) => write!(f, "InvalidYear {year:?} error"),
            Error::NotFullLine(_) => write!(f, "NotFullLine error"),
            Error::PartialValue(_) => write!(f, "PartialValue error"),
        }
    }
}
