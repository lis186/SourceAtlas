# SourceAtlas Global Installation Guide

> 🌐 **English** | [繁體中文](./GLOBAL_INSTALLATION.zh-TW.md)

**Install once, use 4 SourceAtlas commands in any project**

v2.5 | Updated: 2025-11-30

---

## System Requirements

Before starting, ensure your system meets these requirements:

| Requirement | Minimum Version | How to Check |
|-------------|-----------------|--------------|
| **Claude Code** | 0.3+ | Run `/help` in Claude Code |
| **Git** | 2.0+ | `git --version` |
| **Bash** | 3.2+ | `bash --version` |
| **OS** | macOS 11+ / Ubuntu 20.04+ | `uname -a` |

**Quick Verification**:

```bash
# One-click check all dependencies
echo "Claude Code: Manual check required (run /help)"
echo "Git: $(git --version 2>&1 | head -1)"
echo "Bash: $(bash --version 2>&1 | head -1)"
echo "OS: $(uname -s) $(uname -r)"
```

⚠️ **Don't meet requirements?** See [Troubleshooting](#troubleshooting) section

---

## Quick Start

### 1. Install

Run in the SourceAtlas project root directory:

```bash
./install-global.sh
```

This installs 4 commands to `~/.claude/commands/`.

### 2. Verify Installation

```bash
./install-global.sh --check
```

You should see:

```
✓ atlas.init.md → [path] (symlink OK)
✓ atlas.overview.md → [path] (symlink OK)
✓ atlas.pattern.md → [path] (symlink OK)
✓ atlas.impact.md → [path] (symlink OK)
✓ scripts/atlas → [path] (symlink OK)
✓ All commands installed and working
```

### 3. Start Using

Now you can use in **any project**:

```bash
cd ~/projects/any-project

# Run in Claude Code
/atlas.init                        # First use: inject auto-trigger rules
/atlas.overview
/atlas.pattern "api endpoint"
/atlas.impact "src/api/users.ts"
```

---

## Available Commands

### `/atlas.init`

Project initialization (run on first use)

- **Time**: <1 minute
- **Function**: Injects SourceAtlas auto-trigger rules into project's CLAUDE.md
- **Effect**: Claude will automatically suggest appropriate Atlas commands afterwards

### `/atlas.overview`

Quick project understanding

- **Time**: 10-15 minutes
- **Output**: Tech stack, architecture patterns, code quality, project scale

### `/atlas.pattern [pattern]`

Learn design patterns

- **Time**: 0.1-30 seconds
- **Output**: Best example files + implementation guide
- **Supports**: 71 patterns (iOS/TypeScript/Android)

### `/atlas.impact [target]`

Analyze code change impact

- **Time**: 1-2 minutes
- **Output**: Dependency tracking, Breaking Changes, Migration Checklist
- **iOS Special**: Swift/ObjC interop risk analysis

---

## Installation Options

### Default: Symlink

```bash
./install-global.sh
```

**Pros**:
- ✅ Auto-sync updates
- ✅ Saves disk space
- ✅ Single source of truth

**Best for**: Frequent use, want automatic updates

### Copy Method

```bash
INSTALL_METHOD=copy ./install-global.sh
```

**Pros**:
- ✅ Independent copy
- ✅ Version locked
- ✅ Can customize modifications

**Best for**: Need stable version, want customization

---

## Management Commands

### Check Installation Status

```bash
./install-global.sh --check
```

### Update Commands

**Symlink method** (automatic):
```bash
cd ~/dev/sourceatlas2
git pull
# All projects automatically use latest version
```

**Copy method** (manual):
```bash
cd ~/dev/sourceatlas2
git pull
./install-global.sh
```

### Uninstall

```bash
./install-global.sh --remove
```

This removes:
- `~/.claude/commands/atlas.init.md`
- `~/.claude/commands/atlas.overview.md`
- `~/.claude/commands/atlas.pattern.md`
- `~/.claude/commands/atlas.impact.md`
- `~/.claude/scripts/atlas/`

---

## Directory Structure

### Global Configuration After Installation

```
~/.claude/
├── commands/
│   ├── atlas.init.md            # → sourceatlas2/.claude/commands/
│   ├── atlas.overview.md        # → sourceatlas2/.claude/commands/
│   ├── atlas.pattern.md         # → sourceatlas2/.claude/commands/
│   ├── atlas.impact.md          # → sourceatlas2/.claude/commands/
│   └── [your other global commands]
│
└── scripts/
    └── atlas/                    # → sourceatlas2/scripts/atlas/
```

### Coexistence with Project-Level Commands

Global commands don't conflict with project-specific commands:

```
your-project/
├── .claude/
│   └── commands/
│       ├── deploy.md            # Project-specific command
│       └── test.md              # Project-specific command

# Claude Code sees both:
# - Global: /atlas.init, /atlas.overview, /atlas.pattern, /atlas.impact
# - Project: /deploy, /test
```

**Note**: Ensure project commands don't use `atlas.*` names to avoid conflicts.

---

## FAQ

### Q: Will global commands affect performance?

A: No. Claude Code only executes commands when you use them.

### Q: Can I customize global commands?

A: Yes!

**Symlink method**: Modify `sourceatlas2/.claude/commands/` source files (affects all projects)

**Copy method**: Modify `~/.claude/commands/atlas.*.md` (affects local only)

### Q: What happens if I move or delete the SourceAtlas project?

**Symlink method**: Commands will break
```bash
# Fix: Re-clone to same location or uninstall and reinstall
./install-global.sh --remove
cd /new/location/sourceatlas2
./install-global.sh
```

**Copy method**: Unaffected

### Q: Can I create my own global commands?

A: Yes! Reference the SourceAtlas command structure:

```bash
# Create your command
cat > ~/.claude/commands/my-command.md << 'EOF'
---
description: My custom command
---

# My Command Prompt
[Your prompt content...]
EOF

# Use in any project
/my-command
```

---

## Troubleshooting

### Issue: Commands Not Available

**Symptom**: Claude Code can't find command when running `/atlas.overview`

**Solution**:
```bash
# 1. Check installation
./install-global.sh --check

# 2. Reinstall
./install-global.sh --remove
./install-global.sh
```

### Issue: Broken Symlink

**Symptom**: `--check` shows broken symlink

**Solution**:
```bash
# Confirm SourceAtlas project exists
ls ~/dev/sourceatlas2

# If not exists, re-clone
git clone https://github.com/lis186/SourceAtlas.git ~/dev/sourceatlas2

# Reinstall
cd ~/dev/sourceatlas2
./install-global.sh
```

---

## More Resources

- **Main Documentation**: [README.md](./README.md)
- **Usage Guide**: [USAGE_GUIDE.md](./USAGE_GUIDE.md)
- **Report Issues**: [GitHub Issues](https://github.com/lis186/SourceAtlas/issues)

---

**Enjoy using SourceAtlas in any project!** 🚀
