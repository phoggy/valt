---
layout: default
title: "valt/node"
parent: API Reference
nav_order: 999
---

# valt/node

Node.js / npm utilities.
Use via: require 'valt/node'

## Functions

### requireNodeModules()

Ensure node_modules are installed for a project, setting `${projectName}`NodeHome globally.


*args*

| | |
|---|---|
| `projectName` *(string)* | Name of the project (default: ${currentProjectName}). |
| `envVar` *(string)* | If set and non-empty in the environment, use its value as nodeHome directly. |
{: .args-table}

*example*

```bash
requireNodeModules valt VALT_PDF_DEPS_HOME
# valtNodeHome is now set to the resolved node home path
```

### executeNodeScript()

Runs a Node.js script from the project's node/ directory using the project's
node_modules. If script ends in .js, projectName defaults to $currentProjectName.


*args*

| | |
|---|---|
| `projectName` *(string)* | Name of the project (default: currentProjectName). |
| `script` *(string)* | Script filename relative to projectHome/node/. |
| `...` *(string)* | Additional arguments passed to the script. |
{: .args-table}

*example*

```bash
executeNodeScript valt generate-pdf.js "${htmlFile}" "${outputFile}"
executeNodeScript generate-pdf.js "${htmlFile}" "${outputFile}"
```

