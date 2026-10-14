# finance-core guide

Exact quantities, asset identity, explicit rounding and rates for March 0.5.0.
This package has no production dependencies beyond the March standard library.

## Install in an application

Add to your existing `forge.toml` (merge with its existing `[deps]` section):

```toml
[deps]
finance-core = "0.1.0"
```

Run `forge deps`. Pin the application's toolchain to `v0.5.0` in
`.march-version`; install it with `forge toolchain install v0.5.0`.
Modules are referenced by their names, such as `FinanceAmount`, rather than
a hyphenated package name. Commit the generated `forge.lock` in applications.

## Quickstart: exact currency conversion

The following complete test converts USD 12.50 to EUR 11.25 at an illustrative,
caller-supplied rate of 9/10 EUR per USD. It makes no market-data request.
Save it under `test/core_quickstart_test.march`, then run `forge test --seed=42`.

```march
mod CoreQuickstart do
  needs IO.Clock, IO.Process

  fn example() : Result(String, FinanceError.Error) do
    let? usd = FinanceAsset.fiat("USD", 2)
    let? eur = FinanceAsset.fiat("EUR", 2)
    let? amount = FinanceAmount.parse(usd, "12.50")
    let? rate = FinanceRate.make(usd, eur, BigInt.from_int(9), BigInt.from_int(10))
    let? report = FinanceRate.convert_report(rate, amount, FinanceRounding.Exact)
    Ok(FinanceAmount.format(report.quantity))
  end

  test "documented exact conversion" do
    assert (match example() do
      Ok(value) -> value == "11.25"
      Err(_) -> false
    end)
  end
end
```

`let?` propagates an `Err` from the enclosing Result-returning function.
No rounding happens while parsing or adding. A rate converts once, at the
destination's atom boundary.

## Choose the right representation

An asset is an opaque identity plus a precision from 0 through 255. Precision is
supplied by you, not looked up: even `fiat("USD", 2)` validates the code's shape,
not a currency database. An atom is one unit of `10^-precision`.
`from_atoms(asset, BigInt.from_int(1250))` is 12.50 for precision 2, not 1250.00.

Use `asset(id, precision)` for your canonical accounting identity, `fiat` for
three-uppercase-letter codes, and `native`/`token` for chain-qualified identities.
Tickers do not establish identity. Normalize chain and contract/mint identifiers
before construction; the library does not validate addresses or infer decimals.
Core and crypto use different identity encodings; do not assume independently
constructed assets are interchangeable. Use crypto's `core_asset` when appropriate.

Quantities are signed arbitrary-size integers with an asset attached.
`add` and `sub` require matching identity AND precision; `negate` is infallible.
The API does not currently provide a separate `Money` or decimal-valued wrapper.

## Decimal input and rounding

`parse(asset, text)` accepts an optional minus, digits and an optional decimal
fraction. Whitespace, plus signs, exponent notation, incomplete decimals and
fractional digits beyond native precision are rejected, even trailing zeros.
`format` pads to native precision and normalizes negative zero.
Do not convert financial input through Float.

`rescale(quantity, places, policy)` changes accounting precision for the same
identity, not the exchange rate or currency. Reducing precision can lose atoms.
It returns a new value; it does not mutate an asset registry.

| Policy | Fractional destination atom |
| --- | --- |
| Exact | Reject with Inexact |
| TowardZero | Discard the fraction |
| AwayFromZero | Increase magnitude |
| Floor | Round toward negative infinity |
| Ceiling | Round toward positive infinity |
| HalfAway | Nearest; ties away from zero |
| HalfEven | Nearest; ties to an even atom |

For example, rescaling -1.25 from precision 2 to 1 gives -1.2 with HalfEven
and -1.3 with HalfAway. Rounding policy is a business decision, not a global setting.

## Rates, residuals and provenance

`FinanceRate.make(source, target, numerator, denominator)` requires both rational
components to be positive and means target WHOLE units per source WHOLE unit.
`invert` reverses the direction. `convert` returns the quantity;
`convert_report` also returns `policy`, `residual_numerator` and
`residual_denominator`. Residual means exact minus rounded, measured in target
atoms; the fraction need not be reduced. It is not a separate money amount.

`FinanceMetadata.make(source, effective, recorded, external_id)` accepts UTC Unix
seconds supplied by the caller, with effective <= recorded. Source and a present
external ID must be nonblank; accepted spelling is preserved, not trimmed.
Preserve these values across retries.
`FinanceQuote.make(rate, metadata)` attaches provenance; `FinanceQuote.convert`
returns a conversion report. Quotes have no automatic expiry or freshness check.

`FinanceDate.parse`, `format` and `add_days` operate on Gregorian civil dates
in years 0001..9999. There are no timezones, holiday calendars or settlement rules.
The permitted day delta is -3652058..3652058; a resulting out-of-range date fails.

## Error handling

All fallible core operations use `Result(_, FinanceError.Error)`.
Pattern-match the result at your application boundary; do not turn malformed
customer input into a panic.

| Error | Typical cause |
| --- | --- |
| InvalidAssetId / InvalidPrecision | Invalid identity or precision outside 0..255 |
| InvalidDecimal / PrecisionExceeded | Bad decimal grammar or too many fractional digits |
| AssetMismatch | Arithmetic or conversion uses another identity/precision |
| Inexact | Exact policy would discard a fractional atom |
| DivisionByZero | Zero divisor in integer/rounding operations |
| InvalidRate | Nonpositive numerator or denominator |
| InvalidMetadata | Invalid source, optional ID, time ordering or civil date/range |
| InvalidEncoding | Malformed quantity JSON |

`FinanceInteger.divmod` and `FinanceRounding.divide` expose exact integer helpers.
`FinanceCodec.encode/decode` handles quantity JSON v1 only: version, asset,
precision and amount are strings. Journal interchange is not part of this package.

## Guarantees and limits

Opaque constructors and runtime checks enforce validity; refinements describe
bounds but March's checker does not prove every caller obligation. Keep runtime
validation and tests. There is no network, storage, clock, ledger, pricing feed,
valuation, tax policy or authenticity guarantee.

See the [module map and verification commands](../README.md).
The [tested quickstart](../test/docs_quickstart_test.march) is run by ordinary CI.
