---
name: create-readme
description: Create maintainable README files for services and projects. Use when asked to document a service, create a README, or explain a project's architecture.
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
High-level design, component responsibilities, data flow. Use **mermaid diagram** for how components are defined and how they interact with each others.

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
- **Code blocks with syntax highlighting** - Specify language with triple backticks
  
## Content Guidelines

Focus on the following:
- Architectural patterns + rationale
- Component responsibilities (abstract)
- Design decisions with WHY 
- File links in "See Also"
- If project is a library, add produced packages
Avoid:
- Line number reference
- Specific code that might change
- Property/setting names


## Validation Checklist

- [ ] Does the project description explains well what the project is about?
- [ ] Does the architecture section gives the readers a good overview of the service components?
- [ ] Would adding or renaming a class, parameter or config invalidate descriptions?
- [ ] Are design decisions explained with rationale?
- [ ] Does Overview explain WHY this exists (not just WHAT)?
- [ ] Are usage steps complete with installation and prerequisites?
- [ ] Can each audience type find their relevant sections quickly?
- [ ] Are paragraphs short and scannable?
