# WILD DASH AI Coding Guide

This repository is developed with Godot 4.7.1 plus the existing Node, Vite, Electron toolchain.

## Working style

- Use a feature branch for new work. Do not push experimental gameplay changes directly to a stable base branch.
- Keep changes small enough to review and test.
- Before changing behavior, inspect the production scene and the script actually wired into that scene.
- Do not assume a source file is production just because it exists. Confirm the `.tscn` reference or inheritance chain.
- Preserve campaign flow across all rounds unless the task explicitly changes it.

## Godot safety rules

- Godot scene comments use `;`, not `#`.
- Do not commit `.godot/` cache content.
- Do not make generated import or UID churn part of an unrelated change.
- When touching Round 3, verify the complete inheritance chain and production `logspire_leap.tscn` load.
- A visible gameplay obstacle must have matching collision, or be hidden when collision is disabled.
- Recovery logic must never strand racers underwater or inside major geometry.

## Verification before commit

Run these from the repository root, or use the VS Code task `WILD DASH: Verify Before Commit`:

```text
npm run typecheck
npm run lint
npm test
npm run build
```

For Godot changes, also open the project with Godot 4.7.1 and test the affected production scene. Round 3 can be tested directly with `logspire_leap.tscn`.

## Git workflow

1. Pull the latest merged base.
2. Create or switch to a feature branch.
3. Make the smallest coherent change.
4. Run verification.
5. Review `git status` and the diff before committing.
6. Push and open a PR for review.

## VS Code workflow

Recommended extensions are listed in `.vscode/extensions.json`.
Useful tasks are available through `Terminal > Run Task`.
Use the integrated terminal for Git, npm, and Godot commands so the AI assistant and developer can reason from the same repository state.
