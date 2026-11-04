# Publishing v2 development

The project repository is [NightCeller/tsrp-skillworks](https://github.com/NightCeller/tsrp-skillworks).
This candidate has not been pushed or tagged by the package/build tools.
Keep the tested baseline available while v2 is being tested.

For the GitHub web workflow:

1. Create a branch named `develop/v2-configurable-gameplay` from `main`.
2. Upload the extracted source package's **contents** to that branch, preserving
   `addons`, `docs`, `examples`, `tests`, `tools` and `.github` paths. Include the
   new `scripting/include/SkillWorks_Config.inc`. Do not upload the full server archive.
3. Review the changed files. Exclude compiled plugins, logs, databases, accounts
   and credentials. Run the checks below before opening a pull request to `main`.
4. Keep the pull request in draft while the v2 game tests are pending. Record each
   actual test result in docs/TESTING.md; do not carry v1 results forward as v2 passes.

```sh
python3 tools/check_package.py
python3 -m unittest discover -s tests -v
```

The included `.github/workflows/checks.yml` runs these source checks on pushes and
pull requests. It does not build or publish binaries. If hidden folders were omitted
by the web upload, add the workflow file at that exact path.

After live upgrade tests pass and you choose to publish a candidate, tag
`v2.0.0-alpha.1` and mark it as a **pre-release**. Attach the matching source package.
Do not replace a previously published tag with different source. Keep known limits,
including untested combat, visible in the release notes. Binaries require matching
source, dependency notices and recorded build details.

Use GitHub's sign-in flow; never put tokens in URLs or commit files.
