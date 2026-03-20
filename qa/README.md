# Medoru QA Testing Suite

End-to-end testing for Medoru using [Playwright](https://playwright.dev/).

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd qa
npm install
npx playwright install  # Install browser binaries
```

### 2. Setup QA Database

```bash
# Create QA database
cd ..
mix ecto.create -c qa.exs
MIX_ENV=qa mix ecto.migrate

# Seed test users
MIX_ENV=qa mix run priv/repo/qa_seeds.exs
```

### 3. Run Tests

```bash
cd qa

# Run all tests
npm test

# Run with UI mode (great for debugging)
npm run test:ui

# Run specific test file
npx playwright test scenarios/auth.spec.ts

# Run smoke tests only (fast!)
npx playwright test scenarios/smoke-test.spec.ts --project=chromium

# Run full classroom workflow
npx playwright test scenarios/full-classroom-workflow.spec.ts --headed

# Run tests matching pattern
npx playwright test --grep "student"

# Run in headed mode (see the browser)
npm run test:headed
```

## 📁 Project Structure

```
qa/
├── scenarios/                    # Test files (specs)
│   ├── auth.setup.ts             # Authentication setup (runs first)
│   ├── smoke-test.spec.ts        # ⚡ Quick smoke tests (~30s)
│   ├── _template.spec.ts         # 📋 Template for new scenarios
│   ├── auth.spec.ts              # Login/logout tests
│   ├── dashboard.spec.ts         # Dashboard features
│   ├── daily-test.spec.ts        # Daily test flow
│   ├── lessons.spec.ts           # Lesson browsing/study
│   ├── teacher-classrooms.spec.ts # Teacher classroom management
│   └── full-classroom-workflow.spec.ts  # 🎭 Complete E2E workflow
├── helpers/             # Reusable test helpers
│   ├── auth.ts          # Login/logout utilities
│   ├── navigation.ts    # Page navigation
│   ├── assertions.ts    # Custom assertions
│   └── index.ts         # Re-exports
├── fixtures/            # Test data
│   └── users.ts         # Test user definitions
├── playwright.config.ts # Playwright configuration
└── package.json
```

## 👥 Test Users

The QA database comes pre-seeded with 18 test users:

| Email | Type | Description |
|-------|------|-------------|
| `admin@qa.test` | admin | Full admin access |
| `admin2@qa.test` | admin | Secondary admin |
| `teacher@qa.test` | teacher | Teacher with classrooms |
| `teacher2@qa.test` | teacher | Second teacher |
| `teachernoclasses@qa.test` | teacher | Teacher without classes |
| `student@qa.test` | student | Regular student |
| `studentnew@qa.test` | student | New student (3 lessons) |
| `studentadvanced@qa.test` | student | Advanced (50 lessons, 15-day streak) |
| `studentinactive@qa.test` | student | Inactive (broken streak) |
| `classroom.student1@qa.test` | student | For classroom testing |
| `classroom.student2-5@qa.test` | student | More classroom students |
| `user.longname@qa.test` | student | Very long name (UI testing) |
| `user.special+chars@qa.test` | student | Special email chars |
| `user.unicode@qa.test` | student | Unicode/Japanese name |

## 📋 Included Scenarios

| Scenario | Description | Duration |
|----------|-------------|----------|
| `smoke-test.spec.ts` | Quick health check of all major features | ~30s |
| `auth.spec.ts` | Login/logout, access control | ~1m |
| `dashboard.spec.ts` | Dashboard features for different user types | ~1m |
| `daily-test.spec.ts` | Daily test completion flow | ~2m |
| `lessons.spec.ts` | Lesson browsing and study | ~1m |
| `teacher-classrooms.spec.ts` | Teacher classroom management | ~2m |
| `full-classroom-workflow.spec.ts` | **Complete E2E**: Teacher creates classroom → creates lesson → Student joins → Takes lesson → Takes test → Teacher views results | ~5m |

### Full Classroom Workflow

The `full-classroom-workflow.spec.ts` demonstrates the complete platform flow:

```
Teacher: Create Classroom ──► Create Custom Lesson ──► Publish Lesson
                                    │
                                    ▼
Student:  Join with Code ◄── Approved ◄── Apply to Classroom
                                    │
                                    ▼
          Take Lesson ◄─── Study Custom Lesson
                                    │
                                    ▼
          View Results ◄── Teacher Publishes Test ◄── Create Test
```

Run this comprehensive test:
```bash
npx playwright test scenarios/full-classroom-workflow.spec.ts --headed
```

## 🎭 Writing Scenarios

### Basic Test Structure

```typescript
import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

test.describe('Feature Name', () => {
  test('description of what is being tested', async ({ page }) => {
    // Login as a test user
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);

    // Navigate to a page
    await navigateTo(page, 'dashboard');

    // Make assertions
    await expect(page.locator('h1')).toContainText('Dashboard');
  });
});
```

### Using Pre-Authenticated Sessions

For tests that need to start already logged in:

```typescript
import { test, expect } from '@playwright/test';
import { navigateTo } from '../helpers';

// Use pre-authenticated session
test.use({ storageState: 'playwright/.auth/teacher.json' });

test.describe('Teacher Features', () => {
  test('teacher can view classrooms', async ({ page }) => {
    // Already logged in as teacher
    await navigateTo(page, 'teacherClassrooms');
    await expect(page.locator('h1')).toContainText('Classrooms');
  });
});
```

### Available Helpers

#### Authentication
```typescript
const auth = createAuthHelper(page);
await auth.login(TEST_USERS.student);      // API login (fast)
await auth.loginViaUI(TEST_USERS.student); // UI login (tests flow)
await auth.logout();
const isAuth = await auth.isAuthenticated();
```

#### Navigation
```typescript
await navigateTo(page, 'dashboard');       // Named route
await navigateTo(page, '/custom/path');    // Custom path
await goToLesson(page, 123);               // Specific helpers
await goToClassroom(page, 'abc-123');
```

#### Assertions
```typescript
await expectHeading(page, 'Dashboard');
await expectFlashMessage(page, 'Success!', 'success');
await expectAuthenticated(page, 'Student Name');
await expectTestIdVisible(page, 'user-menu');
```

## 🔧 Configuration

### Playwright Config (`playwright.config.ts`)

Key settings:

```typescript
{
  baseURL: 'http://localhost:4001',  // QA server URL
  workers: process.env.CI ? 1 : undefined,  // Parallel workers
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
    { name: 'Mobile Chrome', use: { ...devices['Pixel 5'] } },
  ],
  webServer: {
    command: 'cd .. && MIX_ENV=qa mix phx.server',
    url: 'http://localhost:4001/qa/health',
  }
}
```

### QA Environment (`config/qa.exs`)

- **Port**: 4001 (separate from dev on 4000)
- **Database**: `medoru_qa`
- **OAuth**: Disabled, uses bypass

## 🛠️ Commands

| Command | Description |
|---------|-------------|
| `npm test` | Run all tests |
| `npm run test:ui` | Open Playwright UI mode |
| `npm run test:debug` | Debug mode with step-through |
| `npm run test:headed` | Run with visible browser |
| `npm run test:chrome` | Run only in Chrome |
| `npm run show-report` | View HTML test report |

### Running Specific Scenarios

```bash
# Run only smoke tests (quick validation)
npx playwright test scenarios/smoke-test.spec.ts

# Run full E2E workflow
npx playwright test scenarios/full-classroom-workflow.spec.ts

# Run specific step in workflow (e.g., only student tests)
npx playwright test --grep "Step 6"

# Run tests for specific user type
npx playwright test --grep "Teacher"

# Run with specific browser
npx playwright test --project=chromium
npx playwright test --project=firefox
npx playwright test --project="Mobile Chrome"
```

## 🐛 Debugging Tips

### 1. Use UI Mode

```bash
npm run test:ui
```

Great for:
- Seeing what the browser is doing
- Time-travel debugging
- Inspecting DOM at each step

### 2. Add Debug Points

```typescript
test('example', async ({ page }) => {
  await page.pause();  // Execution stops here
  // ... rest of test
});
```

### 3. View Trace

Tests automatically capture traces on failure:

```bash
npx playwright show-trace test-results/trace.zip
```

### 4. Screenshot on Failure

Already configured in `playwright.config.ts`:

```typescript
screenshot: 'only-on-failure',
video: 'on-first-retry',
```

## 📝 Defining New Scenarios

1. **Create a new file** in `scenarios/`:
   ```bash
   touch scenarios/my-feature.spec.ts
   ```

2. **Write the test**:
   ```typescript
   import { test, expect } from '@playwright/test';
   import { TEST_USERS, createAuthHelper } from '../helpers';

   test.describe('My Feature', () => {
     test('should work', async ({ page }) => {
       const auth = createAuthHelper(page);
       await auth.login(TEST_USERS.student);

       // Your test steps here
     });
   });
   ```

3. **Run it**:
   ```bash
   npx playwright test scenarios/my-feature.spec.ts --headed
   ```

## 🔐 QA Bypass API

For programmatic access in tests:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/qa/bypass` | GET | Web UI for login |
| `/qa/bypass/api/login` | POST | Login as user `{email: "..."}` |
| `/qa/bypass/api/users` | GET | List all test users |
| `/qa/health` | GET | Server health check |

## 🔄 CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: QA Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.17'
          otp-version: '27'
      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - run: mix deps.get
      - run: mix ecto.create -c qa.exs
      - run: MIX_ENV=qa mix ecto.migrate
      - run: MIX_ENV=qa mix run priv/repo/qa_seeds.exs

      - run: cd qa && npm install
      - run: cd qa && npx playwright install --with-deps
      - run: cd qa && npm test
```

## 🤝 Best Practices

1. **Use test IDs**: Add `data-testid` attributes to key elements
2. **Independent tests**: Each test should be able to run alone
3. **Clean state**: Use fresh auth for each test or use setup projects
4. **Descriptive names**: Test names should explain what they verify
5. **Retry flaky tests**: Playwright retries are configured for CI

## 📚 Resources

- [Playwright Docs](https://playwright.dev/docs/intro)
- [Best Practices](https://playwright.dev/docs/best-practices)
- [Selectors Guide](https://playwright.dev/docs/selectors)
- [Assertions](https://playwright.dev/docs/test-assertions)
