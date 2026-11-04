# Publishing this project

Nothing in this package has created or published a GitHub repository.
Suggested owner: NightCeller. Working repository name: `tsrp-skillworks`.
Finalize the name before publishing; change README, NOTICE and this guide if needed.

1. Review LICENSE/NOTICE, credits and the testing limitations.
2. Compile and smoke-test the candidate. Keep it labelled alpha.
3. Create an empty repository on GitHub under your account. Begin private if you
   want to review it first. Do not upload the original amxmodx.zip.
4. Extract this package. From its root, run the commands below (Git must be installed).
   GitHub Desktop is also suitable for adding/publishing this local folder.

```sh
git init -b main
git add .
git diff --cached --stat
git commit -m "Prepare initial SkillWorks alpha source"
# Replace OWNER and REPOSITORY with the repository you actually created.
git remote add origin https://github.com/OWNER/REPOSITORY.git
git push -u origin main
```

Use GitHub's normal sign-in flow; do not put access tokens in URLs or commit files.
The repository description can be:

> Independent modular skills and progression for The Specialists Roleplay, built for Apollo-RP, AMX Mod X and SQLite.

After checking the initial commit, enable Issues and optionally Discussions/private
vulnerability reporting. Mark the first tagged release **pre-release**, with tag
`v0.1.0-alpha.1`. Release notes should link the known limitations and say Fighting
damage is untested/disabled in the example config. No compiled plugins are supplied
here; publish binaries only with matching source, reproducible build details and
applicable dependency notices. Do not call this an official Apollo release.

This source package intentionally leaves an unrelated full-server backup out of Git.
