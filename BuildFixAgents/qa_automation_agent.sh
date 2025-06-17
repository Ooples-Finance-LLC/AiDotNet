#!/bin/bash
# QA Automation Agent - Creates and runs automated tests using Playwright and other frameworks
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QA_STATE="$SCRIPT_DIR/state/qa_automation"
mkdir -p "$QA_STATE/tests" "$QA_STATE/reports" "$QA_STATE/configs"

# Source logging if available
if [[ -f "$SCRIPT_DIR/enhanced_logging_system.sh" ]]; then
    source "$SCRIPT_DIR/enhanced_logging_system.sh"
else
    log_event() { echo "[$1] $2: $3"; }
fi

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║      QA Automation Agent v1.0          ║${NC}"
    echo -e "${BOLD}${RED}╚════════════════════════════════════════╝${NC}"
}

# Initialize test framework
initialize_framework() {
    local framework="${1:-playwright}"
    local output_dir="$QA_STATE/configs"
    
    log_event "INFO" "QA_AUTOMATION" "Initializing $framework test framework"
    
    case "$framework" in
        playwright)
            initialize_playwright "$output_dir"
            ;;
        cypress)
            initialize_cypress "$output_dir"
            ;;
        selenium)
            initialize_selenium "$output_dir"
            ;;
        *)
            log_event "ERROR" "QA_AUTOMATION" "Unknown framework: $framework"
            return 1
            ;;
    esac
}

# Initialize Playwright
initialize_playwright() {
    local output_dir="$1"
    
    # Package.json for Playwright
    cat > "$output_dir/package.json" << 'EOF'
{
  "name": "qa-automation-tests",
  "version": "1.0.0",
  "description": "Automated tests using Playwright",
  "scripts": {
    "test": "playwright test",
    "test:headed": "playwright test --headed",
    "test:debug": "playwright test --debug",
    "test:ui": "playwright test --ui",
    "test:report": "playwright show-report",
    "test:codegen": "playwright codegen",
    "test:mobile": "playwright test --project=mobile",
    "test:api": "playwright test tests/api/",
    "test:e2e": "playwright test tests/e2e/",
    "test:smoke": "playwright test --grep @smoke",
    "test:regression": "playwright test --grep @regression"
  },
  "devDependencies": {
    "@playwright/test": "^1.40.0",
    "@types/node": "^20.0.0",
    "dotenv": "^16.3.1",
    "faker": "^6.6.6",
    "typescript": "^5.3.0"
  }
}
EOF

    # Playwright configuration
    cat > "$output_dir/playwright.config.ts" << 'EOF'
import { defineConfig, devices } from '@playwright/test';
import dotenv from 'dotenv';

dotenv.config();

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
    ['line']
  ],
  
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 15000,
    navigationTimeout: 30000,
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile',
      use: { ...devices['iPhone 13'] },
    },
    {
      name: 'tablet',
      use: { ...devices['iPad Pro'] },
    },
  ],

  webServer: {
    command: 'npm run start',
    port: 3000,
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});
EOF

    # TypeScript configuration
    cat > "$output_dir/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020", "dom"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "noEmit": true,
    "types": ["@playwright/test"]
  },
  "include": ["**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

    # Environment template
    cat > "$output_dir/.env.template" << 'EOF'
# Test Environment Configuration
BASE_URL=http://localhost:3000
API_URL=http://localhost:3000/api

# Test User Credentials
TEST_USER_EMAIL=test@example.com
TEST_USER_PASSWORD=TestPass123!
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=AdminPass123!

# Test Configuration
HEADLESS=true
SLOW_MO=0
TIMEOUT=30000
RETRIES=2

# External Services
MAILHOG_URL=http://localhost:8025
DATABASE_URL=postgresql://test:test@localhost:5432/test_db
EOF
    
    log_event "SUCCESS" "QA_AUTOMATION" "Playwright initialized"
}

# Generate E2E test suite
generate_e2e_tests() {
    local feature="${1:-authentication}"
    local output_dir="$QA_STATE/tests/e2e"
    mkdir -p "$output_dir"
    
    log_event "INFO" "QA_AUTOMATION" "Generating E2E tests for $feature"
    
    case "$feature" in
        authentication)
            generate_auth_tests "$output_dir"
            ;;
        dashboard)
            generate_dashboard_tests "$output_dir"
            ;;
        api)
            generate_api_tests "$output_dir"
            ;;
        *)
            generate_generic_tests "$output_dir" "$feature"
            ;;
    esac
}

# Generate authentication tests
generate_auth_tests() {
    local output_dir="$1"
    
    # Page Object Model
    mkdir -p "$output_dir/pages"
    cat > "$output_dir/pages/auth.page.ts" << 'EOF'
import { Page, Locator } from '@playwright/test';

export class AuthPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;
  readonly successMessage: Locator;
  readonly forgotPasswordLink: Locator;
  readonly signUpLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.locator('input[name="email"]');
    this.passwordInput = page.locator('input[name="password"]');
    this.submitButton = page.locator('button[type="submit"]');
    this.errorMessage = page.locator('.error-message');
    this.successMessage = page.locator('.success-message');
    this.forgotPasswordLink = page.locator('a:has-text("Forgot Password")');
    this.signUpLink = page.locator('a:has-text("Sign Up")');
  }

  async goto() {
    await this.page.goto('/login');
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectError(message: string) {
    await this.errorMessage.waitFor({ state: 'visible' });
    await this.page.waitForFunction(
      (msg) => document.querySelector('.error-message')?.textContent?.includes(msg),
      message
    );
  }

  async expectSuccess() {
    await this.page.waitForURL(/dashboard/);
  }

  async isLoggedIn(): Promise<boolean> {
    try {
      await this.page.waitForURL(/dashboard/, { timeout: 5000 });
      return true;
    } catch {
      return false;
    }
  }
}
EOF

    # Test specifications
    cat > "$output_dir/auth.spec.ts" << 'EOF'
import { test, expect } from '@playwright/test';
import { AuthPage } from './pages/auth.page';

test.describe('Authentication Tests', () => {
  let authPage: AuthPage;

  test.beforeEach(async ({ page }) => {
    authPage = new AuthPage(page);
    await authPage.goto();
  });

  test.describe('Login Functionality', () => {
    test('should login with valid credentials @smoke', async ({ page }) => {
      await authPage.login(
        process.env.TEST_USER_EMAIL!,
        process.env.TEST_USER_PASSWORD!
      );
      
      await authPage.expectSuccess();
      expect(page.url()).toContain('/dashboard');
    });

    test('should show error with invalid credentials', async ({ page }) => {
      await authPage.login('invalid@example.com', 'wrongpassword');
      await authPage.expectError('Invalid email or password');
    });

    test('should validate email format', async ({ page }) => {
      await authPage.emailInput.fill('invalid-email');
      await authPage.passwordInput.fill('password123');
      await authPage.submitButton.click();
      
      const emailError = page.locator('span[data-testid="email-error"]');
      await expect(emailError).toHaveText('Please enter a valid email address');
    });

    test('should require password', async ({ page }) => {
      await authPage.emailInput.fill('test@example.com');
      await authPage.submitButton.click();
      
      const passwordError = page.locator('span[data-testid="password-error"]');
      await expect(passwordError).toHaveText('Password is required');
    });

    test('should handle server errors gracefully', async ({ page, context }) => {
      // Mock API to return 500 error
      await context.route('**/api/auth/login', (route) => {
        route.fulfill({
          status: 500,
          body: JSON.stringify({ error: 'Internal server error' }),
        });
      });

      await authPage.login('test@example.com', 'password123');
      await authPage.expectError('Something went wrong. Please try again.');
    });

    test('should redirect to original page after login', async ({ page }) => {
      // Try to access protected page
      await page.goto('/profile');
      
      // Should redirect to login
      await expect(page).toHaveURL(/login/);
      
      // Login
      await authPage.login(
        process.env.TEST_USER_EMAIL!,
        process.env.TEST_USER_PASSWORD!
      );
      
      // Should redirect back to profile
      await expect(page).toHaveURL(/profile/);
    });
  });

  test.describe('Password Reset', () => {
    test('should send reset email', async ({ page }) => {
      await authPage.forgotPasswordLink.click();
      await expect(page).toHaveURL(/forgot-password/);
      
      const emailInput = page.locator('input[name="email"]');
      const submitButton = page.locator('button[type="submit"]');
      
      await emailInput.fill('test@example.com');
      await submitButton.click();
      
      const successMessage = page.locator('.success-message');
      await expect(successMessage).toHaveText(/reset link has been sent/);
    });
  });

  test.describe('Session Management', () => {
    test('should maintain session across page refreshes', async ({ page }) => {
      // Login
      await authPage.login(
        process.env.TEST_USER_EMAIL!,
        process.env.TEST_USER_PASSWORD!
      );
      await authPage.expectSuccess();
      
      // Refresh page
      await page.reload();
      
      // Should still be logged in
      expect(page.url()).toContain('/dashboard');
    });

    test('should logout successfully', async ({ page }) => {
      // Login first
      await authPage.login(
        process.env.TEST_USER_EMAIL!,
        process.env.TEST_USER_PASSWORD!
      );
      await authPage.expectSuccess();
      
      // Logout
      const userMenu = page.locator('[data-testid="user-menu"]');
      await userMenu.click();
      
      const logoutButton = page.locator('button:has-text("Logout")');
      await logoutButton.click();
      
      // Should redirect to login
      await expect(page).toHaveURL(/login/);
      
      // Try to access protected page
      await page.goto('/dashboard');
      
      // Should redirect back to login
      await expect(page).toHaveURL(/login/);
    });
  });

  test.describe('Security Tests', () => {
    test('should prevent XSS in login form', async ({ page }) => {
      const xssPayload = '<script>alert("XSS")</script>';
      
      await authPage.emailInput.fill(xssPayload);
      await authPage.passwordInput.fill('password');
      await authPage.submitButton.click();
      
      // Check that script is not executed
      const alertDialogs: string[] = [];
      page.on('dialog', (dialog) => {
        alertDialogs.push(dialog.message());
        dialog.dismiss();
      });
      
      await page.waitForTimeout(1000);
      expect(alertDialogs).toHaveLength(0);
    });

    test('should implement rate limiting @security', async ({ page }) => {
      // Attempt multiple failed logins
      for (let i = 0; i < 6; i++) {
        await authPage.login('test@example.com', 'wrongpassword');
        await page.waitForTimeout(100);
      }
      
      // Should show rate limit error
      await authPage.expectError('Too many attempts. Please try again later.');
    });
  });
});
EOF

    # Visual regression tests
    cat > "$output_dir/auth.visual.spec.ts" << 'EOF'
import { test, expect } from '@playwright/test';
import { AuthPage } from './pages/auth.page';

test.describe('Authentication Visual Tests', () => {
  let authPage: AuthPage;

  test.beforeEach(async ({ page }) => {
    authPage = new AuthPage(page);
    await authPage.goto();
  });

  test('login page should match visual snapshot', async ({ page }) => {
    await expect(page).toHaveScreenshot('login-page.png', {
      fullPage: true,
      animations: 'disabled',
    });
  });

  test('login form with errors should match snapshot', async ({ page }) => {
    // Trigger validation errors
    await authPage.submitButton.click();
    
    // Wait for errors to appear
    await page.locator('.error-message').first().waitFor();
    
    await expect(page).toHaveScreenshot('login-errors.png', {
      fullPage: true,
      animations: 'disabled',
    });
  });

  test('mobile login page should match snapshot', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    
    await expect(page).toHaveScreenshot('login-mobile.png', {
      fullPage: true,
      animations: 'disabled',
    });
  });
});
EOF
    
    log_event "SUCCESS" "QA_AUTOMATION" "Authentication tests generated"
}

# Generate API tests
generate_api_test_suite() {
    local output_dir="$QA_STATE/tests/api"
    mkdir -p "$output_dir"
    
    log_event "INFO" "QA_AUTOMATION" "Generating API test suite"
    
    # API test utilities
    cat > "$output_dir/api.utils.ts" << 'EOF'
import { APIRequestContext, request } from '@playwright/test';

export class APIClient {
  private context: APIRequestContext;
  private baseURL: string;
  private token?: string;

  constructor(context: APIRequestContext, baseURL: string) {
    this.context = context;
    this.baseURL = baseURL;
  }

  async authenticate(email: string, password: string): Promise<void> {
    const response = await this.context.post('/api/auth/login', {
      data: { email, password }
    });
    
    if (!response.ok()) {
      throw new Error(`Authentication failed: ${response.status()}`);
    }
    
    const data = await response.json();
    this.token = data.token;
  }

  async get(endpoint: string, options?: any) {
    return this.request('GET', endpoint, options);
  }

  async post(endpoint: string, data?: any, options?: any) {
    return this.request('POST', endpoint, { ...options, data });
  }

  async put(endpoint: string, data?: any, options?: any) {
    return this.request('PUT', endpoint, { ...options, data });
  }

  async delete(endpoint: string, options?: any) {
    return this.request('DELETE', endpoint, options);
  }

  private async request(method: string, endpoint: string, options?: any) {
    const headers = {
      ...options?.headers,
      ...(this.token ? { Authorization: `Bearer ${this.token}` } : {})
    };

    return this.context.fetch(endpoint, {
      method,
      ...options,
      headers
    });
  }
}

export async function createAPIContext(baseURL?: string): Promise<APIRequestContext> {
  return request.newContext({
    baseURL: baseURL || process.env.API_URL || 'http://localhost:3000',
    extraHTTPHeaders: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    }
  });
}
EOF

    # API tests
    cat > "$output_dir/api.spec.ts" << 'EOF'
import { test, expect } from '@playwright/test';
import { APIClient, createAPIContext } from './api.utils';

test.describe('API Tests', () => {
  let apiClient: APIClient;

  test.beforeAll(async () => {
    const context = await createAPIContext();
    apiClient = new APIClient(context, process.env.API_URL!);
  });

  test.describe('Authentication API', () => {
    test('POST /api/auth/login - should authenticate with valid credentials', async () => {
      const response = await apiClient.post('/api/auth/login', {
        email: process.env.TEST_USER_EMAIL,
        password: process.env.TEST_USER_PASSWORD
      });

      expect(response.ok()).toBeTruthy();
      
      const data = await response.json();
      expect(data).toHaveProperty('token');
      expect(data).toHaveProperty('user');
      expect(data.user.email).toBe(process.env.TEST_USER_EMAIL);
    });

    test('POST /api/auth/login - should reject invalid credentials', async () => {
      const response = await apiClient.post('/api/auth/login', {
        email: 'invalid@example.com',
        password: 'wrongpassword'
      });

      expect(response.status()).toBe(401);
      
      const data = await response.json();
      expect(data).toHaveProperty('error');
      expect(data.error).toContain('Invalid');
    });

    test('POST /api/auth/register - should create new user', async () => {
      const uniqueEmail = `test-${Date.now()}@example.com`;
      
      const response = await apiClient.post('/api/auth/register', {
        email: uniqueEmail,
        password: 'TestPass123!',
        firstName: 'Test',
        lastName: 'User'
      });

      expect(response.ok()).toBeTruthy();
      expect(response.status()).toBe(201);
      
      const data = await response.json();
      expect(data).toHaveProperty('userId');
    });
  });

  test.describe('User API', () => {
    test.beforeEach(async () => {
      await apiClient.authenticate(
        process.env.TEST_USER_EMAIL!,
        process.env.TEST_USER_PASSWORD!
      );
    });

    test('GET /api/users/me - should return current user', async () => {
      const response = await apiClient.get('/api/users/me');
      
      expect(response.ok()).toBeTruthy();
      
      const user = await response.json();
      expect(user).toHaveProperty('id');
      expect(user).toHaveProperty('email');
      expect(user.email).toBe(process.env.TEST_USER_EMAIL);
    });

    test('PUT /api/users/me - should update user profile', async () => {
      const updates = {
        firstName: 'Updated',
        lastName: 'Name'
      };

      const response = await apiClient.put('/api/users/me', updates);
      
      expect(response.ok()).toBeTruthy();
      
      const user = await response.json();
      expect(user.firstName).toBe(updates.firstName);
      expect(user.lastName).toBe(updates.lastName);
    });
  });

  test.describe('Performance Tests', () => {
    test('API response times should be within SLA', async () => {
      const endpoints = [
        '/api/health',
        '/api/users/me',
        '/api/products',
      ];

      for (const endpoint of endpoints) {
        const start = Date.now();
        const response = await apiClient.get(endpoint);
        const duration = Date.now() - start;

        expect(response.ok()).toBeTruthy();
        expect(duration).toBeLessThan(200); // 200ms SLA
      }
    });
  });

  test.describe('Security Tests', () => {
    test('should reject requests without authentication', async () => {
      const unauthClient = new APIClient(
        await createAPIContext(),
        process.env.API_URL!
      );

      const response = await unauthClient.get('/api/users/me');
      expect(response.status()).toBe(401);
    });

    test('should implement rate limiting', async () => {
      const requests = Array(20).fill(null).map(() => 
        apiClient.get('/api/health')
      );

      const responses = await Promise.all(requests);
      const rateLimited = responses.some(r => r.status() === 429);
      
      expect(rateLimited).toBeTruthy();
    });
  });
});
EOF
    
    log_event "SUCCESS" "QA_AUTOMATION" "API test suite generated"
}

# Generate mobile test suite
generate_mobile_tests() {
    local output_dir="$QA_STATE/tests/mobile"
    mkdir -p "$output_dir"
    
    log_event "INFO" "QA_AUTOMATION" "Generating mobile test suite"
    
    cat > "$output_dir/mobile.spec.ts" << 'EOF'
import { test, expect, devices } from '@playwright/test';

// Test different mobile devices
const mobileDevices = [
  { name: 'iPhone 13', device: devices['iPhone 13'] },
  { name: 'Pixel 5', device: devices['Pixel 5'] },
  { name: 'iPad Pro', device: devices['iPad Pro'] },
];

test.describe('Mobile Tests', () => {
  for (const { name, device } of mobileDevices) {
    test.describe(`${name} Tests`, () => {
      test.use(device);

      test('should display mobile navigation', async ({ page }) => {
        await page.goto('/');
        
        // Mobile menu should be visible
        const mobileMenu = page.locator('[data-testid="mobile-menu"]');
        await expect(mobileMenu).toBeVisible();
        
        // Desktop menu should be hidden
        const desktopMenu = page.locator('[data-testid="desktop-menu"]');
        await expect(desktopMenu).toBeHidden();
      });

      test('should handle touch interactions', async ({ page }) => {
        await page.goto('/');
        
        // Test swipe gesture
        const carousel = page.locator('[data-testid="carousel"]');
        await carousel.scrollIntoViewIfNeeded();
        
        const boundingBox = await carousel.boundingBox();
        if (boundingBox) {
          await page.touchscreen.tap(
            boundingBox.x + boundingBox.width / 2,
            boundingBox.y + boundingBox.height / 2
          );
        }
      });

      test('should have responsive images', async ({ page }) => {
        await page.goto('/');
        
        const images = page.locator('img');
        const count = await images.count();
        
        for (let i = 0; i < count; i++) {
          const img = images.nth(i);
          const srcset = await img.getAttribute('srcset');
          
          // Should have responsive images
          expect(srcset).toBeTruthy();
        }
      });

      test('forms should be mobile-friendly', async ({ page }) => {
        await page.goto('/contact');
        
        // Input fields should be large enough for touch
        const inputs = page.locator('input, textarea, button');
        const count = await inputs.count();
        
        for (let i = 0; i < count; i++) {
          const element = inputs.nth(i);
          const box = await element.boundingBox();
          
          if (box) {
            expect(box.height).toBeGreaterThanOrEqual(44); // iOS recommendation
          }
        }
      });
    });
  }

  test.describe('Orientation Tests', () => {
    test('should handle portrait to landscape transition', async ({ browser }) => {
      const context = await browser.newContext({
        ...devices['iPhone 13'],
        viewport: { width: 390, height: 844 }, // Portrait
      });
      
      const page = await context.newPage();
      await page.goto('/');
      
      // Take screenshot in portrait
      await page.screenshot({ path: 'portrait.png' });
      
      // Switch to landscape
      await page.setViewportSize({ width: 844, height: 390 });
      
      // Layout should adjust
      await page.waitForTimeout(500); // Wait for transition
      await page.screenshot({ path: 'landscape.png' });
      
      await context.close();
    });
  });

  test.describe('Performance on Mobile', () => {
    test('should load within 3 seconds on 3G', async ({ browser }) => {
      const context = await browser.newContext({
        ...devices['iPhone 13'],
      });
      
      const page = await context.newPage();
      
      // Simulate 3G network
      await page.route('**/*', (route) => {
        route.continue();
      });
      
      const startTime = Date.now();
      await page.goto('/', { waitUntil: 'networkidle' });
      const loadTime = Date.now() - startTime;
      
      expect(loadTime).toBeLessThan(3000);
      
      await context.close();
    });
  });
});
EOF
    
    log_event "SUCCESS" "QA_AUTOMATION" "Mobile test suite generated"
}

# Generate test data factory
generate_test_data() {
    local output_dir="$QA_STATE/tests/fixtures"
    mkdir -p "$output_dir"
    
    log_event "INFO" "QA_AUTOMATION" "Generating test data factory"
    
    cat > "$output_dir/test-data.ts" << 'EOF'
import { faker } from '@faker-js/faker';

export class TestDataFactory {
  static createUser(overrides?: Partial<User>): User {
    return {
      id: faker.string.uuid(),
      email: faker.internet.email(),
      password: 'TestPass123!',
      firstName: faker.person.firstName(),
      lastName: faker.person.lastName(),
      role: 'user',
      isActive: true,
      createdAt: faker.date.past(),
      ...overrides
    };
  }

  static createProduct(overrides?: Partial<Product>): Product {
    return {
      id: faker.string.uuid(),
      name: faker.commerce.productName(),
      description: faker.commerce.productDescription(),
      price: parseFloat(faker.commerce.price()),
      category: faker.commerce.department(),
      stock: faker.number.int({ min: 0, max: 100 }),
      image: faker.image.url(),
      ...overrides
    };
  }

  static createOrder(overrides?: Partial<Order>): Order {
    const items = Array.from({ length: faker.number.int({ min: 1, max: 5 }) }, () => ({
      productId: faker.string.uuid(),
      quantity: faker.number.int({ min: 1, max: 10 }),
      price: parseFloat(faker.commerce.price())
    }));

    const total = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);

    return {
      id: faker.string.uuid(),
      userId: faker.string.uuid(),
      items,
      total,
      status: faker.helpers.arrayElement(['pending', 'processing', 'shipped', 'delivered']),
      shippingAddress: {
        street: faker.location.streetAddress(),
        city: faker.location.city(),
        state: faker.location.state(),
        zip: faker.location.zipCode(),
        country: faker.location.country()
      },
      createdAt: faker.date.recent(),
      ...overrides
    };
  }

  static createCreditCard(): CreditCard {
    return {
      number: '4242424242424242', // Test card number
      expMonth: faker.date.future().getMonth() + 1,
      expYear: faker.date.future().getFullYear(),
      cvc: '123',
      name: faker.person.fullName()
    };
  }

  static generateTestScenarios(): TestScenario[] {
    return [
      {
        name: 'Happy Path',
        user: this.createUser({ isActive: true }),
        products: Array.from({ length: 3 }, () => this.createProduct()),
        expectedOutcome: 'success'
      },
      {
        name: 'Inactive User',
        user: this.createUser({ isActive: false }),
        products: [],
        expectedOutcome: 'blocked'
      },
      {
        name: 'Out of Stock',
        user: this.createUser(),
        products: [this.createProduct({ stock: 0 })],
        expectedOutcome: 'out_of_stock'
      }
    ];
  }
}

// Type definitions
interface User {
  id: string;
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  role: 'user' | 'admin';
  isActive: boolean;
  createdAt: Date;
}

interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  stock: number;
  image: string;
}

interface Order {
  id: string;
  userId: string;
  items: OrderItem[];
  total: number;
  status: string;
  shippingAddress: Address;
  createdAt: Date;
}

interface OrderItem {
  productId: string;
  quantity: number;
  price: number;
}

interface Address {
  street: string;
  city: string;
  state: string;
  zip: string;
  country: string;
}

interface CreditCard {
  number: string;
  expMonth: number;
  expYear: number;
  cvc: string;
  name: string;
}

interface TestScenario {
  name: string;
  user: User;
  products: Product[];
  expectedOutcome: string;
}
EOF
    
    log_event "SUCCESS" "QA_AUTOMATION" "Test data factory generated"
}

# Generate CI/CD integration
generate_ci_integration() {
    local ci_platform="${1:-github}"
    local output_dir="$QA_STATE/configs/ci"
    mkdir -p "$output_dir"
    
    log_event "INFO" "QA_AUTOMATION" "Generating CI/CD integration for $ci_platform"
    
    case "$ci_platform" in
        github)
            cat > "$output_dir/playwright.yml" << 'EOF'
name: Playwright Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  schedule:
    - cron: '0 6 * * *' # Daily at 6 AM

jobs:
  test:
    timeout-minutes: 60
    runs-on: ubuntu-latest
    strategy:
      matrix:
        shard: [1, 2, 3, 4]
    
    steps:
    - uses: actions/checkout@v3
    
    - uses: actions/setup-node@v3
      with:
        node-version: 18
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Install Playwright Browsers
      run: npx playwright install --with-deps
    
    - name: Run Playwright tests
      run: npm run test -- --shard=${{ matrix.shard }}/4
      env:
        BASE_URL: ${{ secrets.BASE_URL }}
        TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
        TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}
    
    - uses: actions/upload-artifact@v3
      if: always()
      with:
        name: playwright-report-${{ matrix.shard }}
        path: playwright-report/
        retention-days: 30
    
    - uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results-${{ matrix.shard }}
        path: test-results/
        retention-days: 30

  report:
    needs: test
    if: always()
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - uses: actions/download-artifact@v3
      with:
        path: artifacts
    
    - name: Merge Reports
      run: |
        npm ci
        npx playwright merge-reports --reporter html ./artifacts/playwright-report-*
    
    - uses: actions/upload-artifact@v3
      with:
        name: playwright-report-combined
        path: playwright-report/
        retention-days: 30
    
    - name: Send Slack Notification
      if: failure()
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        text: 'Playwright tests failed! Check the report.'
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
EOF
            ;;
            
        gitlab)
            cat > "$output_dir/.gitlab-ci.yml" << 'EOF'
stages:
  - test
  - report

variables:
  PLAYWRIGHT_BROWSERS_PATH: $CI_PROJECT_DIR/browsers
  NODE_VERSION: "18"

cache:
  key: $CI_COMMIT_REF_SLUG
  paths:
    - node_modules/
    - browsers/

before_script:
  - apt-get update -qy
  - apt-get install -y wget gnupg
  - curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
  - apt-get install -y nodejs
  - npm ci
  - npx playwright install --with-deps

playwright:
  stage: test
  parallel: 4
  script:
    - npm run test -- --shard=$CI_NODE_INDEX/$CI_NODE_TOTAL
  artifacts:
    when: always
    paths:
      - playwright-report/
      - test-results/
    expire_in: 30 days
  only:
    - merge_requests
    - main
    - develop

test-report:
  stage: report
  dependencies:
    - playwright
  script:
    - npx playwright merge-reports --reporter html ./playwright-report-*
  artifacts:
    paths:
      - playwright-report/
    expire_in: 30 days
  when: always
EOF
            ;;
    esac
    
    log_event "SUCCESS" "QA_AUTOMATION" "CI/CD integration generated for $ci_platform"
}

# Generate test execution script
generate_test_runner() {
    local output_file="$QA_STATE/run_tests.sh"
    
    log_event "INFO" "QA_AUTOMATION" "Generating test runner script"
    
    cat > "$output_file" << 'EOF'
#!/bin/bash
# Test Runner Script

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
TEST_TYPE="${1:-all}"
ENVIRONMENT="${2:-local}"
HEADED="${3:-false}"

echo "🧪 QA Automation Test Runner"
echo "=========================="
echo "Test Type: $TEST_TYPE"
echo "Environment: $ENVIRONMENT"
echo "Headed Mode: $HEADED"
echo ""

# Set environment
case "$ENVIRONMENT" in
    local)
        export BASE_URL="http://localhost:3000"
        ;;
    staging)
        export BASE_URL="https://staging.example.com"
        ;;
    production)
        export BASE_URL="https://app.example.com"
        ;;
esac

# Install dependencies if needed
if [[ ! -d "node_modules" ]]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Install browsers if needed
if [[ ! -d "browsers" ]]; then
    echo "🌐 Installing browsers..."
    npx playwright install --with-deps
fi

# Run tests based on type
case "$TEST_TYPE" in
    smoke)
        echo "🔥 Running smoke tests..."
        npm run test:smoke
        ;;
    regression)
        echo "🔄 Running regression tests..."
        npm run test:regression
        ;;
    api)
        echo "🔌 Running API tests..."
        npm run test:api
        ;;
    mobile)
        echo "📱 Running mobile tests..."
        npm run test:mobile
        ;;
    e2e)
        echo "🌍 Running E2E tests..."
        npm run test:e2e
        ;;
    all)
        echo "🚀 Running all tests..."
        npm test
        ;;
    *)
        echo -e "${RED}Unknown test type: $TEST_TYPE${NC}"
        exit 1
        ;;
esac

# Generate report
echo ""
echo "📊 Generating test report..."
npm run test:report

# Show results
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Tests passed!${NC}"
    echo "View detailed report: npx playwright show-report"
else
    echo -e "${RED}❌ Tests failed!${NC}"
    echo "View detailed report: npx playwright show-report"
    exit 1
fi
EOF
    
    chmod +x "$output_file"
    log_event "SUCCESS" "QA_AUTOMATION" "Test runner script generated"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        init)
            local framework="${2:-playwright}"
            echo -e "${CYAN}Initializing $framework test framework...${NC}"
            initialize_framework "$framework"
            generate_test_data
            generate_test_runner
            echo -e "${GREEN}✓ QA Automation framework initialized!${NC}"
            ;;
        generate)
            local test_type="${2:-e2e}"
            local feature="${3:-authentication}"
            echo -e "${CYAN}Generating $test_type tests for $feature...${NC}"
            case "$test_type" in
                e2e)
                    generate_e2e_tests "$feature"
                    ;;
                api)
                    generate_api_test_suite
                    ;;
                mobile)
                    generate_mobile_tests
                    ;;
                *)
                    echo -e "${RED}Unknown test type: $test_type${NC}"
                    exit 1
                    ;;
            esac
            echo -e "${GREEN}✓ Tests generated!${NC}"
            ;;
        ci)
            local platform="${2:-github}"
            generate_ci_integration "$platform"
            echo -e "${GREEN}✓ CI/CD integration configured for $platform!${NC}"
            ;;
        run)
            local test_type="${2:-all}"
            if [[ -x "$QA_STATE/run_tests.sh" ]]; then
                "$QA_STATE/run_tests.sh" "$test_type"
            else
                echo -e "${RED}Test runner not found. Run 'init' first.${NC}"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 {init|generate|ci|run} [options]"
            echo ""
            echo "Commands:"
            echo "  init [framework]           - Initialize test framework (playwright/cypress/selenium)"
            echo "  generate [type] [feature]  - Generate tests (e2e/api/mobile)"
            echo "  ci [platform]              - Generate CI/CD config (github/gitlab)"
            echo "  run [type]                 - Run tests (smoke/regression/api/mobile/e2e/all)"
            exit 1
            ;;
    esac
}

main "$@"