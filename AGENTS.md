# Agent Instructions

For any issue, feature request, review, or modification task, the agent MUST follow this workflow:

1.  **Research & Think**: Analyze the request (including any review notes), explore the relevant parts of the codebase, and identify the root cause or the optimal design for the change.
2.  **Design & Plan**: Formulate a clear plan of action and test strategy. **ALWAYS show the user the plan/design before making any code changes.**
3.  **Implement**: Perform surgical and idiomatic changes to the codebase directly.
4.  **Verify**: Validate the changes through testing, manual verification, or relevant shell commands to ensure the solution is correct and does not introduce regressions. Double check and verify every fix/solution thoroughly before concluding.

Verification is the only path to finality. Do not assume success. Always double check and verify every fix or solution for correctness.

## Testing Guidelines

When creating a test plan or verifying changes, consider the following:
*   **Edge Cases**: Test invalid inputs and boundary values.
*   **Invariants**: Assert that core logic and state remain consistent.
*   **Error Handling**: Use mocks or stubs to simulate errors and verify recovery.
*   **Performance**: Consider stress testing for performance-critical changes.
*   **Security & Stability**: Use tools like Valgrind or AddressSanitizer to check for memory errors.

## Issue / Problem Workflow

When the user asks about an issue or problem, the agent MUST:

1.  **Explain the problem**: Describe the root cause clearly.
2.  **Propose a solution**: Explain what needs to change and why.
3.  **Show code comparison**: Present a before/after diff so the user can see exactly what changes.
4.  **Approval Mode**:
    *   If the user has indicated **"approve always"**, **"do it"**, **"auto approve"**, or explicitly asks to fix/implement directly: proceed immediately with implementation and verification without asking for confirmation.
    *   Otherwise: wait for user approval before applying changes.

## Commit Workflow

*   **One commit per issue**: Each fix should be its own atomic commit with a descriptive message.
*   **"commit"**: When the user says "commit", create the commit(s) locally. Do NOT push.
*   **"push"**: When the user says "push", push all local commits to the remote repository.
