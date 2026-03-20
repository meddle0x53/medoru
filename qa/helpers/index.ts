/**
 * QA Testing Helpers
 *
 * Re-exports all helpers for convenient imports.
 *
 * @example
 * import { createAuthHelper, TEST_USERS, navigateTo, expectHeading } from '../helpers';
 */

// Auth helpers
export { createAuthHelper, authenticateAndSaveState, waitForServer } from './auth';
export type { AuthHelper } from './auth';

// Navigation helpers
export {
  navigateTo,
  waitForPageLoad,
  getPageTitle,
  isOnPage,
  waitForNavigation,
  clickNavLink,
  openMobileNav,
  navigateViaMobileMenu,
  getNavLinks,
  goToLesson,
  goToKanji,
  goToClassroom,
  PATHS,
} from './navigation';
export type { PathKey } from './navigation';

// Assertion helpers
export {
  expectHeading,
  expectFlashMessage,
  expectAuthenticated,
  expectUnauthenticated,
  expectPageText,
  expectTestIdVisible,
  expectUrl,
  expectDisabled,
  expectEnabled,
  expectInputValue,
  expectNoConsoleErrors,
  expectValidationError,
  expectLoadingState,
  waitForLoadingComplete,
  expectAccessible,
} from './assertions';
