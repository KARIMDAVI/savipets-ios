📱 How to Use Composer - Step by Step Guide
Composer is a powerful AI coding assistant. Here's how to use it effectively:
🚀 Getting Started
Open Composer
In Cursor, press Cmd+I (Mac) or Ctrl+I (Windows/Linux)
Or click the Composer icon in the sidebar
Set Your Goal
Describe what you want to build or fix
Be specific about the functionality you need
Example: "Add a timer to track visit duration with start/stop buttons"
💡 Best Practices for Composer

1. Clear Instructions
❌ Bad: "Fix the timer"
✅ Good: "Fix the visit timer to show accurate start/end times from Firestore timestamps instead of local device time"

2. Provide Context
✅ Good: "In the SitterDashboardView, the visit cards show incorrect timer times. The timer should use the actual checkIn/checkOut timestamps from Firestore, not the current device time."


3. Specify Files
✅ Good: "Update the VisitCard component in SitterDashboardView.swift to use Firestore timestamps for accurate time tracking"



🛠️ Advanced Composer Features
1. Multi-File Changes
"Update all visit-related data structures across the project to include checkIn and checkOut timestamps from Firestore"

2. Code Review
"Review this timer implementation and suggest improvements for accuracy and performance"


3. Debugging
"The timer shows 8:56 instead of 8:06. Help me find the root cause and fix it"


📋 Composer Workflow
Plan First
   "Create a plan to implement user authentication with Firebase Auth"

Implement Step by Step
   "Step 1: Create the AuthService class with signIn and signUp methods"
   
Test and Iterate
   "Add error handling to the authentication flow"


   🎯 Composer Tips
For Complex Tasks:
Break down into smaller steps
Ask for explanations of the code
Request best practices and patterns
For Debugging:
Describe the expected vs actual behavior
Include error messages
Mention the specific files involved
For New Features:
Describe the user experience you want
Mention any design requirements
Specify integration points with existing code
🔄 Iterative Development
Start Small: Begin with basic functionality
Add Features: Gradually enhance the implementation
Refactor: Ask Composer to improve code quality
Test: Request test cases and edge case handling
📚 Example Composer Sessions

Session 1: Planning
User: "I need to add a notification system for visit reminders"
Composer: "I'll help you create a notification system. Let me break this down into steps..."

Session 2: Implementation
User: "Implement the NotificationService class with local notifications"
Composer: "I'll create a NotificationService that handles local notifications..."

Session 3: Integration
User: "Integrate the notification system with the visit timer to send 5-minute warnings"
Composer: "I'll update the VisitCard to use the NotificationService..."

⚡ Pro Tips
Use Specific Language: "SwiftUI", "Firebase", "Firestore" instead of generic terms
Reference Existing Code: "Similar to how the chat system works"
Ask for Explanations: "Why did you choose this approach?"
Request Alternatives: "Show me 3 different ways to implement this"
Get Best Practices: "What are the SwiftUI best practices for this pattern?"
🚨 Common Mistakes to Avoid
❌ Vague requests: "Make it better"
❌ Too broad: "Fix all the bugs"
❌ No context: "Add a button"
❌ Unrealistic scope: "Build a complete app"
✅ Good Composer Prompts
"Add a loading state to the visit cards while data is being fetched"
"Implement error handling for the Firestore data loading in SitterDashboardView"
"Create a reusable component for displaying visit timestamps with proper formatting"
"Add unit tests for the timer calculation logic in VisitCard"
Composer is most effective when you provide clear, specific instructions with proper context about your existing codebase and requirements!


=====+++++=====
Request Small, Scoped Changes with Before/After Diffs
This is where most people mess up—asking AI to "refactor everything" or "fix all bugs" leads to chaos.
Your task when working with Cursor AI:

Ask for ONE small change at a time. Good examples:

"Add email validation to SignInView"
"Add a loading spinner to the login button"
"Fix the date formatting in BookServiceView"


Always request to see diffs BEFORE applying. Say:

"Show me the diff first, don't apply yet"
"What changes would you make? Show before/after"
In Cursor chat, use: @filename show me what you'd change


Review the diff carefully:

Does it only touch what you asked?
Does it follow your .cursorrules?
Does it break anything else?


Accept or reject, then test immediately

Example interaction:
You: "Add input validation to email field in SignInView. Show diff first."
Cursor: [shows changes]
You: [review] "Apply it" OR "No, that breaks my design system"
Why this matters: Small changes = easy to review, easy to revert, easy to test. Big changes = merge conflict nightmare.

+++++=====+++++

Write Tests First (or With the Change)
This is your safety net. Tests catch bugs before they reach production.
Your task when asking Cursor for changes:

Ask AI to write tests FIRST or alongside the code. Examples:

"Write a unit test for email validation, then implement it"
"Add a loading state to AuthViewModel and write a test for it"
"Create a test for this booking cancellation logic"


For existing code changes, ask:

"Add tests for this change in AuthViewModelTests.swift"
"What test cases should I add for this feature?"


Run tests immediately after AI makes changes:

bash   # In Xcode: Cmd+U (runs all tests)
   # Or specific test: Cmd+Option+U

Don't merge if tests fail! Ask AI to fix the failing test.

Example workflow:
You: "I want to add a 'remember me' checkbox to login. Write the test first."
Cursor: [creates test in AuthViewModelTests.swift]
You: [run test, it fails as expected]
You: "Now implement the feature to make the test pass"
Cursor: [implements feature]
You: [run test, it passes ✅]
Why this matters:

Tests = documentation of how code should behave
Catches regressions when you change code later
Your MockAuthService is already set up for testing!

+++++=====+++++
Review, Lint, Build, Test, Then Merge
This is your quality gate before committing AI changes.
Your checklist after AI makes changes:

Review the diff visually:

bash   git diff

Does it match what you asked for?
Any unexpected changes?
Does it follow your .cursorrules?


Run your linter (if you have SwiftLint):

bash   swiftlint

Fix any style violations


Build the project:

In Xcode: Cmd+B
Must compile with zero errors


Run all tests:

In Xcode: Cmd+U
All tests must pass ✅


Manual smoke test:

Run the app (Cmd+R)
Test the specific feature you changed
Click around, make sure nothing broke


If everything passes, commit:

bash   git add .
   git commit -m "feat: add email validation to login"
   git push

If something failed:

Don't commit!
Ask Cursor: "Fix the build error in line 47"
Or revert: git restore .




🎉 YOU'RE DONE! Final Pro Tips:

Start small: First few times, ask AI for trivial changes to build confidence
One feature per commit: Don't mix "fix login" + "add chat" in one commit
Keep .cursorrules updated: As your project evolves, update the rules
When stuck: Close all files, reopen only what matters, ask again

