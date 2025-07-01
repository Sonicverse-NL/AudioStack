# Contributing to AudioStack

Thank you for your interest in contributing to AudioStack! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites

- Git
- Node.js 18+ (for development tools)
- Docker (for testing)

### Development Setup

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/AudioStack.git
   cd AudioStack
   ```
3. Run the development setup script:
   ```bash
   ./scripts/setup-dev.sh
   ```

This script will:
- Install development dependencies (commitlint, husky)
- Set up Git hooks for commit message validation
- Configure your local environment

## Conventional Commits

This project strictly follows [Conventional Commits](https://www.conventionalcommits.org/) specification. All commit messages must adhere to this format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(streaming): add AAC encoding support` |
| `fix` | Bug fix | `fix: resolve audio dropout during failover` |
| `docs` | Documentation changes | `docs: update API configuration guide` |
| `style` | Code style changes (formatting, etc.) | `style: fix indentation in Dockerfile` |
| `refactor` | Code refactoring | `refactor: simplify audio processing pipeline` |
| `perf` | Performance improvements | `perf: optimize buffer management` |
| `test` | Adding or fixing tests | `test: add unit tests for failover logic` |
| `build` | Build system changes | `build: update Docker base image` |
| `ci` | CI/CD changes | `ci: add automated security scanning` |
| `chore` | Maintenance tasks | `chore: update dependencies` |
| `revert` | Revert previous commit | `revert: undo breaking audio format change` |

### Commit Message Rules

- Use present tense ("add feature" not "added feature")
- Use imperative mood ("move cursor to..." not "moves cursor to...")
- Limit the first line to 72 characters
- Reference issues and pull requests when applicable
- Use lowercase for type and scope
- Don't end the subject line with a period

### Examples

```bash
# Good commits
git commit -m "feat(icecast): add custom metadata injection"
git commit -m "fix: prevent memory leak in audio buffer"
git commit -m "docs: add troubleshooting section for common issues"

# Bad commits (will be rejected)
git commit -m "fixed bug"
git commit -m "Added new feature."
git commit -m "WIP: working on stuff"
```

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feat/your-feature-name
# or
git checkout -b fix/issue-description
```

### 2. Make Changes

- Write clear, focused commits
- Test your changes locally
- Ensure Docker builds successfully:
  ```bash
  docker build -t audiostack-test .
  ```

### 3. Test Your Changes

- Build and run the container locally
- Test with actual audio streams if possible
- Verify all existing functionality still works

### 4. Submit Pull Request

1. Push your branch to your fork:
   ```bash
   git push origin feat/your-feature-name
   ```

2. Create a Pull Request on GitHub

3. Ensure all CI checks pass:
   - Commit message validation
   - Docker build succeeds
   - Any automated tests pass

### 5. Code Review Process

- Address any feedback from maintainers
- Keep your branch up to date with main:
  ```bash
  git fetch origin
  git rebase origin/main
  ```

## Code Style Guidelines

### Dockerfile
- Use multi-stage builds when appropriate
- Minimize layer count and image size
- Include health checks
- Use specific version tags for base images
- Add clear comments for complex operations

### Shell Scripts
- Use `#!/bin/bash` or `#!/bin/sh` as appropriate
- Add error handling with `set -e`
- Use clear variable names
- Comment complex logic
- Quote variables to prevent word splitting

### Documentation
- Use clear, concise language
- Include examples for configuration options
- Keep README.md up to date with changes
- Document breaking changes clearly

## Commit Message Validation

### Local Validation
Commit messages are automatically validated locally using husky and commitlint. Invalid commits will be rejected before they're created.

If you encounter validation errors:

1. Check your commit message format
2. Fix the message and try again:
   ```bash
   git commit --amend -m "feat: your corrected message"
   ```

### CI Validation
All pull requests are checked for conventional commit compliance. PRs with non-compliant commit messages will fail CI checks and receive an automated comment with guidance.

## Reporting Issues

When reporting issues, please include:

### Bug Reports
- AudioStack version/commit
- Host operating system
- Docker version
- Complete error messages/logs
- Steps to reproduce
- Expected vs actual behavior

### Feature Requests
- Clear description of the proposed feature
- Use case/justification
- Potential implementation approach (if known)

## Release Process

AudioStack uses automated releases based on conventional commits:

- `feat:` commits trigger minor version bumps
- `fix:` commits trigger patch version bumps  
- `feat!:` or `BREAKING CHANGE:` trigger major version bumps

Docker images are automatically built and published to GitHub Container Registry (ghcr.io) on releases.

## Questions?

- Open an issue for questions about contributing
- Check existing issues and discussions first
- Be respectful and constructive in all interactions

## License

By contributing to AudioStack, you agree that your contributions will be licensed under the MIT License.
