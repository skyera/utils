#include <stdio.h>
#include <stdlib.h>

/**
 * Calculates area of a rectangle.
 * @param width Width of rectangle
 * @param height Height of rectangle
 */
double calculate_area(double width, double height) {
    return width * height;
}

/**
 * Formats and prints user information.
 * @param user_id Unique identifier for the user
 * @param username Name of the user
 * @param score Account score / balance
 * @param is_active Status flag
 */
void print_user_info(int user_id, const char *username, double score, int is_active) {
    printf("User [%d] %s: score=%.2f, active=%d\n", user_id, username, score, is_active);
}

int main(void) {
    // =============================================================
    // TEST 1: Function Signature Help (<Ctrl+k> or typing '(')
    // =============================================================
    // Try typing the arguments below in Insert mode:
    // Press <Ctrl+k> while inside the parentheses:
    double area = calculate_area(12.5, 4.0);
    print_user_info(101, "Alice", 98.5, 1);

    printf("Calculated Area: %.2f\n", area);

    // =============================================================
    // TEST 2: Actual ERROR Detection (Uncomment lines below to test)
    // =============================================================
    // Line below has a missing semicolon (Fatal Syntax ERROR):
    // int x = 42

    // Line below assigns string to int pointer (Fatal Type ERROR):
    // int *ptr = "hello world";

    // Line below uses undeclared identifier (Fatal Scope ERROR):
    // int total = undefined_variable + 10;

    // =============================================================
    // TEST 3: Warning Suppression
    // =============================================================
    // Unused variable (This is a Warning, so it will be hidden inline):
    int unused_var = 100;

    return 0;
}
