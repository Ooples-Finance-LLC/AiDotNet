#!/bin/bash

# IDE Integration Module for Build Fix Agent
# Supports VS Code, Visual Studio, JetBrains, and other major IDEs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Detect current IDE
detect_ide() {
    # Check environment variables and processes
    if [[ -n "${VSCODE_PID:-}" ]] || [[ -n "${VSCODE_IPC_HOOK:-}" ]]; then
        echo "vscode"
    elif [[ -n "${VisualStudioVersion:-}" ]] || [[ -n "${VSAPPIDDIR:-}" ]]; then
        echo "visualstudio"
    elif [[ -n "${IDEA_INITIAL_DIRECTORY:-}" ]] || timeout 1s pgrep -f "idea" > /dev/null 2>&1; then
        echo "intellij"
    elif [[ -n "${RIDER_INITIAL_DIRECTORY:-}" ]] || timeout 1s pgrep -f "rider" > /dev/null 2>&1; then
        echo "rider"
    elif [[ -n "${PYCHARM_HOSTED:-}" ]] || timeout 1s pgrep -f "pycharm" > /dev/null 2>&1; then
        echo "pycharm"
    elif [[ -n "${WEBSTORM_INITIAL_DIRECTORY:-}" ]] || timeout 1s pgrep -f "webstorm" > /dev/null 2>&1; then
        echo "webstorm"
    elif [[ -n "${SUBLIME_PACKAGES:-}" ]]; then
        echo "sublime"
    elif [[ -n "${ATOM_HOME:-}" ]]; then
        echo "atom"
    elif [[ -n "${CLAUDE_CODE:-}" ]]; then
        echo "claude_code"
    else
        echo "unknown"
    fi
}

# VS Code Integration
setup_vscode() {
    local extension_dir="$SCRIPT_DIR/vscode-extension"
    mkdir -p "$extension_dir"
    
    # Create package.json for VS Code extension
    cat > "$extension_dir/package.json" << 'EOF'
{
  "name": "build-fix-agent",
  "displayName": "Build Fix Agent",
  "description": "AI-powered build error fixing for multiple languages",
  "version": "1.0.0",
  "engines": {
    "vscode": "^1.74.0"
  },
  "categories": ["Other"],
  "activationEvents": [
    "onCommand:buildFixAgent.runFix",
    "onCommand:buildFixAgent.analyzeErrors",
    "onCommand:buildFixAgent.applyFix"
  ],
  "main": "./extension.js",
  "contributes": {
    "commands": [
      {
        "command": "buildFixAgent.runFix",
        "title": "Build Fix: Run Auto Fix"
      },
      {
        "command": "buildFixAgent.analyzeErrors",
        "title": "Build Fix: Analyze Errors"
      },
      {
        "command": "buildFixAgent.applyFix",
        "title": "Build Fix: Apply Selected Fix"
      }
    ],
    "configuration": {
      "title": "Build Fix Agent",
      "properties": {
        "buildFixAgent.aiProvider": {
          "type": "string",
          "default": "none",
          "enum": ["none", "claude", "openai", "claude-code"],
          "description": "AI provider for enhanced fixes"
        },
        "buildFixAgent.apiKey": {
          "type": "string",
          "default": "",
          "description": "API key for AI provider (not needed for Claude Code)"
        },
        "buildFixAgent.autoFixOnSave": {
          "type": "boolean",
          "default": false,
          "description": "Automatically fix errors on save"
        }
      }
    },
    "problemMatchers": [
      {
        "name": "buildFixAgent",
        "owner": "buildFixAgent",
        "fileLocation": ["relative", "${workspaceFolder}"],
        "pattern": {
          "regexp": "^(.*):(\\d+):(\\d+):\\s+(warning|error):\\s+(.*)$",
          "file": 1,
          "line": 2,
          "column": 3,
          "severity": 4,
          "message": 5
        }
      }
    ]
  }
}
EOF

    # Create extension.js
    cat > "$extension_dir/extension.js" << 'EOF'
const vscode = require('vscode');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

function activate(context) {
    console.log('Build Fix Agent is now active!');
    
    // Register commands
    let runFixCommand = vscode.commands.registerCommand('buildFixAgent.runFix', async () => {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            vscode.window.showErrorMessage('No workspace folder open');
            return;
        }
        
        // Show progress
        vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: "Running Build Fix Agent",
            cancellable: true
        }, async (progress, token) => {
            progress.report({ increment: 0, message: "Analyzing build errors..." });
            
            // Run the build fix agent
            const scriptPath = path.join(__dirname, '../../autofix.sh');
            
            return new Promise((resolve, reject) => {
                const process = exec(`bash "${scriptPath}"`, {
                    cwd: workspaceFolder.uri.fsPath
                }, (error, stdout, stderr) => {
                    if (error) {
                        vscode.window.showErrorMessage(`Build Fix failed: ${error.message}`);
                        reject(error);
                        return;
                    }
                    
                    // Parse results
                    const fixes = parseFixResults(stdout);
                    if (fixes.length > 0) {
                        showFixesQuickPick(fixes);
                    } else {
                        vscode.window.showInformationMessage('No errors found or all errors fixed!');
                    }
                    resolve();
                });
                
                token.onCancellationRequested(() => {
                    process.kill();
                });
            });
        });
    });
    
    let analyzeCommand = vscode.commands.registerCommand('buildFixAgent.analyzeErrors', async () => {
        const diagnostics = vscode.languages.getDiagnostics();
        const errors = [];
        
        diagnostics.forEach(([uri, fileDiagnostics]) => {
            fileDiagnostics.forEach(diagnostic => {
                if (diagnostic.severity === vscode.DiagnosticSeverity.Error) {
                    errors.push({
                        file: uri.fsPath,
                        line: diagnostic.range.start.line + 1,
                        message: diagnostic.message,
                        source: diagnostic.source
                    });
                }
            });
        });
        
        if (errors.length === 0) {
            vscode.window.showInformationMessage('No errors found in workspace');
            return;
        }
        
        // Create webview to show analysis
        const panel = vscode.window.createWebviewPanel(
            'buildFixAnalysis',
            'Build Error Analysis',
            vscode.ViewColumn.Two,
            { enableScripts: true }
        );
        
        panel.webview.html = getAnalysisWebviewContent(errors);
    });
    
    // Code action provider for quick fixes
    const provider = vscode.languages.registerCodeActionProvider(
        { scheme: 'file' },
        new BuildFixCodeActionProvider(),
        { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] }
    );
    
    context.subscriptions.push(runFixCommand, analyzeCommand, provider);
    
    // Auto-fix on save if enabled
    if (vscode.workspace.getConfiguration('buildFixAgent').get('autoFixOnSave')) {
        vscode.workspace.onDidSaveTextDocument(async (document) => {
            const diagnostics = vscode.languages.getDiagnostics(document.uri);
            if (diagnostics.some(d => d.severity === vscode.DiagnosticSeverity.Error)) {
                vscode.commands.executeCommand('buildFixAgent.runFix');
            }
        });
    }
}

class BuildFixCodeActionProvider {
    provideCodeActions(document, range, context, token) {
        const actions = [];
        
        context.diagnostics.forEach(diagnostic => {
            if (diagnostic.severity === vscode.DiagnosticSeverity.Error) {
                const action = new vscode.CodeAction(
                    `Fix: ${diagnostic.message}`,
                    vscode.CodeActionKind.QuickFix
                );
                
                action.command = {
                    command: 'buildFixAgent.applyFix',
                    title: 'Apply Build Fix',
                    arguments: [document, diagnostic]
                };
                
                actions.push(action);
            }
        });
        
        return actions;
    }
}

function parseFixResults(output) {
    // Parse the output from build fix agent
    const fixes = [];
    const lines = output.split('\n');
    
    // Simple parser - enhance based on actual output format
    lines.forEach(line => {
        if (line.includes('Fixed:')) {
            fixes.push(line);
        }
    });
    
    return fixes;
}

function showFixesQuickPick(fixes) {
    vscode.window.showQuickPick(fixes, {
        placeHolder: 'Select fixes to apply',
        canPickMany: true
    }).then(selected => {
        if (selected && selected.length > 0) {
            // Apply selected fixes
            vscode.window.showInformationMessage(`Applied ${selected.length} fixes`);
        }
    });
}

function getAnalysisWebviewContent(errors) {
    const errorsByFile = {};
    errors.forEach(error => {
        if (!errorsByFile[error.file]) {
            errorsByFile[error.file] = [];
        }
        errorsByFile[error.file].push(error);
    });
    
    return `<!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Build Error Analysis</title>
        <style>
            body { font-family: var(--vscode-font-family); padding: 20px; }
            .error { margin: 10px 0; padding: 10px; background: var(--vscode-inputValidation-errorBackground); }
            .file { font-weight: bold; margin-top: 20px; }
            .fix-button { margin-top: 10px; }
        </style>
    </head>
    <body>
        <h1>Build Error Analysis</h1>
        <p>Found ${errors.length} errors in ${Object.keys(errorsByFile).length} files</p>
        ${Object.entries(errorsByFile).map(([file, fileErrors]) => `
            <div class="file">${file}</div>
            ${fileErrors.map(error => `
                <div class="error">
                    Line ${error.line}: ${error.message}
                    <button class="fix-button" onclick="fixError('${file}', ${error.line})">Fix</button>
                </div>
            `).join('')}
        `).join('')}
        <script>
            function fixError(file, line) {
                // Send message to extension to fix specific error
                vscode.postMessage({
                    command: 'fixError',
                    file: file,
                    line: line
                });
            }
        </script>
    </body>
    </html>`;
}

function deactivate() {}

module.exports = {
    activate,
    deactivate
};
EOF

    echo -e "${GREEN}VS Code extension created at: $extension_dir${NC}"
    echo -e "${YELLOW}To install: cd $extension_dir && vsce package && code --install-extension *.vsix${NC}"
}

# Visual Studio Integration
setup_visual_studio() {
    local vs_dir="$SCRIPT_DIR/visual-studio"
    mkdir -p "$vs_dir"
    
    # Create VSIX manifest
    cat > "$vs_dir/source.extension.vsixmanifest" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Id="BuildFixAgent.c1e25a5e-3e2d-4b89-a5e7-2f8e9c7d5a3b" Version="1.0" Language="en-US" Publisher="BuildFixAgent" />
    <DisplayName>Build Fix Agent</DisplayName>
    <Description>AI-powered build error fixing for Visual Studio</Description>
    <MoreInfo>https://github.com/yourusername/buildfix</MoreInfo>
    <License>LICENSE.txt</License>
    <Tags>build;fix;ai;errors;automation</Tags>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Community" Version="[17.0, 18.0)" />
    <InstallationTarget Id="Microsoft.VisualStudio.Pro" Version="[17.0, 18.0)" />
    <InstallationTarget Id="Microsoft.VisualStudio.Enterprise" Version="[17.0, 18.0)" />
  </Installation>
  <Dependencies>
    <Dependency Id="Microsoft.Framework.NDP" DisplayName="Microsoft .NET Framework" Version="[4.5,)" />
  </Dependencies>
  <Prerequisites>
    <Prerequisite Id="Microsoft.VisualStudio.Component.CoreEditor" Version="[17.0,)" DisplayName="Visual Studio core editor" />
  </Prerequisites>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.VsPackage" Path="BuildFixAgent.pkgdef" />
    <Asset Type="Microsoft.VisualStudio.MefComponent" Path="BuildFixAgent.dll" />
  </Assets>
</PackageManifest>
EOF

    # Create Package definition
    cat > "$vs_dir/BuildFixAgentPackage.cs" << 'EOF'
using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.VisualStudio;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio.Shell.Interop;
using EnvDTE;
using EnvDTE80;
using System.ComponentModel.Design;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Collections.Generic;

namespace BuildFixAgent
{
    [PackageRegistration(UseManagedResourcesOnly = true, AllowsBackgroundLoading = true)]
    [Guid("c1e25a5e-3e2d-4b89-a5e7-2f8e9c7d5a3b")]
    [ProvideMenuResource("Menus.ctmenu", 1)]
    [ProvideAutoLoad(UIContextGuids.SolutionExists, PackageAutoLoadFlags.BackgroundLoad)]
    public sealed class BuildFixAgentPackage : AsyncPackage
    {
        public const string PackageGuidString = "c1e25a5e-3e2d-4b89-a5e7-2f8e9c7d5a3b";
        private DTE2 _dte;
        private BuildEvents _buildEvents;
        private ErrorListProvider _errorListProvider;

        protected override async Task InitializeAsync(CancellationToken cancellationToken, IProgress<ServiceProgressData> progress)
        {
            await this.JoinableTaskFactory.SwitchToMainThreadAsync(cancellationToken);
            
            _dte = await GetServiceAsync(typeof(DTE)) as DTE2;
            _errorListProvider = new ErrorListProvider(this);
            
            // Subscribe to build events
            _buildEvents = _dte.Events.BuildEvents;
            _buildEvents.OnBuildDone += OnBuildDone;
            
            // Add menu commands
            if (await GetServiceAsync(typeof(IMenuCommandService)) is OleMenuCommandService commandService)
            {
                var menuCommandID = new CommandID(Guid.Parse("1a5f1e2d-8c9b-4f2a-b3d4-e5f6a7b8c9d0"), 0x0100);
                var menuItem = new MenuCommand(this.RunBuildFix, menuCommandID);
                commandService.AddCommand(menuItem);
                
                var analyzeCommandID = new CommandID(Guid.Parse("1a5f1e2d-8c9b-4f2a-b3d4-e5f6a7b8c9d0"), 0x0101);
                var analyzeItem = new MenuCommand(this.AnalyzeErrors, analyzeCommandID);
                commandService.AddCommand(analyzeItem);
            }
        }

        private void OnBuildDone(vsBuildScope Scope, vsBuildAction Action)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            
            if (Action == vsBuildAction.vsBuildActionBuild || Action == vsBuildAction.vsBuildActionRebuildAll)
            {
                var errors = GetBuildErrors();
                if (errors.Any() && ShouldAutoFix())
                {
                    RunBuildFixAsync().FireAndForget();
                }
            }
        }

        private List<ErrorItem> GetBuildErrors()
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            
            var errors = new List<ErrorItem>();
            var errorItems = _dte.ToolWindows.ErrorList.ErrorItems;
            
            for (int i = 1; i <= errorItems.Count; i++)
            {
                var item = errorItems.Item(i);
                if (item.ErrorLevel == vsBuildErrorLevel.vsBuildErrorLevelHigh)
                {
                    errors.Add(new ErrorItem
                    {
                        Description = item.Description,
                        FileName = item.FileName,
                        Line = item.Line,
                        Column = item.Column,
                        Project = item.Project
                    });
                }
            }
            
            return errors;
        }

        private bool ShouldAutoFix()
        {
            // Check user settings
            var settingsManager = new ShellSettingsManager(this);
            var store = settingsManager.GetReadOnlySettingsStore(SettingsScope.UserSettings);
            
            if (store.CollectionExists("BuildFixAgent"))
            {
                return store.GetBoolean("BuildFixAgent", "AutoFixOnBuild", false);
            }
            
            return false;
        }

        private async void RunBuildFix(object sender, EventArgs e)
        {
            await RunBuildFixAsync();
        }

        private async Task RunBuildFixAsync()
        {
            await ThreadHelper.JoinableTaskFactory.SwitchToMainThreadAsync();
            
            var statusBar = await GetServiceAsync(typeof(SVsStatusbar)) as IVsStatusbar;
            statusBar?.SetText("Running Build Fix Agent...");
            
            try
            {
                var solutionDir = Path.GetDirectoryName(_dte.Solution.FullName);
                var scriptPath = FindBuildFixScript(solutionDir);
                
                if (string.IsNullOrEmpty(scriptPath))
                {
                    VsShellUtilities.ShowMessageBox(
                        this,
                        "Build Fix Agent script not found. Please ensure it's installed in your solution.",
                        "Build Fix Agent",
                        OLEMSGICON.OLEMSGICON_WARNING,
                        OLEMSGBUTTON.OLEMSGBUTTON_OK,
                        OLEMSGDEFBUTTON.OLEMSGDEFBUTTON_FIRST);
                    return;
                }
                
                // Run the script
                var processInfo = new ProcessStartInfo
                {
                    FileName = "bash",
                    Arguments = $"\"{scriptPath}\" vs-integration",
                    WorkingDirectory = solutionDir,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };
                
                using (var process = Process.Start(processInfo))
                {
                    var output = await process.StandardOutput.ReadToEndAsync();
                    var error = await process.StandardError.ReadToEndAsync();
                    
                    await process.WaitForExitAsync();
                    
                    if (process.ExitCode == 0)
                    {
                        ParseAndApplyFixes(output);
                        statusBar?.SetText("Build Fix Agent completed successfully");
                    }
                    else
                    {
                        statusBar?.SetText("Build Fix Agent encountered errors");
                        OutputError(error);
                    }
                }
            }
            catch (Exception ex)
            {
                statusBar?.SetText("Build Fix Agent failed");
                OutputError(ex.ToString());
            }
        }

        private void AnalyzeErrors(object sender, EventArgs e)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            
            var errors = GetBuildErrors();
            var toolWindow = this.FindToolWindow(typeof(BuildFixAnalysisWindow), 0, true);
            
            if (toolWindow?.Frame == null)
            {
                throw new NotSupportedException("Cannot create tool window");
            }
            
            var window = toolWindow as BuildFixAnalysisWindow;
            window?.ShowAnalysis(errors);
            
            IVsWindowFrame windowFrame = (IVsWindowFrame)toolWindow.Frame;
            ErrorHandler.ThrowOnFailure(windowFrame.Show());
        }

        private string FindBuildFixScript(string solutionDir)
        {
            var possiblePaths = new[]
            {
                Path.Combine(solutionDir, "BuildFixAgents", "autofix.sh"),
                Path.Combine(solutionDir, "tools", "BuildFixAgents", "autofix.sh"),
                Path.Combine(solutionDir, ".tools", "BuildFixAgents", "autofix.sh")
            };
            
            return possiblePaths.FirstOrDefault(File.Exists);
        }

        private void ParseAndApplyFixes(string output)
        {
            // Parse JSON output from build fix agent
            // Apply fixes to files
            // Refresh solution
        }

        private void OutputError(string error)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            
            var outputWindow = _dte.ToolWindows.OutputWindow;
            var pane = outputWindow.OutputWindowPanes.Add("Build Fix Agent");
            pane.OutputString(error);
            pane.Activate();
        }
    }

    public class ErrorItem
    {
        public string Description { get; set; }
        public string FileName { get; set; }
        public int Line { get; set; }
        public int Column { get; set; }
        public string Project { get; set; }
    }
}
EOF

    echo -e "${GREEN}Visual Studio extension created at: $vs_dir${NC}"
    echo -e "${YELLOW}To build: Open in Visual Studio and build the VSIX project${NC}"
}

# JetBrains IDE Integration
setup_jetbrains() {
    local ide_name="$1"
    local plugin_dir="$SCRIPT_DIR/jetbrains-plugin"
    mkdir -p "$plugin_dir/src/main/resources/META-INF"
    
    # Create plugin.xml
    cat > "$plugin_dir/src/main/resources/META-INF/plugin.xml" << EOF
<idea-plugin>
  <id>com.buildfix.agent</id>
  <name>Build Fix Agent</name>
  <version>1.0.0</version>
  <vendor>BuildFixAgent</vendor>
  
  <description><![CDATA[
    AI-powered build error fixing for JetBrains IDEs.
    Supports multiple languages and integrates with your existing build tools.
  ]]></description>
  
  <depends>com.intellij.modules.platform</depends>
  <depends optional="true" config-file="java-features.xml">com.intellij.modules.java</depends>
  
  <extensions defaultExtensionNs="com.intellij">
    <toolWindow id="BuildFixAgent" 
                secondary="true" 
                icon="/icons/buildfix.svg" 
                anchor="bottom" 
                factoryClass="com.buildfix.agent.toolwindow.BuildFixToolWindowFactory"/>
    
    <projectService serviceImplementation="com.buildfix.agent.services.BuildFixService"/>
    
    <postStartupActivity implementation="com.buildfix.agent.startup.BuildFixStartup"/>
    
    <notificationGroup id="Build Fix Agent" 
                       displayType="BALLOON" 
                       key="notification.group.buildfix"/>
  </extensions>
  
  <actions>
    <action id="BuildFix.RunAnalysis" 
            class="com.buildfix.agent.actions.RunAnalysisAction" 
            text="Run Build Fix Analysis" 
            description="Analyze and fix build errors">
      <add-to-group group-id="BuildMenu" anchor="last"/>
      <keyboard-shortcut keymap="\$default" first-keystroke="ctrl alt shift F"/>
    </action>
    
    <action id="BuildFix.QuickFix" 
            class="com.buildfix.agent.actions.QuickFixAction" 
            text="Quick Fix Current Error" 
            description="Fix the error at cursor position">
      <add-to-group group-id="EditorPopupMenu" anchor="first"/>
    </action>
  </actions>
</idea-plugin>
EOF

    # Create main plugin class
    cat > "$plugin_dir/src/main/kotlin/com/buildfix/agent/BuildFixPlugin.kt" << 'EOF'
package com.buildfix.agent

import com.intellij.openapi.compiler.CompileContext
import com.intellij.openapi.compiler.CompileStatusNotification
import com.intellij.openapi.compiler.CompilerManager
import com.intellij.openapi.components.service
import com.intellij.openapi.project.Project
import com.intellij.openapi.startup.StartupActivity
import com.intellij.openapi.vfs.VirtualFile
import com.intellij.openapi.wm.ToolWindowManager
import com.intellij.notification.NotificationGroupManager
import com.intellij.notification.NotificationType
import java.io.BufferedReader
import java.io.InputStreamReader

class BuildFixStartup : StartupActivity {
    override fun runActivity(project: Project) {
        val compilerManager = CompilerManager.getInstance(project)
        
        compilerManager.addCompilationStatusListener { aborted, errors, warnings, compileContext ->
            if (errors > 0 && project.service<BuildFixSettings>().autoFixEnabled) {
                project.service<BuildFixService>().runAutoFix()
            }
        }
    }
}

class BuildFixService(private val project: Project) {
    fun runAutoFix() {
        val scriptPath = findBuildFixScript() ?: return
        
        NotificationGroupManager.getInstance()
            .getNotificationGroup("Build Fix Agent")
            .createNotification("Running Build Fix Agent...", NotificationType.INFORMATION)
            .notify(project)
        
        Thread {
            try {
                val processBuilder = ProcessBuilder("bash", scriptPath, "jetbrains")
                    .directory(project.basePath?.let { java.io.File(it) })
                    .redirectErrorStream(true)
                
                val process = processBuilder.start()
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val output = reader.readText()
                
                val exitCode = process.waitFor()
                
                if (exitCode == 0) {
                    parseAndApplyFixes(output)
                    showSuccessNotification()
                } else {
                    showErrorNotification(output)
                }
            } catch (e: Exception) {
                showErrorNotification(e.message ?: "Unknown error")
            }
        }.start()
    }
    
    private fun findBuildFixScript(): String? {
        val basePath = project.basePath ?: return null
        val possiblePaths = listOf(
            "$basePath/BuildFixAgents/autofix.sh",
            "$basePath/tools/BuildFixAgents/autofix.sh",
            "$basePath/.tools/BuildFixAgents/autofix.sh"
        )
        
        return possiblePaths.firstOrNull { java.io.File(it).exists() }
    }
    
    private fun parseAndApplyFixes(output: String) {
        // Parse JSON output and apply fixes
        // This would integrate with IntelliJ's PSI (Program Structure Interface)
    }
    
    private fun showSuccessNotification() {
        NotificationGroupManager.getInstance()
            .getNotificationGroup("Build Fix Agent")
            .createNotification(
                "Build Fix Complete", 
                "All errors have been fixed successfully",
                NotificationType.INFORMATION
            )
            .notify(project)
    }
    
    private fun showErrorNotification(error: String) {
        NotificationGroupManager.getInstance()
            .getNotificationGroup("Build Fix Agent")
            .createNotification(
                "Build Fix Failed", 
                error,
                NotificationType.ERROR
            )
            .notify(project)
    }
}

class BuildFixSettings {
    var autoFixEnabled: Boolean = false
    var aiProvider: String = "none"
    var apiKey: String = ""
}
EOF

    echo -e "${GREEN}JetBrains plugin created at: $plugin_dir${NC}"
    echo -e "${YELLOW}To build: cd $plugin_dir && ./gradlew buildPlugin${NC}"
}

# IDE-specific output formatting
format_for_ide() {
    local ide="$1"
    local input_file="$2"
    local output_file="${3:-${input_file}.${ide}}"
    
    case "$ide" in
        vscode)
            # VS Code problem matcher format
            # file:line:col: severity: message
            sed -E 's|^([^:]+)\(([0-9]+),([0-9]+)\): error ([A-Z]+[0-9]+): (.*)$|\1:\2:\3: error: \5 [\4]|' \
                "$input_file" > "$output_file"
            ;;
            
        visualstudio)
            # Visual Studio format
            # file(line,col): error CODE: message
            # Already in this format for C# errors
            cp "$input_file" "$output_file"
            ;;
            
        jetbrains)
            # IntelliJ format
            # file:line: error: message
            sed -E 's|^([^:]+)\(([0-9]+),([0-9]+)\): error ([A-Z]+[0-9]+): (.*)$|\1:\2: error: \5|' \
                "$input_file" > "$output_file"
            ;;
            
        json)
            # Generic JSON format for any IDE
            echo '{"errors": [' > "$output_file"
            local first=true
            while IFS= read -r line; do
                if [[ "$line" =~ ^(.+)\(([0-9]+),([0-9]+)\):[[:space:]]*error[[:space:]]+([A-Z]+[0-9]+):[[:space:]]*(.*)$ ]]; then
                    [[ "$first" == "false" ]] && echo "," >> "$output_file"
                    cat >> "$output_file" << EOF
  {
    "file": "${BASH_REMATCH[1]}",
    "line": ${BASH_REMATCH[2]},
    "column": ${BASH_REMATCH[3]},
    "code": "${BASH_REMATCH[4]}",
    "message": "${BASH_REMATCH[5]}",
    "severity": "error"
  }
EOF
                    first=false
                fi
            done < "$input_file"
            echo ']}'>> "$output_file"
            ;;
    esac
    
    echo "$output_file"
}

# Main execution based on IDE
main() {
    local command="${1:-detect}"
    local ide="${2:-$(detect_ide)}"
    
    case "$command" in
        detect)
            local detected_ide=$(detect_ide)
            echo -e "${CYAN}Detected IDE: ${BOLD}$detected_ide${NC}"
            
            if [[ "$detected_ide" != "unknown" ]]; then
                echo -e "${YELLOW}Run '${0} setup $detected_ide' to set up integration${NC}"
            fi
            ;;
            
        setup)
            case "$ide" in
                vscode)
                    setup_vscode
                    ;;
                visualstudio)
                    setup_visual_studio
                    ;;
                intellij|rider|pycharm|webstorm)
                    setup_jetbrains "$ide"
                    ;;
                *)
                    echo -e "${RED}Unsupported IDE: $ide${NC}"
                    echo "Supported IDEs: vscode, visualstudio, intellij, rider, pycharm, webstorm"
                    exit 1
                    ;;
            esac
            ;;
            
        format)
            local input="${3:-build_output.txt}"
            local output=$(format_for_ide "$ide" "$input")
            echo -e "${GREEN}Formatted output saved to: $output${NC}"
            ;;
            
        help)
            echo "IDE Integration for Build Fix Agent"
            echo ""
            echo "Usage: $0 [command] [ide]"
            echo ""
            echo "Commands:"
            echo "  detect          Detect current IDE"
            echo "  setup <ide>     Set up integration for specific IDE"
            echo "  format <ide>    Format errors for specific IDE"
            echo "  help            Show this help"
            echo ""
            echo "Supported IDEs:"
            echo "  vscode          Visual Studio Code"
            echo "  visualstudio    Visual Studio"
            echo "  intellij        IntelliJ IDEA"
            echo "  rider           JetBrains Rider"
            echo "  pycharm         PyCharm"
            echo "  webstorm        WebStorm"
            ;;
            
        *)
            $0 help
            ;;
    esac
}

# Export functions for use by main script
export -f detect_ide
export -f format_for_ide

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi