# App Service - React Application

A modern React application built with **Vite** and managed with **Yarn** package manager. This project provides a minimal, high-performance setup for React development with Hot Module Replacement (HMR) and ESLint configuration.

## Project Overview

- **Framework**: React 19
- **Build Tool**: Vite 8
- **Package Manager**: Yarn
- **Node Version**: 18+ recommended
- **Development Server**: Port 5173

## Getting Started

### Prerequisites

- Node.js 18 or higher
- Yarn package manager (installed globally)

### Installation

All dependencies are already installed. If you need to reinstall:

```bash
yarn install
```

## Available Scripts

### Development Server

Start the development server with hot module replacement:

```bash
yarn dev
```

Access the application at `http://localhost:5173/`

### Build for Production

Create an optimized production build:

```bash
yarn build
```

Output is generated in the `dist` folder.

### Preview Production Build

Preview the production build locally:

```bash
yarn preview
```

### Linting

Run ESLint to check code quality:

```bash
yarn lint
```

## Project Structure

```
src/
  ├── App.jsx          # Main App component
  ├── App.css          # App styles
  ├── main.jsx         # Entry point
  ├── index.css        # Global styles
  └── assets/          # Static assets
public/                # Public assets
index.html             # HTML template
vite.config.js         # Vite configuration
.eslintrc.cjs          # ESLint configuration
```

## Technologies

- **React 19** - UI library with React Hooks and Fast Refresh
- **Vite 8** - Lightning-fast build tool with instant HMR
- **@vitejs/plugin-react** - Babel-based React Fast Refresh plugin
- **ESLint** - Code quality and style checking

## Features

- ⚡ **Fast Development** - Instant HMR updates with Vite
- 🔧 **Modern Tooling** - Vite provides optimized builds
- 📦 **Yarn Package Manager** - Faster, more reliable dependency management
- 🎯 **ESLint Integration** - Built-in code quality checking
- 🔄 **React 19** - Latest React features and improvements

## Development Tips

1. **Hot Module Replacement**: Changes to components are reflected instantly without full page reload
2. **Fast Refresh**: React state is preserved during development changes
3. **Source Maps**: DevTools support for debugging

## Production Deployment

Build the project and serve the `dist` folder with a static hosting service:

```bash
yarn build
```

The production build is fully optimized and ready for deployment.

## Available Tasks in VS Code

Use VS Code's Task system (Tasks menu or Ctrl+Shift+B) to run:
- **yarn dev** - Start development server (default)
- **yarn build** - Create production build
- **yarn lint** - Run linter
- **yarn preview** - Preview production build

## Customization

- Modify `vite.config.js` for custom build configurations
- Update `.eslintrc.cjs` to adjust linting rules
- Edit `index.html` to change the application template
