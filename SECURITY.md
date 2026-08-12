# Safety and security reporting

This repository contains **firmware configuration files and optional patches**
for operating the M3-CRETE open hardware platform on Marlin or Klipper. It does
not redistribute firmware source; users obtain that from the upstream projects.

The dominant risk here is a configuration that silently disables a protection
the machine depends on. A meter-scale gantry with a heated or pressurised
printhead can injure people and destroy hardware if thermal runaway protection,
endstops, soft limits, or an E-stop path are wrong or absent.

**Treat a configuration that removes a safety guard as urgent and report it
privately.**

## Reporting

Preferred: GitHub's private reporting — **Security → Report a vulnerability** on
<https://github.com/sunnyday-technologies/M3-CRETE-FIRMWARE>.

If you cannot use GitHub, or the issue is time-sensitive, email
**security@sunn3d.com**. Please do not open a public issue for a safety-relevant
configuration defect until a correction is published.

## In scope

- A published configuration that disables, weakens, or misconfigures thermal
  runaway protection, maximum temperature limits, endstops, soft axis limits,
  homing behaviour, or emergency stop.
- Motion or acceleration values that drive an axis beyond the mechanical
  envelope of the documented build.
- A patch that does something other than what its description states.
- An upstream reference — repository, release, or checksum — that points
  somewhere other than the genuine Marlin or Klipper project. Treat this as a
  supply-chain report; it is the highest-severity class in this repository.
- Credentials, API keys, network names, or personal data committed in a config.

## Out of scope

- Vulnerabilities in Marlin or Klipper themselves. Report those upstream to the
  respective project; tell us as well if a configuration here makes the impact
  worse or the mitigation ineffective.
- Tuning preferences, print-quality settings, or values that are suboptimal but
  safe.
- Running modified firmware on non-M3-CRETE hardware.

## Response

We aim to acknowledge within five working days, and faster for anything that
removes a safety guard. Corrections state plainly what was unsafe and which
revisions are affected, so operators can check a machine already in service.
