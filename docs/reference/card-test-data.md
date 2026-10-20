# Synthetic Card Test Data

Chimera generates payment-card values only from the closed catalogue below. All
entries are published sandbox test numbers. The application never invents an
account-number suffix in a live issuer range, sends a number over the network,
or stores generated output.

| Network | Exact sandbox PANs |
| --- | --- |
| Visa | `4005520201264821`, `4242424242424242`, `4000056655665556` |
| Mastercard | `5500005555555559`, `5555555555554444`, `2223003122003222` |
| American Express | `340353278080900`, `378282246310005`, `371449635398431` |
| Discover | `6011003179988686`, `6011111111111117`, `6011000990139424` |

Each selected value is independently checked for the requested network's
prefix and length rules and for a valid Luhn checksum. A candidate not in this
exact catalogue is rejected even if it is otherwise structurally valid.

Sources (accessed 2026-10-20):

- [Visa Checkout Getting Started, sandbox test card table](https://community.developer.visa.com/visa/attachments/visa/implementation/658/1/VisaCheckoutGettingStartedV1901.pdf)
- [Stripe test card numbers by brand](https://docs.stripe.com/testing?testing-method=card-numbers#cards)
