# SourceAtlas Plugin

**AI-powered codebase understanding assistant for Claude Code**

SourceAtlas helps developers quickly understand any codebase through pattern learning and impact analysis.

## ✨ Features

- **🎯 Pattern Learning** (`/atlas-pattern`) - Learn design patterns from existing code
- **📊 Impact Analysis** (`/atlas-impact`) - Analyze change impact (Coming Soon)
- **🔍 Quick Search** (`/atlas-find`) - Rapidly locate functionality (Coming Soon)
- **🔍 Project Overview** (`/atlas-overview`) - Quick project understanding

## 🚀 Installation

### Method 1: Local Development/Testing

```bash
# Clone or download this repository
cd ~/.claude/commands
git clone https://github.com/justinlee/sourceatlas-plugin.git sourceatlas

# Or copy the plugin directory
cp -r /path/to/sourceatlas-plugin ~/.claude/commands/sourceatlas
```

### Method 2: Via Claude Code Plugin (Recommended)

```bash
# In Claude Code, add the marketplace
/plugin marketplace add justinlee/sourceatlas-marketplace

# Install the plugin
/plugin install sourceatlas@sourceatlas-marketplace

# Start using
/atlas-pattern "api endpoint"
```

## 📖 Usage

### `/atlas-pattern` - Learn Design Patterns ⭐

Learn how the current codebase implements specific patterns.

**Examples:**

```bash
# Learn API endpoint patterns
/atlas-pattern "api endpoint"

# Learn background job patterns
/atlas-pattern "background job"

# Learn file upload patterns
/atlas-pattern "file upload"

# Learn authentication patterns
/atlas-pattern "authentication"

# Learn database query patterns
/atlas-pattern "database query"
```

**What you get:**
- 📁 Best example files with line numbers
- 🎯 Standard implementation flow
- 📐 Key conventions to follow
- ⚠️ Common pitfalls to avoid
- 🧪 Testing patterns
- 📚 Concrete implementation steps

### Coming Soon

- `/atlas-impact` - Analyze the impact of code changes
- `/atlas-find` - Quickly locate functionality
- `/atlas` - Complete three-stage codebase analysis

## 🎓 How It Works

SourceAtlas uses **information theory principles** to understand codebases efficiently:

1. **High-Entropy File Prioritization** - Scans <5% of files to achieve 70-80% understanding
2. **Pattern Recognition** - Extracts reusable design patterns from existing code
3. **Actionable Guidance** - Provides concrete steps to follow existing conventions

**Key Principles:**
- ✅ Scan <5% of files (targeted, not exhaustive)
- ✅ Focus on patterns, not implementation details
- ✅ Provide actionable, concrete guidance
- ✅ Always cite specific file locations

## 🧪 Example Output

When you run `/atlas-pattern "api endpoint"` in a Next.js project:

```markdown
# 📋 Pattern: REST API Endpoints (Next.js API Routes)

## ✅ How This Codebase Handles It

This project uses Next.js API routes with TypeScript, following a
consistent controller pattern with centralized error handling and
Zod validation.

## 📁 Best Example Files

- **`src/pages/api/users/[id].ts:15`** - Complete CRUD endpoint example
- **`src/pages/api/auth/login.ts:8`** - POST endpoint with validation
- **`src/lib/api/errorHandler.ts:5`** - Centralized error handling

## 🎯 Standard Flow

1. **Define route** in `src/pages/api/[route].ts`
2. **Validate request** using Zod schema
3. **Call service layer** for business logic
4. **Return standardized response** (success/error format)
5. **Handle errors** through centralized error handler

... (and more)
```

## 🛠️ Development

### Project Structure

```
sourceatlas-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── commands/
│   └── atlas-pattern.md     # Pattern learning command
├── README.md
└── LICENSE
```

### Testing Locally

```bash
# Create a test marketplace structure
mkdir -p ~/test-marketplace
cp -r plugin ~/test-marketplace/sourceatlas-plugin

# Add local marketplace in Claude Code
/plugin marketplace add file:///Users/yourname/test-marketplace

# Install and test
/plugin install sourceatlas-plugin@test-marketplace

# Test in any project
cd ~/your-project
/atlas-pattern "api endpoint"

# After making changes
/plugin uninstall sourceatlas-plugin@test-marketplace
# Make your changes
/plugin install sourceatlas-plugin@test-marketplace
```

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes locally
4. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) for details

## 🙏 Acknowledgments

Based on SourceAtlas v2.0 methodology:
- Three-stage analysis framework
- Information theory principles
- High-entropy file prioritization

## 📚 Resources

- [SourceAtlas Documentation](https://github.com/justinlee/sourceatlas2)
- [Claude Code Plugin Docs](https://code.claude.com/docs/en/plugins)
- [Usage Examples](./USAGE_EXAMPLES.md) (Coming Soon)

---

**SourceAtlas v2.5.1** - Understanding codebases at the speed of thought 🚀
