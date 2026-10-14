# finance-core

[![Tests](https://github.com/march-finance/finance-core/actions/workflows/ci.yml/badge.svg)](https://github.com/march-finance/finance-core/actions/workflows/ci.yml)

Licensed under the [MIT License](LICENSE).

## GitHub checkout and CI

Clone the repositories into the same parent directory so Forge's sibling path
dependencies resolve (finance-crypto is test-only for finance-codec integration):

```sh
git clone https://github.com/march-finance/finance-core.git
cd finance-core
forge test --seed=42
```

GitHub Actions runs on pushes, pull requests and manual dispatches. It installs
the pinned March 0.5.0 release, checks/builds this package, and runs debug/release
tests and properties. Dependencies are checked out from their `main` branches.
Compile-time contract checks run with Z3.

March library for exact amounts shared by traditional finance and crypto.
Initialized with `forge init`; package version 0.1.0.
The project pins March 0.5.0 in `.march-version` (install with
`forge toolchain install v0.5.0`). Check the resolved compiler with
`forge toolchain which`. When running `scripts/check-contracts.sh`, set
`MARCH_COMPILER` to that compiler path if your global default differs.

## Modules

| Module | Responsibility |
| --- | --- |
| `FinanceAsset` | Opaque identifiers, fiat/native/token factories, precision |
| `FinanceAmount` | Signed BigInt atom quantities, arithmetic, decimal text, rescaling |
| `FinanceInteger` | Arbitrary-size signed integer division |
| `FinanceRounding` | Exact, truncation, directed, and nearest rounding policies |
| `FinanceRate` | Directional rational rates, inversion, audited conversion |
| `FinanceDate` | Validated Gregorian civil dates and day arithmetic |
| `FinanceMetadata` | Source, effective/recorded UTC seconds, external event identity |
| `FinanceQuote` | Rates with observation provenance |
| `FinanceCodec` | Strict versioned quantity JSON |
| `FinanceError` | Structured validation errors |
| `FinanceCore` | Thin convenience facade for assets and amounts |

The dependency direction is errors → numeric/asset primitives → amounts →
rates → quotes. Dates and provenance are independent; the codec depends only
on assets/amounts. Library code has no network, clock, or storage effects.

## Amounts and conversion

One atom is the smallest accounting unit: USD at precision 2 uses cents; ETH
at precision 18 uses wei. BigInt coefficients avoid machine integer overflow.
Asset precision is bounded to 0..255, with refinements on stored precision,
accessors, rescaling, and powers of ten. Smart constructors and runtime checks
back up those contracts. Opaque constructors prevent invalid values from being
manufactured outside their modules.

```march
mod Example do
  fn convert() do
    let? eth = FinanceAsset.native("ethereum:mainnet", 18)
    let? usd = FinanceAsset.fiat("USD", 2)
    let? amount = FinanceAmount.parse(eth, "0.001")
    let? rate = FinanceRate.make(eth, usd, BigInt.from_int(2000), BigInt.one())
    FinanceRate.convert_report(rate, amount, FinanceRounding.HalfEven)
  end
end
```

This yields USD 2.00 and a zero residual. Rates quote target whole units per
source whole unit, regardless of their respective precision. Conversion rounds
once at the destination atom boundary. `convert_report` returns the policy and
an exact signed rational residual: exact value minus rounded value, measured
in destination atoms. Its fraction is not necessarily reduced.

Parsing accepts an optional minus sign, digits, and an optional decimal point
followed by digits. It rejects whitespace, exponents, plus signs, incomplete
decimals, and excess precision. Formatting pads to native precision and
normalizes negative zero. `rescale` explicitly changes accounting precision for
the same identity; quantities with conflicting precision cannot be added.
`Exact` rejects any lost fractional atom. `HalfEven` rounds signed ties to an
even atom; `HalfAway` rounds ties away from zero.

Fiat codes must have three uppercase ASCII letters; the core does not maintain
a currency registry. Native/token factories length-prefix identity components,
so delimiters cannot cause chain/contract collisions. Callers must canonicalize
chain and contract/mint identifiers; address validation belongs to chain
adapters. Tickers are not asset identifiers.

## Dates, metadata, and interchange

Civil dates use strict YYYY-MM-DD, Gregorian years 0001..9999. Day arithmetic
has refined bounds and runtime range checks. Market holiday calendars, day-count
conventions, and IANA timezones belong to later domain libraries.

Metadata is caller-supplied: nonempty source, effective and recorded Unix
seconds in UTC, and an optional nonempty external ID. Effective time cannot be
after recorded time. Use these metadata objects for observed facts and quotes;
future scheduling is a separate concern.

Quantity JSON v1 has exactly four string-valued fields: `version`, `asset`,
`precision`, and `amount`. Strings preserve values beyond JavaScript's numeric
precision. Decoding rejects duplicate/unknown fields, unknown versions,
non-string values, and invalid amounts. This is quantity interchange; journal
CSV and broader event serialization belong to `finance-codec`.

## Verification

```sh
forge build
forge test --seed=42
forge test --release --seed=123
sh scripts/check-contracts.sh
forge publish --dry-run
```

The test suite includes generated properties with shrinking for signed decimal
and JSON round trips, arithmetic laws, large-divisor reconstruction, rounding
symmetry/bracketing, rescaling, and exact rate inversion. Regression cases cover
large crypto values, signed ties, cross-chain identity, malformed JSON, leap
days, and provenance.

Contract checks require Z3 and a current March compiler. They use the active
Forge toolchain by default; set `MARCH_COMPILER` to override the compiler.
March's refinement checker is not a complete proof system: unverified
obligations are not proof of correctness. Runtime validation and executable
tests remain essential.

This package is the financial core. Ledgers/postings, exchange/chain clients,
valuation/P&L, persistence, and tax/reporting are separate libraries.
