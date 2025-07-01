#!/bin/bash

# AudioStack Development Setup Script
# This script sets up the development environment with commit linting

set -e

echo "🚀 Setting up AudioStack development environment..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ first."
    echo "   Visit: https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js version 18+ required. Current version: $(node --version)"
    exit 1
fi

# Install dependencies
echo "📦 Installing development dependencies..."
npm install

# Initialize husky
echo "🔧 Setting up Git hooks..."
npx husky install

# Make hooks executable (in case they're not)
chmod +x .husky/commit-msg

echo "✅ Development environment setup complete!"
echo ""
echo "📋 Next steps:"
echo "   • Make commits using conventional commit format"
echo "   • Example: git commit -m 'feat: add new audio processing feature'"
echo "   • Your commits will be automatically validated before creation"
echo ""
echo "🔗 Learn more about Conventional Commits:"
echo "   https://www.conventionalcommits.org/"
