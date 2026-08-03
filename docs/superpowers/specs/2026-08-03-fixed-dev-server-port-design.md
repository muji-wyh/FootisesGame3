# Fixed Development Server Port

## Goal

Use port `8090` for every local web development server invocation and documented URL.

## Design

- Set `tools\serve.py` to a fixed `PORT = 8090`.
- Remove its command-line port override and unused `sys` import.
- Update the server docstring, `README.md`, and `.github\copilot-instructions.md` so commands and URLs consistently use port `8090`.
- Keep existing socket binding errors unchanged so port conflicts remain visible.

## Validation

Run the server without arguments, request `http://localhost:8090/`, and confirm no development-server references use the legacy port.
