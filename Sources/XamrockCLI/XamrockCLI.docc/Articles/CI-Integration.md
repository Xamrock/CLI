# CI/CD Integration

Automate your app exploration with continuous integration.

## Overview

Xamrock CLI integrates seamlessly with CI/CD pipelines, enabling automated UI testing on every commit or pull request. This guide covers best practices and examples for popular CI platforms.

## CI Mode

For deterministic and CI-friendly behavior, use the `--ci-mode` flag:

```bash
xamrock explore \
  --app com.example.App \
  --ci-mode \
  --fail-on-issues \
  --no-generate-dashboard
```

### CI Mode Features

- **Deterministic behavior**: Fixed random seed and low temperature for consistent results
- **Minimal output**: Optimized for CI logs
- **JSON manifest**: Machine-readable results for parsing
- **Exit codes**: Non-zero exit on failures (with `--fail-on-issues`)

## GitHub Actions

### Basic Workflow

Create `.github/workflows/xamrock-test.yml`:

```yaml
name: AI-Powered UI Testing

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  explore:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Install Xamrock CLI
        run: |
          brew tap xamrock/tap
          brew install xamrock

      - name: Generate exploration test
        run: |
          xamrock explore \
            --app com.example.YourApp \
            --ci-mode \
            --output ./test-results

      - name: Add test to project
        run: cp test-results/ScoutCLIExploration.swift YourAppUITests/

      - name: Run exploration
        run: |
          xcodebuild test \
            -project YourApp.xcodeproj \
            -scheme YourApp \
            -destination 'platform=iOS Simulator,name=iPhone 15'

      - name: Upload results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: exploration-results
          path: test-results/
```

### Advanced Workflow with Matrix Testing

Test multiple configurations:

```yaml
jobs:
  explore:
    runs-on: macos-latest
    strategy:
      matrix:
        device: ['iPhone 15', 'iPhone 15 Pro Max', 'iPad Pro']
        steps: [20, 30]

    steps:
      - uses: actions/checkout@v4

      - name: Install Xamrock CLI
        run: |
          brew tap xamrock/tap
          brew install xamrock

      - name: Run exploration
        run: |
          xamrock explore \
            --app com.example.YourApp \
            --steps ${{ matrix.steps }} \
            --device "${{ matrix.device }}" \
            --ci-mode \
            --output ./test-results-${{ matrix.device }}-${{ matrix.steps }}

      - name: Upload results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: results-${{ matrix.device }}-${{ matrix.steps }}
          path: test-results-${{ matrix.device }}-${{ matrix.steps }}/
```

## GitLab CI/CD

Create `.gitlab-ci.yml`:

```yaml
stages:
  - test

xamrock-exploration:
  stage: test
  tags:
    - macos

  before_script:
    - brew tap xamrock/tap
    - brew install xamrock

  script:
    - |
      xamrock explore \
        --app com.example.YourApp \
        --ci-mode \
        --fail-on-issues \
        --output ./test-results

    - cp test-results/ScoutCLIExploration.swift YourAppUITests/

    - |
      xcodebuild test \
        -project YourApp.xcodeproj \
        -scheme YourApp \
        -destination 'platform=iOS Simulator,name=iPhone 15'

  artifacts:
    when: always
    paths:
      - test-results/
    expire_in: 30 days
```

## Jenkins

Jenkinsfile example:

```groovy
pipeline {
    agent { label 'macos' }

    stages {
        stage('Install Xamrock') {
            steps {
                sh '''
                    brew tap xamrock/tap
                    brew install xamrock
                '''
            }
        }

        stage('Generate Test') {
            steps {
                sh '''
                    xamrock explore \
                        --app com.example.YourApp \
                        --ci-mode \
                        --output ./test-results
                '''
            }
        }

        stage('Run Exploration') {
            steps {
                sh '''
                    cp test-results/ScoutCLIExploration.swift YourAppUITests/
                    xcodebuild test \
                        -project YourApp.xcodeproj \
                        -scheme YourApp \
                        -destination 'platform=iOS Simulator,name=iPhone 15'
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'test-results/**/*', allowEmptyArchive: true
        }
    }
}
```

## CircleCI

Create `.circleci/config.yml`:

```yaml
version: 2.1

jobs:
  explore:
    macos:
      xcode: "15.0.0"

    steps:
      - checkout

      - run:
          name: Install Xamrock CLI
          command: |
            brew tap xamrock/tap
            brew install xamrock

      - run:
          name: Generate and run exploration
          command: |
            xamrock explore \
              --app com.example.YourApp \
              --ci-mode \
              --output ./test-results

            cp test-results/ScoutCLIExploration.swift YourAppUITests/

            xcodebuild test \
              -project YourApp.xcodeproj \
              -scheme YourApp \
              -destination 'platform=iOS Simulator,name=iPhone 15'

      - store_artifacts:
          path: test-results
          destination: exploration-results

workflows:
  version: 2
  test:
    jobs:
      - explore
```

## Best Practices

### 1. Cache Dependencies

Speed up CI runs by caching Homebrew installations:

```yaml
# GitHub Actions
- uses: actions/cache@v4
  with:
    path: ~/Library/Caches/Homebrew
    key: ${{ runner.os }}-brew-${{ hashFiles('**/Brewfile') }}
```

### 2. Fail Fast

Use `--fail-on-issues` to catch problems early:

```bash
xamrock explore \
  --app com.example.YourApp \
  --ci-mode \
  --fail-on-issues
```

### 3. Save Artifacts

Always upload test results for debugging:

```yaml
- uses: actions/upload-artifact@v4
  if: always()  # Upload even on failure
  with:
    name: exploration-results
    path: test-results/
```

### 4. Version Pinning

Pin Xamrock CLI version for reproducibility:

```bash
brew install xamrock@0.3.0
```

### 5. Parallel Execution

Run multiple explorations in parallel for faster feedback:

```yaml
strategy:
  matrix:
    goal:
      - "Test authentication flows"
      - "Test checkout process"
      - "Test navigation"
```

## Parsing Results

The `manifest.json` file contains machine-readable results:

```json
{
  "version": "0.3.0",
  "timestamp": "2025-10-27T23:34:49Z",
  "bundleId": "com.example.YourApp",
  "steps": 20,
  "status": "success",
  "issuesFound": 0,
  "criticalIssues": 0,
  "outputDirectory": "./test-results"
}
```

Parse it in your CI scripts:

```bash
# Check for critical issues
CRITICAL=$(jq '.criticalIssues' test-results/manifest.json)
if [ "$CRITICAL" -gt 0 ]; then
  echo "Found $CRITICAL critical issues!"
  exit 1
fi
```

## Scheduled Runs

Run explorations on a schedule to catch regressions:

```yaml
# GitHub Actions
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
```

## Next Steps

- Learn about <doc:Configuration-article> options
- Review <doc:Troubleshooting> guide
- Explore <doc:GeneratedTests> format
