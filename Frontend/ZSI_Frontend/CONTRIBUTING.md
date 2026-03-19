# Contributing to ZSI Wildlife Identifier

Thank you for your interest in contributing to the ZSI Wildlife Identifier project! This document provides guidelines and instructions for contributing.

## Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors. Please:
- Be respectful and considerate of others
- Welcome people of all backgrounds and experience levels
- Focus on what is best for the community
- Show empathy towards other community members

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check the issue list to avoid duplicates. When creating a bug report, include:
- **Title**: Clear and descriptive
- **Description**: Detailed description of the issue
- **Steps to Reproduce**: Specific steps to reproduce the problem
- **Expected Behavior**: What you expected to happen
- **Actual Behavior**: What actually happened
- **Screenshots**: If applicable
- **Environment**: OS, Flutter version, device details
- **Logs**: Any relevant error messages or logs

### Suggesting Enhancements

Enhancement suggestions should include:
- **Title**: Clear and descriptive
- **Description**: Detailed description of the enhancement
- **Use Case**: How would this feature be used?
- **Example Implementation**: If possible, provide examples
- **Alternative Solutions**: Have you considered alternatives?

### Pull Requests

1. **Fork the repository** and create your branch from `master`
2. **Create a descriptive branch name**:
   - `feature/species-comparison` for features
   - `fix/database-sync-issue` for bug fixes
   - `docs/update-readme` for documentation
   - `test/add-model-tests` for tests

3. **Make your changes**:
   - Follow the code style guidelines
   - Write or update tests for your changes
   - Update documentation as needed
   - Keep commits clean and meaningful

4. **Run tests and checks**:
   ```bash
   flutter analyze
   flutter test
   dart format lib test
   ```

5. **Commit with clear messages**:
   ```bash
   git commit -m "feat: add species comparison feature
   
   - Add comparison widget showing two species side-by-side
   - Include habitat, conservation status comparison
   - Add difference highlighting
   
   Closes #123"
   ```

6. **Push to your fork** and submit a pull request

## Development Setup

### Prerequisites
- Flutter 3.8.1+
- Dart 3.8.1+
- Git
- Your favorite code editor (VS Code, Android Studio, etc.)

### Initial Setup
```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/ZSI_Frontend.git
cd ZSI_Frontend

# Add upstream remote
git remote add upstream https://github.com/ZSI-India/ZSI_Frontend.git

# Install dependencies
flutter pub get

# Create a new branch
git checkout -b feature/your-feature-name
```

### Keep Your Fork Updated
```bash
git fetch upstream
git rebase upstream/master
git push origin master
```

## Code Style Guidelines

### Dart/Flutter Code
- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use 2-space indentation
- Format code: `dart format lib test`
- Use meaningful variable and function names
- Add comments for complex logic (not obvious code)
- Keep lines under 80 characters

### Naming Conventions
- **Classes**: PascalCase (e.g., `UploadRecord`, `DatabaseService`)
- **Methods/Variables**: camelCase (e.g., `getAllSightings`, `userEmail`)
- **Constants**: camelCase (e.g., `apiBaseUrl`, `maxRetries`)
- **Private members**: prefix with underscore (e.g., `_uploadHistory`)

### Example
```dart
// Good
class SpeciesIdentifier {
  static const String apiUrl = 'https://api.example.com';
  
  final String name;
  final double confidence;
  
  SpeciesIdentifier({required this.name, required this.confidence});
  
  bool get isHighConfidence => confidence > 0.8;
  
  void identifySpecies() {
    // Implementation
  }
}

// Avoid
class SI {
  String n;
  double c;
  
  SI(this.n, this.c);
}
```

## Testing Guidelines

### Test Requirements
- **Unit Tests**: For models and services (>80% coverage)
- **Widget Tests**: For UI components
- **Integration Tests**: For critical workflows

### Test Example
```dart
group('UploadRecord Tests', () {
  test('copyWith updates status correctly', () {
    final original = UploadRecord(
      id: 'test-1',
      imagePath: '/path/to/image.jpg',
      timestamp: DateTime.now(),
    );
    
    final updated = original.copyWith(status: 'verified');
    
    expect(updated.status, equals('verified'));
    expect(updated.id, equals(original.id));
  });
});
```

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models_test.dart

# Generate coverage
flutter test --coverage
```

## Documentation Guidelines

### Code Documentation
- Document public classes, methods, and variables
- Use /// for public documentation, // for inline comments
- Include examples for complex functionality
- Update README.md for significant features

### Example
```dart
/// Saves a sighting record to the local SQLite database.
///
/// This method stores the record with all scientific metadata
/// for offline access and later synchronization.
///
/// Example:
/// ```dart
/// await DatabaseService.saveSighting(uploadRecord);
/// ```
Future<void> saveSighting(UploadRecord record) async {
  // Implementation
}
```

## Commit Message Guidelines

Follow conventional commit format:
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc.)
- `refactor`: Code refactoring without feature changes
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependencies

### Examples
```
feat(database): implement SQLite persistence for sightings

fix(auth): correct OTP validation logic

test(models): add comprehensive unit tests for UploadRecord

docs(readme): update installation instructions
```

## Review Process

1. **Automated Checks**: GitHub Actions will run:
   - `flutter analyze`
   - `flutter test`
   - Code coverage checks

2. **Code Review**: At least one maintainer will review:
   - Code quality and style
   - Test coverage
   - Documentation completeness
   - Backward compatibility

3. **Approval**: Once approved, your PR will be merged

## Reporting Security Issues

Do NOT create public issues for security vulnerabilities. Instead:
1. Email security-report@zsi.gov.in with details
2. Include steps to reproduce (if possible)
3. Allow 90 days for a fix before public disclosure

## Questions?

- Check existing issues and discussions
- Join our development Slack channel
- Contact the ZSI team: dev-team@zsi.gov.in

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- GitHub contributors page
- Release notes

Thank you for making ZSI Wildlife Identifier better! 🦁
