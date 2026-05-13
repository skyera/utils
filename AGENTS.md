# Agent Instructions

For any issue, feature request, or modification task, the agent MUST follow this workflow:

1.  **Research & Think**: Analyze the request, explore the relevant parts of the codebase, and identify the root cause or the optimal design for the change.
2.  **Design & Plan**: Create a detailed plan of action. This plan must be presented to the user for approval before any files are modified.
3.  **Implement**: Once the plan is approved, perform surgical and idiomatic changes to the codebase.
4.  **Verify**: Validate the changes through testing, manual verification, or relevant shell commands to ensure the solution is correct and does not introduce regressions.

Verification is the only path to finality. Do not assume success.
