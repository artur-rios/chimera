# Synthetic person generation rules

Chimera generates synthetic test people locally. It does not query registries,
copy known identity records, claim that generated values were issued, or retain
requests and results. Every surface labels the output as synthetic test data.

## Shared constraints

- Supported person locales are United States (`us`) and Brazil (`br`).
- Minimum and maximum ages are inclusive whole numbers from 0 through 130.
- Birth dates are generated and checked against one operation date. A birthday
  must have occurred in the current calendar year before that year counts.
- Names come from bundled locale-specific fixture lists.
- Email local parts are derived from the generated names. All addresses use
  `example.com`, which IANA reserves for documentation and examples.
- Address city, region, postal code, and phone area code/DDD are selected from
  one bundled location fixture and validated together.
- US phone lines use `555-0100` through `555-0199`, the fictional non-working
  range retained by the North American Numbering Plan Administrator.
- Brazilian mobile numbers use country code `55`, a two-digit DDD, and the
  Anatel `9XXXX-XXXX` subscriber format. They are synthetic but are not asserted
  to be unassigned.
- US people contain a synthetic SSN. Brazilian people contain CPF and CIN
  entries sharing the same CPF-based registration number. All identifiers are
  independently checked by Chimera's identity-document validator.
- A person is accepted only after the complete aggregate passes validation.
  Generation retries at most 32 candidates per requested person and never
  returns a partial batch.

## Primary references

- [IANA example domains](https://www.iana.org/help/example-domains)
- [NANPA 555 fictional number statement](https://www.nationalnanpa.com/reports/2018_NANPA_Annual_Report.pdf)
- [Anatel Brazilian numbering plan](https://www.gov.br/anatel/pt-br/regulado/numeracao/plano-de-numeracao-brasileiro)
- [Anatel mobile numbering table](https://www.gov.br/anatel/pt-br/regulado/numeracao/tabela-servico-movel-celular)
- [Chimera identity-document rules](identity-document-rules.md)
