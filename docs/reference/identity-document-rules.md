# Identity document generation references

Accessed 2026-10-20. Chimera uses these rules only for local synthetic test-data
generation and validation. A structurally valid value is not evidence that a
government authority issued it, and generated output must never be used as a
real identity.

## United States

- SSN is nine digits. SSA excludes area `000`, `666`, and `900`-`999`, group
  `00`, and serial `0000`: https://www.ssa.gov/employer/randomizationfaqs.html
- Chimera's SSN production catalogue uses `219-09-9999`, published by SSA as a
  specimen number in a Social Security Board pamphlet:
  https://www.ssa.gov/history/oasis/may1962.pdf
- ITIN begins with `9`; digits four and five are `50`-`65`, `70`-`88`,
  `90`-`92`, or `94`-`99`:
  https://www.irs.gov/irm/part3/irm_03-012-002r
- Valid EIN prefixes are the current IRS campus, online, and SBA prefixes:
  https://www.irs.gov/businesses/small-businesses-self-employed/valid-eins

## Brazil

- Receita Federal's CPF modulus-11 example `280.012.389-38` and calculation:
  https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/manuais/sped/manuais-e-financeira/versoes-anteriores/versao-119-20240412-e-financeira-manual-de-preenchimentol.pdf
- CNPJ has twelve base characters and two numeric check digits. Alphanumeric
  values map each base character to ASCII minus 48 and use the published
  modulus-11 weights:
  https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/documentos-tecnicos/cnpj/manual-dv-cnpj.pdf
- Receita Federal's local-only simulator identifies its output as fictitious;
  Chimera bundles simulator examples and never calls it at runtime:
  https://servicos.receitafederal.gov.br/servico/cnpj-alfa/simula
- New CNPJ registrations became alphanumeric in July 2026 while existing
  numeric registrations remain valid:
  https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/acoes-e-programas/programas-e-atividades/cnpj-alfanumerico/cnpj-alfa
- Current CONTRAN rules define the CNH national registration as nine characters
  plus two check digits. Chimera applies the established BINCO modulus-11
  validation routine; the current production/manual details are access
  controlled by the issuing authority:
  https://anttlegis.antt.gov.br/action/ActionDatalegis.php?acao=abrirTextoAto&cod_menu=7145&cod_modulo=420&numeroAto=00001020&orgao=CONTRAN%2FMT&tipo=RES&valorAno=2025
- The CIN uses CPF as the single national registration number. Legacy RG values
  remain state-specific and are therefore rejected unless a future use case
  selects and sources one jurisdiction:
  https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2023/lei/l14534.htm
  and https://www.gov.br/gestao/pt-br/identidade-nacional

