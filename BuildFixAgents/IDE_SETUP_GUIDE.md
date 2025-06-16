# IDE Integration Setup Guide

The Build Fix Agent now supports deep integration with major IDEs for a seamless development experience.

## Quick Setup

### Auto-Detection
The agent automatically detects your IDE:
```bash
./autofix.sh
# Will detect VS Code, Visual Studio, IntelliJ, etc.
```

### Manual IDE Setup
```bash
# Check which IDE is detected
./ide_integration.sh detect

# Set up specific IDE
./ide_integration.sh setup vscode
./ide_integration.sh setup visualstudio
./ide_integration.sh setup intellij
```

## Visual Studio Code

### Features
- ✅ Auto-fix on save
- ✅ Error analysis panel
- ✅ Quick fix code actions
- ✅ Progress notifications
- ✅ Integrated terminal commands

### Installation
1. Generate the extension:
   ```bash
   ./ide_integration.sh setup vscode
   ```

2. Install the extension:
   ```bash
   cd BuildFixAgents/vscode-extension
   npm install
   npm install -g vsce
   vsce package
   code --install-extension build-fix-agent-*.vsix
   ```

3. Configure in VS Code settings:
   ```json
   {
     "buildFixAgent.aiProvider": "claude",
     "buildFixAgent.apiKey": "your-api-key",
     "buildFixAgent.autoFixOnSave": true
   }
   ```

### Usage
- **Command Palette**: `Ctrl+Shift+P` → "Build Fix: Run Auto Fix"
- **Quick Fix**: Hover over error → click lightbulb → "Fix: [error]"
- **Status Bar**: Click "Build Fix" to run analysis

## Visual Studio

### Features
- ✅ Build event integration
- ✅ Error List integration
- ✅ Solution-wide fixes
- ✅ Tool window for analysis
- ✅ Options page for configuration

### Installation
1. Generate the extension:
   ```bash
   ./ide_integration.sh setup visualstudio
   ```

2. Build in Visual Studio:
   - Open `BuildFixAgents/visual-studio/BuildFixAgent.sln`
   - Build → Build Solution
   - The VSIX will be in `bin/Release/`

3. Install the VSIX:
   - Double-click the `.vsix` file
   - Or: Extensions → Manage Extensions → Install from file

### Usage
- **Build Menu**: Build → Run Build Fix Agent
- **Error List**: Right-click error → "Fix with Build Fix Agent"
- **Auto-fix**: Enable in Tools → Options → Build Fix Agent

## JetBrains IDEs (IntelliJ, Rider, PyCharm, WebStorm)

### Features
- ✅ Inspection integration
- ✅ Quick fix intentions
- ✅ Build tool integration
- ✅ Project-wide analysis
- ✅ Custom tool window

### Installation
1. Generate the plugin:
   ```bash
   ./ide_integration.sh setup intellij  # or rider, pycharm, webstorm
   ```

2. Build the plugin:
   ```bash
   cd BuildFixAgents/jetbrains-plugin
   ./gradlew buildPlugin
   ```

3. Install in IDE:
   - File → Settings → Plugins
   - Click gear icon → Install Plugin from Disk
   - Select `build/distributions/build-fix-agent-*.zip`

### Usage
- **Build Menu**: Build → Run Build Fix Analysis
- **Editor**: `Alt+Enter` on error → "Fix with Build Fix Agent"
- **Shortcut**: `Ctrl+Alt+Shift+F` to run analysis

## IDE Output Formats

The agent automatically formats errors for your IDE:

### VS Code Format
```
src/Example.cs:42:10: error: The type 'List' could not be found [CS0246]
```

### Visual Studio Format
```
src/Example.cs(42,10): error CS0246: The type 'List' could not be found
```

### IntelliJ Format
```
src/Example.cs:42: error: The type 'List' could not be found
```

## Advanced Configuration

### Project-Level Settings
Create `.buildfix/config.json` in your project:
```json
{
  "ide": {
    "preferredIDE": "vscode",
    "autoDetect": true,
    "formatting": {
      "showErrorCodes": true,
      "groupByFile": true,
      "maxErrorsPerFile": 10
    }
  },
  "integration": {
    "autoFixOnBuild": true,
    "autoFixOnSave": false,
    "showNotifications": true,
    "requireConfirmation": true
  }
}
```

### Environment Variables
```bash
# Force specific IDE mode
export BUILD_FIX_IDE=vscode

# Disable IDE detection
export BUILD_FIX_NO_IDE=1

# Custom IDE output format
export BUILD_FIX_FORMAT=json
```

## Troubleshooting

### IDE Not Detected
```bash
# Check detection
./ide_integration.sh detect

# Force IDE mode
BUILD_FIX_IDE=vscode ./autofix.sh
```

### Extension Not Loading
1. Check IDE logs:
   - VS Code: Help → Toggle Developer Tools → Console
   - Visual Studio: View → Output → Build Fix Agent
   - IntelliJ: Help → Show Log in Explorer

2. Verify installation:
   ```bash
   # VS Code
   code --list-extensions | grep build-fix
   
   # Visual Studio
   # Check in Extensions → Manage Extensions
   
   # JetBrains
   # Check in File → Settings → Plugins
   ```

### Performance Issues
- Disable auto-fix on save for large projects
- Limit concurrent analysis with `maxConcurrentAgents`
- Use file filters to exclude generated code

## Best Practices

### For Teams
1. Commit IDE settings to version control:
   ```
   .vscode/settings.json
   .idea/buildfix.xml
   *.buildfix
   ```

2. Use consistent AI provider across team:
   ```json
   {
     "buildFixAgent.aiProvider": "claude",
     "buildFixAgent.apiKeySource": "environment"
   }
   ```

### For CI/CD
The agent works in headless mode for CI:
```bash
# No IDE detection in CI
CI=true ./autofix.sh

# Output in standard format
./autofix.sh | ./ide_integration.sh format json
```

## Contributing

To add support for a new IDE:

1. Add detection logic in `detect_ide()`
2. Create setup function `setup_<ide_name>()`
3. Add formatting rules in `format_for_ide()`
4. Submit PR with example usage

## Supported IDEs

| IDE | Detection | Extension | Auto-fix | Quick Fix |
|-----|-----------|-----------|----------|-----------|
| VS Code | ✅ | ✅ | ✅ | ✅ |
| Visual Studio | ✅ | ✅ | ✅ | ✅ |
| IntelliJ IDEA | ✅ | ✅ | ✅ | ✅ |
| Rider | ✅ | ✅ | ✅ | ✅ |
| PyCharm | ✅ | ✅ | ✅ | ✅ |
| WebStorm | ✅ | ✅ | ✅ | ✅ |
| Sublime Text | ✅ | 🚧 | ❌ | ❌ |
| Atom | ✅ | 🚧 | ❌ | ❌ |
| Vim/Neovim | 🚧 | 🚧 | ❌ | ❌ |
| Emacs | 🚧 | 🚧 | ❌ | ❌ |

Legend: ✅ Supported | 🚧 Planned | ❌ Not Available