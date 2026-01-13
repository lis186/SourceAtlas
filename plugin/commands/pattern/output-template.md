# Pattern Learning Output Template

Complete Markdown format specification for pattern analysis reports.

---

## Header Format

```markdown
🗺️ SourceAtlas: Pattern
───────────────────────────────
🧩 [Pattern Name] │ [N] files found
```

---

## Section 1: Overview

2-3 sentence summary of how this codebase implements the pattern.

```markdown
## Overview

This codebase implements [pattern] using [approach/framework]. The pattern follows [architectural style] with [key characteristics]. [Additional context about why this approach was chosen or how it differs from standard implementations].
```

**Example:**
```markdown
## Overview

This codebase implements API endpoints using Express.js controllers with a 3-layer architecture: Controller → Service → Repository. All endpoints follow RESTful conventions and use middleware for auth, validation, and error handling. The pattern emphasizes separation of concerns with clear boundaries between HTTP handling, business logic, and data access.
```

---

## Section 2: Best Examples

Show 2-3 concrete examples from the codebase.

```markdown
## Best Examples

### 1. [File Path]:[line]

**Purpose**: [What this example demonstrates - 1 sentence]

**Key Code**:
```[language]
[Relevant code snippet - 5-15 lines showing core pattern]
```

**Key Points**:
- [Important observation 1]
- [Important observation 2]
- [Important observation 3]

---

### 2. [File Path]:[line]

[Same structure as Example 1]

---

### 3. [File Path]:[line] (Optional)

[Only include if it adds significant new insight]
```

**Example:**
```markdown
## Best Examples

### 1. src/api/controllers/UserController.ts:45

**Purpose**: Demonstrates RESTful endpoint with authentication middleware

**Key Code**:
```typescript
@Controller('/api/users')
export class UserController extends BaseController {
  constructor(private userService: UserService) {
    super();
  }

  @Get('/:id')
  @UseGuards(AuthGuard)
  async getUser(@Param('id') id: string): Promise<UserResponse> {
    const user = await this.userService.findById(id);
    return this.formatResponse(user);
  }
}
```

**Key Points**:
- Uses decorator-based routing (@Controller, @Get)
- Extends BaseController for common functionality
- Injects UserService via constructor
- Auth guard applied via @UseGuards decorator
- Async/await pattern for service calls
```

---

## Section 3: Key Conventions

Observable patterns extracted from examples.

```markdown
## Key Conventions

Based on the examples above, this codebase follows these conventions:

- **[Convention Category 1]** - [Specific rule/pattern]
  - Location: [where to find examples]
  - Example: [concrete example]

- **[Convention Category 2]** - [Specific rule/pattern]
  - Location: [where to find examples]
  - Example: [concrete example]

- **[Convention Category 3]** - [Specific rule/pattern]
  - Location: [where to find examples]
  - Example: [concrete example]
```

**Example:**
```markdown
## Key Conventions

Based on the examples above, this codebase follows these conventions:

- **File Structure** - Controllers → Services → Repositories pattern
  - Location: src/api/controllers/, src/services/, src/repositories/
  - Example: UserController calls UserService calls UserRepository

- **Naming** - PascalCase for classes, camelCase for methods
  - Location: All TypeScript files
  - Example: UserController.getUser(), OrderService.createOrder()

- **Dependency Injection** - Constructor injection with private properties
  - Location: All service and controller classes
  - Example: constructor(private userService: UserService)

- **Error Handling** - Custom exception classes + global error handler
  - Location: src/exceptions/, src/middleware/errorHandler.ts
  - Example: throw new NotFoundException('User not found')
```

---

## Section 4: Testing Pattern

How this pattern is tested in the codebase.

```markdown
## Testing Pattern

**Test Location:** [path/to/tests/ or "No tests found"]

**Testing Approach:**
[Describe framework, structure, key testing strategies - 2-3 sentences]

**Example Test File:** [path/to/example.test.ext] (if available)

**Key Test Patterns:**
- [Test pattern 1]
- [Test pattern 2]
- [Test pattern 3]
```

**Example:**
```markdown
## Testing Pattern

**Test Location:** tests/integration/api/

**Testing Approach:**
Uses Jest + Supertest for API integration tests. Tests follow Arrange-Act-Assert pattern with separate test database setup. Each test file mirrors the controller structure and tests both happy paths and error cases.

**Example Test File:** tests/integration/api/users.test.ts

**Key Test Patterns:**
- Mock external services using jest.mock()
- Test database seeded in beforeEach, cleaned in afterEach
- Use supertest for HTTP request testing
- Separate unit tests for services in tests/unit/services/
```

---

## Section 5: Common Pitfalls to Avoid

Based on code analysis and anti-patterns observed.

```markdown
## Common Pitfalls to Avoid

Based on code analysis and observations:

1. **[Pitfall 1]** - [What to avoid]
   - Why: [Reason/consequence]
   - Instead: [Correct approach]

2. **[Pitfall 2]** - [What to avoid]
   - Why: [Reason/consequence]
   - Instead: [Correct approach]

3. **[Pitfall 3]** - [What to avoid]
   - Why: [Reason/consequence]
   - Instead: [Correct approach]
```

**Example:**
```markdown
## Common Pitfalls to Avoid

Based on code analysis and observations:

1. **Don't put business logic in controllers**
   - Why: Controllers should only handle HTTP concerns (request parsing, response formatting)
   - Instead: Move all business logic to service layer (UserService, OrderService, etc.)

2. **Don't call repositories directly from controllers**
   - Why: Breaks the layered architecture and makes testing harder
   - Instead: Always go through service layer: Controller → Service → Repository

3. **Don't forget input validation**
   - Why: API is public-facing, all user input must be validated
   - Instead: Use class-validator decorators on DTOs or middleware validators
```

---

## Section 6: Step-by-Step Implementation Guide

Concrete steps to implement similar functionality.

```markdown
## Step-by-Step Implementation Guide

To implement [similar functionality] following this codebase's pattern:

1. **[Step 1 Title]** - [Action with specifics]
   - File: [where to create/modify]
   - Code structure: [what to include]
   - Example: [concrete code snippet or reference]

2. **[Step 2 Title]** - [Action with specifics]
   - File: [where to create/modify]
   - Code structure: [what to include]
   - Example: [concrete code snippet or reference]

... (as many steps as needed, typically 4-7 steps)
```

**Example:**
```markdown
## Step-by-Step Implementation Guide

To implement a new API endpoint following this codebase's pattern:

1. **Create Route Definition**
   - File: src/routes/[resource].ts
   - Code structure: Import controller, define routes
   - Example:
     ```typescript
     import { ProductController } from '../controllers/ProductController';
     router.get('/api/products', controller.list);
     router.post('/api/products', controller.create);
     ```

2. **Create Controller Class**
   - File: src/controllers/[Resource]Controller.ts
   - Code structure: Extend BaseController, inject service
   - Example:
     ```typescript
     @Controller('/api/products')
     export class ProductController extends BaseController {
       constructor(private productService: ProductService) {
         super();
       }
     }
     ```

3. **Implement Controller Methods**
   - File: Same as above
   - Code structure: Use decorators, call service methods
   - Example:
     ```typescript
     @Get('/')
     @UseGuards(AuthGuard)
     async list(): Promise<ProductResponse[]> {
       const products = await this.productService.findAll();
       return this.formatList(products);
     }
     ```

4. **Create Service Class**
   - File: src/services/[Resource]Service.ts
   - Code structure: Business logic, inject repository
   - Example:
     ```typescript
     export class ProductService {
       constructor(private productRepo: ProductRepository) {}

       async findAll(): Promise<Product[]> {
         return this.productRepo.findAll({ active: true });
       }
     }
     ```

5. **Create Repository Class** (if database access needed)
   - File: src/repositories/[Resource]Repository.ts
   - Code structure: Extend BaseRepository, use ORM
   - Example:
     ```typescript
     export class ProductRepository extends BaseRepository<Product> {
       async findAll(filters: any): Promise<Product[]> {
         return this.model.findAll({ where: filters });
       }
     }
     ```

6. **Add Integration Tests**
   - File: tests/integration/api/[resource].test.ts
   - Code structure: Test happy path + error cases
   - Example:
     ```typescript
     describe('GET /api/products', () => {
       it('returns list of products', async () => {
         const response = await request(app).get('/api/products');
         expect(response.status).toBe(200);
         expect(response.body).toHaveLength(3);
       });
     });
     ```
```

---

## Section 7: Related Patterns (Optional)

Patterns commonly used together.

```markdown
## Related Patterns

[If applicable, mention related patterns in this codebase]

- **[Related Pattern 1]** - [Brief explanation of relationship]
- **[Related Pattern 2]** - [Brief explanation of relationship]
```

**Example:**
```markdown
## Related Patterns

These patterns are commonly used with API endpoints in this codebase:

- **Middleware Pattern** - Auth, validation, and error handling middleware wrap all endpoints
- **DTO Pattern** - Data Transfer Objects validate and transform request/response data
- **Repository Pattern** - All database access abstracted behind repository interfaces
```

---

## Section 8: Recommended Next (Optional)

Dynamic suggestions based on findings.

```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:[command] "[parameter]"` | [Reason based on specific findings] |
| 2 | `/sourceatlas:[command] "[parameter]"` | [Reason based on specific findings] |

💡 Enter a number (e.g., `1`) or copy the command to execute
```

**Rules:**
- Only include if there are clear next steps
- Use actual discovered information (file names, patterns found)
- Limit to 1-2 suggestions
- Reference specific findings in Purpose column

---

## Section 9: Additional Notes (Optional)

Project-specific quirks or important context.

```markdown
## Additional Notes

[Any project-specific quirks, gotchas, or important context that doesn't fit above]

- [Note 1]
- [Note 2]
```

---

## Footer Format

```markdown
───────────────────────────────
🗺️ v2.12.0 │ Constitution v1.0

✅ Verified: [N] file paths, [M] directories, [K] code snippets

💾 Saved to .sourceatlas/patterns/[pattern-name].md
```

---

## Complete Example

```markdown
🗺️ SourceAtlas: Pattern
───────────────────────────────
🧩 API Endpoint │ 12 files found

## Overview

This codebase implements API endpoints using Express.js controllers with a 3-layer architecture: Controller → Service → Repository. All endpoints follow RESTful conventions and use middleware for auth, validation, and error handling. The pattern emphasizes separation of concerns with clear boundaries between HTTP handling, business logic, and data access.

---

## Best Examples

### 1. src/api/controllers/UserController.ts:45

**Purpose**: Demonstrates RESTful endpoint with authentication middleware

**Key Code**:
```typescript
@Controller('/api/users')
export class UserController extends BaseController {
  constructor(private userService: UserService) {
    super();
  }

  @Get('/:id')
  @UseGuards(AuthGuard)
  async getUser(@Param('id') id: string): Promise<UserResponse> {
    const user = await this.userService.findById(id);
    return this.formatResponse(user);
  }
}
```

**Key Points**:
- Uses decorator-based routing (@Controller, @Get)
- Extends BaseController for common functionality
- Injects UserService via constructor
- Auth guard applied via @UseGuards decorator
- Async/await pattern for service calls

---

[... rest of sections ...]

───────────────────────────────
🗺️ v2.12.0 │ Constitution v1.0

✅ Verified: 3 file paths, 4 directories, 5 code snippets

💾 Saved to .sourceatlas/patterns/api-endpoint.md
```
