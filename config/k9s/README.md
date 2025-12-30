# K9s Plugins for Flux CD

This directory contains K9s plugin configurations that provide keyboard shortcuts for managing Flux CD resources directly from K9s.

## Installation

### Automatic Installation (Recommended)

The plugins are automatically installed when you run the full deployment:

```bash
task install
```

Or install them separately:

```bash
task install:k9s-plugins
```

### Manual Installation

If you prefer to install manually:

```bash
# Copy the plugin file to your K9s config directory
mkdir -p ~/.k9s
cp config/k9s/plugin.yml ~/.k9s/plugin.yml
```

## Prerequisites

- **K9s**: The Kubernetes CLI tool (`brew install k9s` or [download](https://k9scli.io/topics/install/))
- **Flux CLI**: Required for plugin functionality (`curl -s https://fluxcd.io/install.sh | sudo bash`)
- **jq**: Required for some plugins like `trace` and `get-suspended-*` (`brew install jq`)

## Usage

After installation, restart K9s to load the plugins:

```bash
k9s
```

### Keyboard Shortcuts

| Shortcut | Resource Type | Action | Confirmation |
|----------|--------------|--------|--------------|
| **Shift-T** | HelmRelease | Toggle suspend/resume | Yes |
| **Shift-T** | Kustomization | Toggle suspend/resume | Yes |
| **Shift-T** | ResourceSet | Toggle suspend/resume | No |
| **Shift-T** | InputProvider | Toggle suspend/resume | No |
| **Shift-R** | GitRepository | Reconcile source | No |
| **Shift-R** | HelmRelease | Reconcile | No |
| **Shift-R** | Kustomization | Reconcile | No |
| **Shift-R** | ImageRepository | Reconcile | No |
| **Shift-R** | ImageUpdateAutomation | Reconcile | No |
| **Shift-R** | ResourceSet | Reconcile | No |
| **Shift-R** | InputProvider | Reconcile | No |
| **Shift-Z** | HelmRepository | Reconcile source | No |
| **Shift-Z** | OCIRepository | Reconcile source | No |
| **Shift-S** | HelmRelease | List suspended releases | No |
| **Shift-S** | Kustomization | List suspended kustomizations | No |
| **Shift-P** | Any | Trace resource dependencies | No |

### How to Use

1. **Navigate to a resource** in K9s (e.g., `:helmreleases` or `:kustomizations`)
2. **Select a resource** by moving the cursor to it
3. **Press the shortcut key** (e.g., `Shift-T` to toggle suspend/resume)
4. **Follow the prompts** if confirmation is required

### Examples

#### Toggle a HelmRelease

```bash
# In K9s:
# 1. Type :helmreleases
# 2. Navigate to your HelmRelease
# 3. Press Shift-T
# 4. Confirm the action
```

#### Reconcile a Kustomization

```bash
# In K9s:
# 1. Type :kustomizations
# 2. Navigate to your Kustomization
# 3. Press Shift-R (no confirmation needed)
```

#### List Suspended Resources

```bash
# In K9s:
# 1. Type :helmreleases or :kustomizations
# 2. Press Shift-S
# 3. View the list of suspended resources
```

#### Trace Resource Dependencies

```bash
# In K9s:
# 1. Navigate to any resource
# 2. Press Shift-P
# 3. View the dependency trace
```

## Plugin Details

### Toggle Plugins

Toggle plugins allow you to suspend or resume Flux resources:
- **Suspend**: Temporarily stops reconciliation
- **Resume**: Re-enables reconciliation

### Reconcile Plugins

Reconcile plugins force an immediate reconciliation of Flux resources:
- **GitRepository**: Triggers a git pull and reconciliation
- **HelmRelease**: Triggers a Helm release reconciliation
- **Kustomization**: Triggers a Kustomize reconciliation
- **ImageRepository**: Triggers an image repository scan
- **ImageUpdateAutomation**: Triggers an image update automation run

### Trace Plugin

The trace plugin shows the dependency chain for a resource, helping you understand:
- What resources depend on the selected resource
- What resources the selected resource depends on
- The complete dependency graph

## Troubleshooting

### Plugins Not Working

1. **Check K9s version**: Ensure you're using a recent version of K9s
   ```bash
   k9s version
   ```

2. **Verify plugin file location**: Ensure the file is at `~/.k9s/plugin.yml`
   ```bash
   ls -la ~/.k9s/plugin.yml
   ```

3. **Restart K9s**: Exit and restart K9s after installation

4. **Check Flux CLI**: Ensure Flux CLI is installed and in PATH
   ```bash
   flux --version
   ```

5. **Check jq**: Some plugins require jq
   ```bash
   jq --version
   ```

### Plugin Conflicts

If you have existing K9s plugins, the installation script will:
- Offer to backup your existing file
- Allow you to manually merge configurations
- Skip installation if you prefer

## Updating Plugins

To update the plugins:

```bash
# Re-run the installation task
task install:k9s-plugins
```

Or manually:

```bash
cp config/k9s/plugin.yml ~/.k9s/plugin.yml
```

## Credits

Some plugins are based on the [Flux CD community discussions](https://github.com/fluxcd/flux2/discussions/2494).

## Related Documentation

- [K9s Documentation](https://k9scli.io/)
- [Flux CD Documentation](https://fluxcd.io/)
- [Flux CLI Reference](https://fluxcd.io/flux/cmd/)


