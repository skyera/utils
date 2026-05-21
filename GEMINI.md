# Agent Instructions

For any issue, feature request, review, or modification task, the agent MUST follow this workflow:

1.  **Research & Think**: Analyze the request (including any review notes), explore the relevant parts of the codebase, and identify the root cause or the optimal design for the change.
2.  **Design & Plan**: Create a detailed plan of action. This plan must include a clear test plan outlining how the changes will be validated, tested, and verified. The complete plan must be presented to the user for approval before any files are modified. If the plan is simple, there is no need to write it to an implementation plan file; simply print it on the screen and ask for approval.
3.  **Implement**: Once the plan is approved, perform surgical and idiomatic changes to the codebase.
4.  **Verify**: Validate the changes through testing, manual verification, or relevant shell commands to ensure the solution is correct and does not introduce regressions.

Verification is the only path to finality. Do not assume success.

## Handling Multiple Issues
When presented with multiple issues, bugs, or feature requests at once, you MUST prepend the standard workflow with an explicit triage and selection phase:
1. **Triage & Prioritize**: List all identified issues, grouped by estimated priority (High, Medium, Low).
2. **Suggest Fixes**: For each issue in the list, provide a brief (1-2 sentence) description of the likely root cause and proposed fix.
3. **User Selection**: Ask the user to select which specific issue(s) they want to address first. Wait for their selection before proceeding to the "Design & Plan" phase for the chosen items.

## Testing Guidelines

When creating a test plan or verifying changes, consider the following:
*   **Edge Cases**: Test invalid inputs and boundary values.
*   **Invariants**: Assert that core logic and state remain consistent.
*   **Error Handling**: Use mocks or stubs to simulate errors and verify recovery.
*   **Performance**: Consider stress testing for performance-critical changes.
*   **Security & Stability**: Use tools like Valgrind or AddressSanitizer to check for memory errors.
