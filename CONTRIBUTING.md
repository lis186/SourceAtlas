# Contributing to SourceAtlas

Thank you for your interest in contributing to SourceAtlas! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Style Guidelines](#style-guidelines)

## Code of Conduct

Please read and follow our [Code of Conduct](./CODE_OF_CONDUCT.md).

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/SourceAtlas.git`
3. Create a branch: `git checkout -b feature/your-feature-name`

## How to Contribute

### Reporting Bugs

- Check if the issue already exists in [GitHub Issues](https://github.com/lis186/SourceAtlas/issues)
- Use the bug report template when creating a new issue
- Include reproduction steps, expected behavior, and actual behavior

### Suggesting Features

- Check existing issues and discussions first
- Use the feature request template
- Explain the use case and expected benefit

### Contributing Code

1. Look for issues labeled `good first issue` or `help wanted`
2. Comment on the issue to indicate you're working on it
3. Follow the development setup and style guidelines below

## Development Setup

### Prerequisites

- Claude Code 0.3+
- Git 2.0+
- Bash 4.0+ (5.0+ recommended)
- macOS 12+ or Linux

### Installation

```bash
# Clone the repository
git clone https://github.com/lis186/SourceAtlas.git
cd SourceAtlas

# Option 1: Test with plugin directly
claude --plugin-dir ./plugin

# Option 2: Install via local marketplace
# In Claude Code:
/plugin marketplace add ./
/plugin install sourceatlas@lis186-sourceatlas
```

### Testing Your Changes

```bash
# Test on a sample project
cd /path/to/test-project
/atlas.overview
/atlas.pattern "your pattern"
```

### Project Structure

```
SourceAtlas/
├── .claude/commands/     # Slash command definitions
├── scripts/atlas/        # Shell scripts
├── plugin/               # Claude Code plugin package
├── dev-notes/            # Development documentation
└── docs/                 # User documentation (future)
```

## Pull Request Process

1. **Update Documentation**: Update README.md or relevant docs if needed
2. **Follow Checklist**: Ensure all items in the PR template are addressed
3. **One Feature Per PR**: Keep PRs focused on a single change
4. **Write Clear Commits**: Use conventional commit messages

### Commit Message Format

```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
- `feat(pattern): add Vue 3 composition API patterns`
- `fix(detection): resolve Swift project misdetection with Gemfile`
- `docs(readme): update installation instructions`

## Style Guidelines

### Shell Scripts

- Use `#!/bin/bash` shebang
- Quote variables: `"$VAR"` not `$VAR`
- Use `[[ ]]` for conditionals (not `[ ]`)
- Add comments for complex logic

### Markdown

- Use ATX-style headers (`#`, `##`, etc.)
- One sentence per line (for better diffs)
- Use fenced code blocks with language identifiers

### Command Files (.md in .claude/commands/)

- Keep prompts clear and actionable
- Include example usage
- Document expected output format

## Questions?

- Open a [Discussion](https://github.com/lis186/SourceAtlas/discussions)
- Check existing issues and discussions

Thank you for contributing!
