# Roadmap

## Alpha release preparation

- [x] Publish TSRP SkillWorks source under NightCeller/tsrp-skillworks.
- [ ] Compile and smoke-test this exact packaged candidate.
- [ ] Establish a reproducible compiler build in CI with pinned dependencies.
- [ ] Validate unmodified Apollo Core; isolate/document required compatibility fixes.
- [ ] Review source and dependency licence provenance before publishing binaries.

## Reliability

- [ ] Complete multiplayer and cancellation/slot-reuse test matrix.
- [ ] Validate Fighting damage classification and normal kill/armor behavior.
- [ ] Design durable economic transactions with Apollo persistence.
- [ ] Add a shared skill API and suite-wide activity coordination where appropriate.
- [ ] Add upgrade/migration tests before changing stored schemas.

## Gameplay and maintenance

- [ ] Replace remaining Stage/Apollo UI wording with independent project branding.
- [x] Make recipe switches, thresholds, prices and timings configurable in the v2 candidate.
- [ ] Complete the v2 upgrade and live configuration test matrix.
- [ ] Balance public-server ATM rewards, police requirements and cooldowns.
- [ ] Improve item availability diagnostics and optional recipes.
- [ ] Revisit teacher/education features after the current gameplay base is stable.

No release dates promised. Education enhancements and existing engine CRC work are deferred.
