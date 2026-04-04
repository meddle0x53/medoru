/**
 * Test user fixtures for QA scenarios
 *
 * These users are seeded in the QA database via priv/repo/qa_seeds.exs
 */

export interface TestUser {
  email: string;
  name: string;
  type: 'student' | 'teacher' | 'admin';
  description: string;
}

export const TEST_USERS = {
  // Admin users
  admin: {
    email: 'admin@qa.test',
    name: 'QA Admin',
    type: 'admin' as const,
    description: 'Full admin access',
  },
  admin2: {
    email: 'admin2@qa.test',
    name: 'Second Admin',
    type: 'admin' as const,
    description: 'Secondary admin account',
  },

  // Moderator user
  moderator: {
    email: 'moderator@qa.test',
    name: 'QA Moderator',
    type: 'student' as const,
    description: 'Moderator with content management access',
  },

  // Teacher users
  teacher: {
    email: 'teacher@qa.test',
    name: 'QA Teacher',
    type: 'teacher' as const,
    description: 'Teacher with classrooms',
  },
  teacher2: {
    email: 'teacher2@qa.test',
    name: 'Second Teacher',
    type: 'teacher' as const,
    description: 'Second teacher account',
  },
  teacherNoClasses: {
    email: 'teachernoclasses@qa.test',
    name: 'Teacher No Classes',
    type: 'teacher' as const,
    description: 'Teacher without any classrooms',
  },

  // Student users
  student: {
    email: 'student@qa.test',
    name: 'QA Student',
    type: 'student' as const,
    description: 'Regular student',
  },
  student2: {
    email: 'student2@qa.test',
    name: 'Second Student',
    type: 'student' as const,
    description: 'Second student account',
  },
  studentNew: {
    email: 'studentnew@qa.test',
    name: 'New Student',
    type: 'student' as const,
    description: 'New student with minimal progress (3 lessons)',
  },
  studentAdvanced: {
    email: 'studentadvanced@qa.test',
    name: 'Advanced Student',
    type: 'student' as const,
    description: 'Advanced student (50 lessons, 15-day streak, level 6)',
  },
  studentInactive: {
    email: 'studentinactive@qa.test',
    name: 'Inactive Student',
    type: 'student' as const,
    description: 'Inactive student with broken streak',
  },

  // Classroom students
  classroomStudent1: {
    email: 'classroom.student1@qa.test',
    name: 'Classroom Student 1',
    type: 'student' as const,
    description: 'Student for classroom testing',
  },
  classroomStudent2: {
    email: 'classroom.student2@qa.test',
    name: 'Classroom Student 2',
    type: 'student' as const,
    description: 'Student for classroom testing',
  },
  classroomStudent3: {
    email: 'classroom.student3@qa.test',
    name: 'Classroom Student 3',
    type: 'student' as const,
    description: 'Student for classroom testing',
  },
  classroomStudent4: {
    email: 'classroom.student4@qa.test',
    name: 'Classroom Student 4',
    type: 'student' as const,
    description: 'Student for classroom testing',
  },
  classroomStudent5: {
    email: 'classroom.student5@qa.test',
    name: 'Classroom Student 5',
    type: 'student' as const,
    description: 'Student for classroom testing',
  },

  // Edge cases
  longName: {
    email: 'user.longname@qa.test',
    name: 'User With A Very Long Name That Might Cause UI Issues',
    type: 'student' as const,
    description: 'User with very long name for UI testing',
  },
  specialChars: {
    email: 'user.special+chars@qa.test',
    name: 'Special Chars User',
    type: 'student' as const,
    description: 'User with special characters in email',
  },
  unicodeName: {
    email: 'user.unicode@qa.test',
    name: 'ユーザー テスト',
    type: 'student' as const,
    description: 'User with unicode/Japanese name',
  },
} as const;

/**
 * Get all users of a specific type
 */
export function getUsersByType(type: TestUser['type']): TestUser[] {
  return Object.values(TEST_USERS).filter((user) => user.type === type);
}

/**
 * Get a user by email
 */
export function getUserByEmail(email: string): TestUser | undefined {
  return Object.values(TEST_USERS).find((user) => user.email === email);
}

/**
 * Get classroom students (useful for bulk classroom operations)
 */
export function getClassroomStudents(): TestUser[] {
  return [
    TEST_USERS.classroomStudent1,
    TEST_USERS.classroomStudent2,
    TEST_USERS.classroomStudent3,
    TEST_USERS.classroomStudent4,
    TEST_USERS.classroomStudent5,
  ];
}
