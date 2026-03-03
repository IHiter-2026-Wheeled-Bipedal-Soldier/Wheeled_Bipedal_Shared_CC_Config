---
name: name-symbol
description: Extract all variables from the control theory description documents and generate a standard naming document in accordance with the project's naming conventions. Accepts inputs in the form of documents, textual descriptions, images, etc.
disable-model-invocation: true
argument-hint: <theory description file path or description text>
allowed-tools: Read, Grep, Glob, Bash, Write
---

## Trigger Examples

```
/name-symbol docs/VMC_derivation.pdf
/name-symbol docs/LQR_theory.md docs/leg_model.md
/name-symbol "five-linkage model with leg length l0, swing angle theta, hip angles phi1/phi2"
```

## References

- Naming rules: [naming_rules.md](naming_rules.md)
- Output template: [template.md](template.md)
- Expected sample: [examples/sample.md](examples/sample.md)
- Validation script: [scripts/validate.sh](scripts/validate.sh)

## Execution Flow

### Step 1: Understand Theory Context

Read all `$ARGUMENTS` inputs (.md/.txt/.pdf/.c/.h) and user text/image context.
Extract model and control entities:

- system model (five-linkage, inverted pendulum, VMC, etc.)
- controller type (PID, LQR, Kalman, etc.)
- physical quantities, state variables, controller variables, constants, intermediates

### Step 2: Classify Variables

Classify extracted variables into:

- physical quantities
- control variables
- state vector items
- parameters/constants
- intermediate calculations

### Step 3: Apply Naming Rules

Load [naming_rules.md](naming_rules.md), then build names with:

1. scope prefix (`G`/`S`/local)
2. type prefix (`F`/`ST`/`EM`/none)
3. module prefix (`CH`/`GB`/...)
4. descriptive suffix based on project abbreviations

### Step 4: Generate Output File

Fill [template.md](template.md).

Output path rules:

1. Use `References/SymbolName/` under current workspace.
2. Create directory if missing.
3. Use concise topic file name, e.g. `LQR-state-naming.md`.

Optional validation:

```bash
bash scripts/validate.sh References/SymbolName/<file-name>.md
```

### Step 5: Ask for User Approval

- Report output file path.
- Allow user edits on naming proposals.
- Do not modify source code automatically.

## Constraints

- Naming only; no logic implementation.
- Preserve original math symbols as notes where useful.
- Deduplicate same physical quantity names across contexts.
- Always output under `References/SymbolName/` in current workspace.

