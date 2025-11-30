#!/bin/bash

# Quick verification script for global installation

echo "🔍 Verifying SourceAtlas Global Installation..."
echo ""

# Check if commands exist
if [ -f "$HOME/.claude/commands/atlas.overview.md" ] && [ -f "$HOME/.claude/commands/atlas.pattern.md" ]; then
    echo "✅ Commands installed in ~/.claude/commands/"
else
    echo "❌ Commands not found. Run ./install-global.sh first"
    exit 1
fi

# Check if scripts are accessible
if [ -d "$HOME/.claude/scripts/atlas" ]; then
    echo "✅ Scripts linked in ~/.claude/scripts/atlas/"
else
    echo "❌ Scripts not found. Run ./install-global.sh first"
    exit 1
fi

# Check if symlinks are valid (if they are symlinks)
if [ -L "$HOME/.claude/commands/atlas.overview.md" ]; then
    target=$(readlink "$HOME/.claude/commands/atlas.overview.md")
    if [ -f "$target" ]; then
        echo "✅ Symlinks are valid"
    else
        echo "⚠️  Broken symlink detected: $target"
        exit 1
    fi
fi

echo ""
echo "🎉 All checks passed!"
echo ""
echo "You can now use these commands in ANY project:"
echo "  /atlas.overview"
echo "  /atlas.pattern"
echo ""
echo "Try it:"
echo "  cd ~/projects/any-project"
echo "  # Then in Claude Code, type: /atlas.overview"
