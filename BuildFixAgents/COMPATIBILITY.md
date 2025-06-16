# Build Fix Agent System - Compatibility Guide

## Where Can You Use This System?

This system is **completely standalone** and works in any environment where you have:
- Bash shell (Linux, macOS, WSL on Windows)
- .NET SDK installed
- Git (optional, for version control features)

### Compatible Environments:

1. **Local Development**
   - Visual Studio
   - VS Code
   - JetBrains Rider
   - Command line only
   - Any IDE/editor

2. **CI/CD Pipelines**
   - GitHub Actions
   - Azure DevOps
   - Jenkins
   - GitLab CI
   - CircleCI
   - Any CI/CD system that supports bash

3. **Cloud Environments**
   - AWS CodeBuild
   - Azure Cloud Shell
   - Google Cloud Shell
   - GitHub Codespaces
   - Gitpod

4. **AI-Assisted Development**
   - Claude Code
   - GitHub Copilot Workspace
   - Cursor
   - Any AI coding assistant

5. **Remote Servers**
   - SSH into any Linux server
   - Docker containers
   - Kubernetes pods
   - Virtual machines

## Installation Examples

### GitHub Actions
```yaml
name: Fix Build Errors
on: [push, pull_request]

jobs:
  fix-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-dotnet@v3
      - name: Run Build Fix
        run: |
          chmod +x BuildFixAgents/*.sh
          ./BuildFixAgents/autofix.sh
```

### Docker
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0
COPY BuildFixAgents /app/BuildFixAgents
WORKDIR /app
RUN chmod +x BuildFixAgents/*.sh
CMD ["./BuildFixAgents/enterprise_launcher.sh", "start"]
```

### Jenkins Pipeline
```groovy
pipeline {
    agent any
    stages {
        stage('Fix Build') {
            steps {
                sh 'chmod +x BuildFixAgents/*.sh'
                sh './BuildFixAgents/autofix.sh'
            }
        }
    }
}
```

## Key Points

- **No Dependencies on Claude Code**: The system uses standard bash scripts
- **Portable**: Copy the BuildFixAgents folder anywhere
- **Self-Contained**: All logic is in the scripts
- **Language Agnostic**: While designed for C#, can be adapted for other languages
- **Platform Independent**: Works on any Unix-like system