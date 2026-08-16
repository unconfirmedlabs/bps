## Sui Development Skills

Install community-maintained skills for Sui development:

```sh
npx skills https://github.com/MystenLabs/skills
```

## Project Structure

- `sources/bps.move` — basis-point value type and checked arithmetic helpers.
- `tests/bps_tests.move` — Move unit and boundary tests.

## Project Rules

- Preserve `BPS` invariants: values stay within `[0, 10_000]`, checked arithmetic must not wrap, and rounding behavior must be explicit and tested.
- Keep the public API composable and use Move 2024 syntax.
- Run linted builds and tests with explicit `--build-env testnet` and `--build-env mainnet`, plus boundary/property-style tests, before publishing or upgrading.
- Verify published bytecode against source for each network recorded in `Published.toml`.

## Official Resources

When unsure about Move patterns or Sui APIs, consult these sources. Do not guess or extrapolate from other blockchains.

- Sui documentation MCP server: `https://sui.mcp.kapa.ai`
- Move Book: https://move-book.com (use https://move-book.com/llms.txt)
- Sui Docs: https://docs.sui.io (use https://docs.sui.io/llms.txt)
- Sui Move examples: https://github.com/MystenLabs/sui/tree/main/examples/move
