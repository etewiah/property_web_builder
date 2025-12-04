---
name: rails-testing
description: Help with Rails testing including unit tests, integration tests, fixtures, and debugging test failures. Use when working on tests or debugging test issues.
---

# Rails Testing

## Instructions

When helping with Rails testing:

1. **Understand the test structure**
   - Check existing tests in `test/` directory to understand project conventions
   - Look for test patterns in similar files (models, controllers, etc.)
   - Respect the project's test organization and naming conventions

2. **Running tests**
   - Run all tests: `bin/rails test`
   - Run specific file: `bin/rails test test/models/user_test.rb`
   - Run specific test: `bin/rails test test/models/user_test.rb:5` (line number)
   - Run with verbose output: `bin/rails test -v`
   - Use `--fail-fast` to stop on first failure: `bin/rails test --fail-fast`

3. **Test types in Rails**
   - **Models**: Test business logic, validations, associations
   - **Controllers**: Test request/response, status codes, redirects, instance variables
   - **Integration Tests**: Test full workflows across multiple components
   - **Fixtures**: Use for test data setup

4. **Writing effective tests**
   - Use descriptive test names: `test_should_create_valid_user`
   - Test both success and failure cases
   - Keep tests focused and isolated
   - Use fixtures for shared test data
   - Clean up side effects after tests

5. **Debugging test failures**
   - Read error messages carefully - they usually point to the issue
   - Check if test data is set up correctly (fixtures, setup methods)
   - Verify assertions match the actual behavior
   - Use `puts` or `p` to inspect values
   - Check test isolation - tests shouldn't depend on each other

6. **Test database**
   - Rails uses a separate test database
   - Run migrations: `bin/rails db:test:prepare`
   - Check `test/fixtures/` for test data

## Examples

**When user asks: "How do I test this model?"**
→ Create a model test in `test/models/` following existing patterns, test validations and associations

**When user asks: "Why is this test failing?"**
→ Analyze the error, check test data setup, verify assertions, suggest fixes

**When user asks: "Add tests for this controller"**
→ Create controller tests in `test/controllers/`, test CRUD actions and edge cases

**When user asks: "How do I set up test data?"**
→ Suggest fixtures in `test/fixtures/` or setup methods in the test file
