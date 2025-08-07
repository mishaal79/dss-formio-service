# Testing Framework

This directory contains Terraform native tests using `.tftest.hcl` files, following the Qrius GCP methodology for testing infrastructure.

## Test Structure

```
tests/
├── unit/                   # Module unit tests
│   ├── cloud_run_module.tftest.hcl
│   └── postgresql_module.tftest.hcl
├── integration/            # Environment integration tests
│   ├── dev_environment.tftest.hcl
│   └── prod_environment.tftest.hcl
└── README.md              # This file
```

## Running Tests

### All Tests
```bash
terraform test
```

### Specific Test File
```bash
terraform test tests/unit/cloud_run_module.tftest.hcl
```

### Verbose Output
```bash
terraform test -verbose
```

## Test Types

### Unit Tests (`tests/unit/`)
- Test individual modules in isolation
- Use mock values for dependencies
- Focus on module logic and resource configuration
- Fast execution, no real resources created

### Integration Tests (`tests/integration/`)
- Test complete environment configurations
- Validate module interactions
- Test shared infrastructure integration
- Use `plan` command to avoid creating real resources

## Testing Principles

1. **Use Terraform Native Testing**: Leverage `terraform test` command with `.tftest.hcl` files
2. **No Custom Scripts**: Avoid bash scripts for testing, use Terraform's built-in capabilities
3. **Plan-Only Testing**: Use `command = plan` to test without creating resources
4. **Meaningful Assertions**: Test business logic, naming conventions, and security configurations
5. **Environment-Specific**: Test different configurations for dev/staging/prod

## Quality Gates Integration

Tests are integrated with pre-commit hooks:
- `terraform test` runs as part of the quality pipeline
- Tests validate before code reaches CI/CD
- Manual execution for cost-sensitive integration tests

## Writing New Tests

1. Create `.tftest.hcl` files in appropriate directory
2. Use `run` blocks to define test scenarios
3. Use `assert` blocks to validate expected outcomes
4. Test both positive and negative scenarios
5. Include meaningful error messages

Example test structure:
```hcl
run "test_name" {
  command = plan
  
  module {
    source = "../../path/to/module"
  }
  
  variables {
    # Test variables
  }
  
  assert {
    condition     = # test condition
    error_message = "Descriptive error message"
  }
}
```