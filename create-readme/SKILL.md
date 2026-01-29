---
name: create-readme
description: Create maintainable README files for services and projects. Use when asked to document a service, create a README, or explain a project's architecture. Focuses on lasting concepts (architectural patterns, design rationale, component responsibilities) rather than implementation details (class names, method signatures, line numbers) that change frequently.
---

# Create README Skill

Generate documentation that survives refactoring by focusing on concepts over implementation.

## Workflow

1. **Analyze** - Review project structure, entry points, configuration, and dependencies
2. **Identify** - Discover architectural patterns, components, and design decisions
3. **Document** - Write README using the structure below (adapt sections to project type)
4. **Validate** - Ensure no class names, method signatures, or line numbers that would break on refactor

## README Structure

```markdown
# [Name]

## Overview
Brief introduction (2-3 paragraphs max). What it does and WHY it exists.
Link to demo, website, or detailed docs if available.

## Architecture
High-level design, component responsibilities, data flow. Use mermaid diagram for how components interact with each others.

## Features
Key capabilities (bulleted list).

## Prerequisites
Required dependencies, tools, or environment setup.

## Usage
Basic usage examples to get users productive quickly.


## See Also
Links to related docs, APIs, or source files.
```

## Writing Style Guidelines

Apply web writing best practices (people scan, not read):

- **Short paragraphs** - 3-5 lines max, one concept per paragraph
- **Bulleted lists** - Prefer over comma-separated lists
- **Meaningful link text** - Never use "click here"; use descriptive text
- **Highlight keywords** - Use **bold** for key terms (avoid underline)
- **Inverted pyramid** - Start with the most important information
- **Code blocks with syntax highlighting** - Specify language ```csharp```

## Content Guidelines

| Include                               | Avoid                          |
| ------------------------------------- | ------------------------------ |
| Architectural patterns + rationale    | Specific class names           |
| Component responsibilities (abstract) | Method signatures              |
| Design decisions with WHY             | Line number references         |
| Directory overview                    | Property/setting names         |
| File links in "See Also"              | Package names (use categories) |

## Validation Checklist

- [ ] Would renaming a class break this?
- [ ] Would adding a parameter invalidate descriptions?
- [ ] Are design decisions explained with rationale?
- [ ] Does Overview explain WHY this exists (not just WHAT)?
- [ ] Are usage steps complete with installation and prerequisites?
- [ ] Can each audience type find their relevant sections quickly?
- [ ] Are paragraphs short and scannable?
