# Contributing

Keep changes small and describe the player-visible problem, resulting behavior
and validation. Open an issue or pull request once the public repository is created.

- Preserve SQLite tables, Steam ID identity checks and existing commands unless an
  explicit migration is included. Do not interpolate unvalidated input into SQL.
- Register chat through Apollo's dispatcher; aliases need distinct handler names
  within the same chat mode. Generic `say /command` hooks can conflict with TalkArea.
- Use Apollo APIs for money/items/jobs. Do not bypass core persistence with direct
  edits to its account tables. Never award an item/reward twice from a timer.
- Clear active operations before completion, and check identity, connection slot,
  requirements and resources again at completion.
- Compile affected plugins, run repository checks, and describe manual server tests.
  If you cannot test a path, state that explicitly.
- Update documentation and module version for functional changes. Project release
  versions and individual plugin versions are separate.
- Contributions use the project licence/exception in LICENSE and NOTICE. Preserve
  third-party attribution and do not add dependencies with unreviewed terms.

Never attach complete databases, users.ini, credentials, full server archives or
unredacted player logs to public issues. Supply the smallest redacted error excerpt.
