# Contributing to Receipt Tracker

First off, thanks for taking the time to contribute! 🎉

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues as you might find that you don't need to create one. When you are creating a bug report, please include as many details as possible using our bug report template.

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. Create an issue using the feature request template and provide the following information:

- Clear and descriptive title
- Detailed description of the suggested enhancement
- Explain why this enhancement would be useful
- List any alternatives you've considered

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code lints (SwiftLint)
6. Issue that pull request!

## Development Setup

### Prerequisites

- Xcode 15.0+
- iOS 16.0+ SDK
- CocoaPods or Swift Package Manager (if dependencies added)
- SwiftLint (optional but recommended)

### Installation

```bash
git clone https://github.com/babushkai/receipt-tracker-ios.git
cd receipt-tracker-ios
open ReceiptTracker.xcodeproj
```

### Building

1. Select target device/simulator
2. Press ⌘ + B to build
3. Press ⌘ + R to run

## Style Guide

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).

Key points:
- Use meaningful names
- Prefer clarity over brevity
- Follow naming conventions
- Use SwiftLint for consistency

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line
- Use conventional commits format:
  - `feat:` new feature
  - `fix:` bug fix
  - `docs:` documentation changes
  - `style:` formatting, missing semicolons, etc.
  - `refactor:` refactoring production code
  - `test:` adding tests
  - `chore:` updating build tasks, package manager configs, etc.

### Example Commit Message

```
feat: add OCR processing for receipts

- Implement Vision framework integration
- Add text extraction and parsing
- Update UI to show processing state

Closes #123
```

## Testing

### Running Tests

```bash
⌘ + U  # Run all tests in Xcode
```

### Writing Tests

- Write unit tests for all business logic
- Write UI tests for critical user flows
- Aim for 80%+ code coverage
- Use meaningful test names that describe what is being tested

## Documentation

- Update README.md with any new features
- Document all public APIs using DocC comments
- Keep code comments up to date
- Update CHANGELOG.md (if we add one)

## Architecture

This project follows MVVM architecture:

- **Models**: Data structures and Core Data entities
- **Views**: SwiftUI views
- **ViewModels**: Business logic and state management
- **Services**: Reusable services (OCR, Analytics, Persistence)

### Adding New Features

1. Create models in `/Models`
2. Create services in `/Services`
3. Create ViewModels in `/ViewModels`
4. Create Views in `/Views`
5. Add tests for all layers
6. Update documentation

## Code Review Process

1. All PRs require at least 1 approval
2. CI checks must pass
3. Code must follow style guidelines
4. Tests must pass
5. Documentation must be updated

## Release Process

(To be defined as project matures)

1. Update version number
2. Update CHANGELOG.md
3. Create release branch
4. Test thoroughly
5. Merge to main
6. Tag release
7. Deploy to TestFlight/App Store

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the project's license.

---

Thank you for contributing! 🙏

