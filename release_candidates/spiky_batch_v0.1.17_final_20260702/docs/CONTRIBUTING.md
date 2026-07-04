# Contributing

Use GitHub Issues for reproducible non-sensitive bugs and feature proposals. Describe the Fiji/ImageJ version, operating system, macro version/hash, settings, input shape, expected behavior, actual behavior, and relevant error text. Use synthetic or fully public data whenever possible.

Pull requests should be focused, documented, and accompanied by validation appropriate to their risk. Keep generated files and private data out of commits.

Scientific behavior changes require especially careful review. Changes to baseline anchors or fitting, thresholds, peak detection, normalization, exclusions, pass/fail criteria, or exported calculations must not be made casually. They require a stated scientific rationale, updated documentation and versioning, deterministic fixtures, static checks, Full Batch validation, aggregation checks, and comparison against the accepted reference behavior.

Documentation-only and public-hygiene changes must still pass `git diff --check`, link/path review, and package inventory/hash checks when they affect a release.

By contributing, you agree that your contribution is licensed under GPL-3.0-or-later.
