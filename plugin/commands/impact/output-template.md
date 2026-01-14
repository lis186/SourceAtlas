# Impact Analysis Output Template

Complete format specification for impact analysis reports.

---

## For API Impact

```markdown
🗺️ SourceAtlas: Impact
───────────────────────────────
💥 $API_PATH │ [total dependents] dependents

📊 **Impact Summary**:
- Backend files: [count]
- Frontend files: [count]
- Test files: [count]
- **Risk Level**: 🔴/🟡/🟢 [reason]

---

## 1. Backend Layer

### API Definition
- File: [path:line]
- Handler: [function name]
- Request/Response types: [types]

### Response Structure
```[language]
// Current structure from types
interface UserResponse {
  id: string
  role: string  // ⚠️ If changing this
  ...
}
```

---

## 2. Frontend Layer

### API Client/Service
- File: [path:line]
- Wrapper function: [function name]

### Custom Hooks (React)
- `useUser` ([path:line])
  - Used by [count] components
  - Components: [list]

### Direct API Calls
- [component:line] - [usage description]

---

## 3. Component Impact

**High Priority** (Directly affected):
1. [Component A] ([path:line])
   - Usage: [how it uses the API/field]
   - Impact: [what breaks]

2. [Component B] ([path:line])
   - Usage: [description]

**Medium Priority** (Indirectly affected):
3. [Component C] - Uses Hook that wraps API

---

## 4. Field Usage Analysis

**Field: `role`** (⚠️ Changing from string → array)
- Total occurrences: [count]
- Locations:
  1. [file:line] - `if (user.role === 'admin')`
  2. [file:line] - `user.role.toUpperCase()`

**Breaking Change Assessment**:
- All usages assume string type
- Migration required: Yes
- Backward compatibility: Possible with adapter

---

## 5. Test Impact

**Test Files to Update**:
- `user.test.ts` - Mock data structure
- `useUser.test.ts` - Hook logic
- `UserBadge.test.tsx` - Component rendering
- `e2e/user-profile.spec.ts` - E2E scenarios

**Test Coverage Gaps**:
- ⚠️ No tests for [Component X]
- ⚠️ Missing integration tests for [Flow Y]

---

## 6. Migration Checklist

- [ ] Update API response type definition
- [ ] Update [N] API call sites
- [ ] Update [N] components using the field
- [ ] Add backward compatibility layer (if needed)
- [ ] Update [N] test files
- [ ] Test all affected pages manually
- [ ] Update API documentation

**Risk Level**: 🔴 HIGH | 🟡 MEDIUM | 🟢 LOW

💡 **Note**: Time estimation depends on team velocity and complexity. Discuss with your team based on the checklist above.

---

## 7. Language-Specific Deep Analysis

**⚠️ Swift/Objective-C Interop Risks** (iOS Projects Only)

### Critical Issues 🔴

**Nullability Coverage**: [X]% ([N] files missing NS_ASSUME_NONNULL)
- **Impact**: Runtime crashes due to force unwrapping operator (!)
- **Auto-fix**: Run provided sed script to add annotations
- **Priority**: CRITICAL - Fix before making changes

### Medium Risks 🟡

**@objc Exposure**: [N] classes + [M] @objcMembers
- Classes exposing members to Objective-C
- **Risk**: Renaming/removing will break ObjC callers
- **Target file impact**: [Is/Is not] in interop boundary

**Memory Management**: [N] unowned references detected
- **Risk**: Crashes if referenced object is deallocated
- **Recommendation**: Review and convert to `weak` where appropriate

### Architecture Info ℹ️

**UI Framework**: [SwiftUI|UIKit|Hybrid]
- SwiftUI files: [N]
- UIKit files: [M]
- Integration points: [N] UIViewRepresentable, [M] UIHostingController

**Bridging Headers**: [N] found
- Largest imports: [N] headers
- Circular dependencies: [None|Detected]

💡 **Full Swift Analysis**: Run `/sourceatlas:impact [target].m` to see complete 7-section analysis

---

## 8. Recommendations

1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]
```

---

## For Model Impact

```markdown
🗺️ SourceAtlas: Impact
───────────────────────────────
💥 $MODEL_NAME │ [total dependents] dependents

📊 **Impact Summary**:
- Controllers: [count]
- Services: [count]
- Associated models: [count]
- Test files: [count]
- **Risk Level**: 🔴/🟡/🟢 [reason]

---

## 1. Model Definition
- File: [path]
- Table: [table_name]
- Key fields: [list]

### Associations
- `belongs_to :organization`
- `has_many :orders`
- `has_one :profile`

### Validations
- `validates :email, presence: true, uniqueness: true`
- [other validations]

---

## 2. Direct Dependencies

### Controllers ([count])
1. `UsersController#create` ([path:line])
   - Creates new User instances
   - Validation-dependent

2. `Admin::UsersController#update` ([path:line])
   - Updates User attributes

### Services ([count])
1. `UserImportService` ([path:line])
   - Bulk creates Users
   - ⚠️ No validation error handling

---

## 3. Cascade Impact

### Associated Models
1. **Order model** ([path:line])
   - `belongs_to :user, validates: true`
   - **Impact**: Will fail if User validation fails

2. **Notification model** ([path:line])
   - Assumes `user.email` is always valid
   - **Risk**: May send to invalid emails

---

## 4. Test Coverage

**Existing Tests**:
- `users_controller_spec.rb` - Basic CRUD
- `user_spec.rb` - Model validations

**Coverage Gaps**:
- ⚠️ UserImportService has no validation failure tests
- ⚠️ Order-User association not tested with invalid user

---

## 5. Migration Checklist

- [ ] Review validation rules for edge cases
- [ ] Add tests for validation failures
- [ ] Update controllers to handle new validation errors
- [ ] Check associated models for assumptions
- [ ] Add integration tests for cascade effects
- [ ] Update API documentation

**Risk Level**: 🔴 HIGH | 🟡 MEDIUM | 🟢 LOW

💡 **Note**: Time estimation depends on team velocity and complexity. Discuss with your team based on the checklist above.

---

## 6. Language-Specific Deep Analysis

*(Same format as API Impact - include if iOS/Swift project)*
```

---

## Field Descriptions

### Impact Summary
- **Backend/Frontend/Test files**: Count of impacted files by category
- **Risk Level**: Overall assessment based on dependency count, criticality, and test coverage

### Component Impact Sections
- **High Priority**: Components directly using the target (will break immediately)
- **Medium Priority**: Components indirectly using target (may break)

### Field Usage Analysis
- **Total occurrences**: Exact count from grep
- **Locations**: File:line references with code snippet
- **Breaking Change Assessment**: Migration complexity evaluation

### Test Impact
- **Test Files to Update**: Specific test files needing changes
- **Coverage Gaps**: Missing tests that should be added

### Migration Checklist
- Concrete, actionable steps
- Each item should be measurable
- Include counts where known ([N] files)

### Language-Specific Deep Analysis
- Only include for iOS/Swift projects
- Focus on interop risks and architecture
- Provide actionable recommendations
