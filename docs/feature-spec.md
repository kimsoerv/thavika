# Thavika: expense, plan and savings app (feature draft)

App name: **Thavika** (ថវិកា, "budget, funds"; from Pali thavikā, "purse, money bag"). Store subtitle: "Budget & Savings Tracker". Project folder: `thavika`.

Status: draft for discussion. Nothing has been built yet.

## 1. Goal

A simple app that helps the user (and the user's wife, and other people) note daily expenses and income, make a monthly spending plan, save toward goals, and get reminded when spending goes in the wrong direction.

Main principle: adding an entry takes under 5 seconds. If it is slow, people stop using the app.

## 2. Decisions made

| Topic | Decision |
|---|---|
| Entry | Quick add: amount, category, save. Expense and income in one screen. |
| Plans | Four plan cards: 50/30/20, 70/20/10, 80/20, Custom. |
| Plan editing | User can edit amounts, rename, delete, and add categories. A "Left to assign" box shows if the plan adds up to income. |
| Plan storage | One plan at a time. No named plans list in version 1 (kept simple). |
| Tracking | Daily comparison of actual spending against the plan, with reminders. |
| AI | Gemini with the user's own API key, for photo scan and bank Excel/CSV import. User always reviews before saving. |
| Data | Offline first, no ads. |
| Connectivity | Must work in both offline and online mode. The phone's local database is the source of truth; online adds sync and backup (details still to discuss, see section 9). |
| Tech | Flutter, local database, secure storage for the key, local notifications. |
| Backend | Supabase (user does not want to pay for a server). Free plan to start. Local database stays the main copy; Supabase is optional sync and backup with row level security so each user only sees their own data. Gemini key stays on the phone and is never stored in Supabase. |

## 3. Feature list by version

### Version 1 (core)

1. **Quick add**: expense/income toggle, big amount, category icons, optional note, date defaults to today.
2. **Categories**: ready-made list with icons, user can add their own.
3. **Home screen**: "Safe to spend today", income, spent, category bar, recent entries.
4. **Transactions list**: grouped by day, search, filter by category or date, swipe to edit or delete.
5. **Plan suggestion**: user enters monthly income and picks a plan card. Amounts per category are listed automatically.
6. **Plan editing**: edit, rename, delete, add categories. "Left to assign" box (green when every dollar has a job, amber when money is left, red when over income). Reset to suggested amounts.
7. **Budgets**: each plan category becomes a monthly budget with a progress bar.
8. **Plan tracking and reminders**: see section 5.
9. **Savings goals**: name, target, date, progress ring, "save X per month" hint, add money.
10. **Recurring transactions**: salary, rent, subscriptions repeat by themselves.
11. **Backup and export**: export to Excel/CSV and restore, so changing phone does not lose data.
12. **Optional Google sign-in**: the app works fully without login (guest mode, data on the phone only). Signing in adds cloud backup and sync. A guest can sign in later and the existing data is uploaded.
13. **Offline and online sync**: every entry is saved on the phone first. If signed in and online it uploads right away; otherwise it is marked "waiting to sync" (draft) and uploads in the background when internet returns. See section 3b.
14. **Household sharing** (moved into version 1): two or more people share entries, plan, budgets, and goals. Requires sign-in.

### Version 2

- **Gemini photo scan**: photo of handwritten notes or receipts becomes draft entries.
- **Gemini Excel/CSV import**: bank statement becomes categorized entries.
- **Gemini tips**: one friendly suggestion based on the numbers (optional).
- **Safe-to-spend improvements**, monthly report, comparison with last month.
- **Multiple wallets** (cash, bank, e-wallet).
- **PIN or fingerprint lock.**

### Version 3 (ideas)

- Subscription and bill tracker with due-date reminders.
- Home-screen widget and voice entry.
- Savings streaks and challenges.
- Debt and money-lent tracker.
- Named plans ("Our family plan", "Tight month").

## 3a. Manual entry flow (user notes expenses and income by hand)

This is the main daily action and must stay fast.

Steps:

1. Tap the + button (available from every main screen).
2. Choose type: Expense or Income (one toggle, Expense is the default).
3. Type the amount on a big keypad. Amount is required and must be above zero.
4. Pick a category with one tap. Frequently used categories are shown first. If the category is missing, "Add category" lets the user create one (name and icon) and continues the entry.
5. Optional details: note, date (defaults to today, can go back to earlier days), wallet (once wallets exist), and a photo of the receipt later.
6. Save. A confirmation appears with Undo for 5 seconds.
7. After saving, the app updates Home (safe to spend), the category budget bar, and the plan check. A reminder is sent only when the category is slightly ahead or off track.

Editing and fixing mistakes:

- Tap an entry in the Transactions list to edit amount, category, note, or date.
- Swipe to delete (with Undo).
- Duplicate an entry for things bought often ("repeat last").
- Editing or deleting recalculates budgets, safe to spend, and plan check.

Helpers for speed:

- Frequent categories on top, last used category remembered for the same note.
- Note suggestions from earlier notes (for example "coffee").
- Works fully offline, saves in under a second.
- Income uses the same screen with income categories (salary, bonus, other).
- Idea, not decided: a one-line typed entry such as "coffee 2.5" that fills the form for the user to confirm.

## 3b. Offline, online, sync and household

Sign-in:

- Guest mode: no login, everything stays on the phone.
- Optional Google sign-in: adds cloud backup, sync across phones, and household sharing.
- Guest to signed-in: existing local data is uploaded after sign-in.
- Guests see a gentle reminder: "Sign in to back up your data."

Sync flow (Supabase, local database is the main copy):

1. Every entry is saved on the phone first, even when online, so saving is always instant.
2. If signed in and online, upload starts immediately.
3. If offline (or the upload fails), the entry is marked "waiting to sync" (draft) with a small badge.
4. When internet returns, or the app opens, waiting entries upload in the background and retry on failure.
5. Newer edit wins when two phones change the same entry. Deletes are synced.
6. Status shown to the user: Saved on phone, Waiting to sync, Syncing, Synced.

Online saving does not depend on a household: every signed-in user's data is saved online (personal backup and sync across their own phones), whether or not they are in a household. A household is an optional layer on top. Each row has an owner (user) and an optional household; row level security allows access to the owner, or to members of the row's household. A user who is not signed in (guest) is saved on the phone only.

Decision: when a user joins a household, all of their existing entries are shared with the household (share everything). Before joining, the app shows a clear confirmation: "Joining shares all your entries, plan, and goals with this household." On leaving, the user keeps a copy of their own entries; the remaining members keep what was shared (to be confirmed).

Household sharing (version 1):

- Needs sign-in. The owner creates a household and invites by code or link; the partner joins with Google sign-in.
- Household members see the same entries, plan, budgets, goals, and plan check. Each entry shows who added it.
- Supabase row level security: a user can only read rows of households they belong to.
- Decided: everything is shared (no private entries in version 1); one household plan using the combined income; no member limit.
- Members: owner and members. The owner can create invite codes (which expire), remove a member, and rename the household. If the owner leaves, ownership passes to the longest-standing member. If the last member leaves, the household is deleted.
- Leaving a household (proposed): the household keeps all shared entries, so its budgets and reports do not change, and each entry still shows who added it. The leaving person gets a copy of the entries they added, plus a copy of the household plan as their personal plan, and continues alone. Leaving asks for confirmation.

Backend: Supabase free plan. Note that free projects pause after 7 days of inactivity; the app keeps working offline and shows a clear message.

## 4. Plan templates (starting points, not advice)

| Plan | Split | Notes |
|---|---|---|
| 50/30/20 | Needs 50, Wants 30, Savings 20 | Best-known rule. Default. |
| 70/20/10 | Living 70, Savings 20, Giving or debt 10 | Good for people with debt or family support. |
| 80/20 | Spending 80, Savings 20 | Pay yourself first, fewest categories. |
| Custom | Start from zero | User builds the plan. |

Example at income $2,000 with 50/30/20: Needs $1,000 (housing $440, food $280, transport $140, bills $140), Wants $600, Savings $400.

Note: 50% for needs does not fit everyone. At setup the app can ask "What do rent and food cost per month?" and suggest 70/20/10 or Custom if needs are above 50%. Show a line saying these are common starting points and can be changed.

## 5. Plan tracking and reminders

For each category:

- Expected by today = monthly budget x (day of month / days in month).
- On track: spent is at or below expected.
- Slightly ahead: up to 15% above expected (amber).
- Off track: more than 15% above expected (red).
- Over budget: the whole monthly budget is used.

The summary shows the effect on savings ("At this pace you would save $196 instead of $400") and a "Safe to spend today" number (remaining flexible budget divided by days left).

Reminders (all local notifications, work offline):

| Trigger | Example |
|---|---|
| Category slightly ahead or off track | "Shopping: $192 of $240 used on day 12. $48 left, about $2 per day." |
| Category reaches 80% and 100% | "Food is at 80% of its budget." |
| Nothing recorded today | Daily at 9 pm: "Did you record today's spending?" |
| Savings not set aside | "Move $400 to your savings goal." |
| End of month | Short summary of budgets kept and money saved. |

Rules: at most one warning per category per day and two per day overall; user chooses the reminder time and can turn each type off; fixed bills like rent are not judged as off track; tone is supportive, never blaming.

## 6. Gemini scan and import (version 2)

- User pastes their own Gemini key in Settings, with a Test key button. The key is stored in secure storage (Keychain or Keystore). Calls go directly from the phone to Gemini, so there is no server and no cost to us.
- Photo flow: take or pick photo, resize, ask Gemini for JSON only (date, amount, currency, type, category, note, confidence) using the user's category list.
- Excel/CSV flow: read the file on the phone, send only the header and a few sample rows to Gemini to find the columns, apply that mapping in code, then send only descriptions in batches to be categorized. Save the mapping per bank.
- Always show a review screen: edit items, yellow flag for low confidence, duplicates skipped, then Save.
- Corrections become local rules (for example "GRAB" becomes Transport) so the next time needs no AI call.
- Privacy: tell the user that images and rows go to Google under their key; send as little as possible and never account numbers.
- Free keys have rate limits, so batching and local rules matter. Keep the model name in one setting because model names change.

## 7. Screens

1. Home
2. Quick add
3. Transactions
4. Plan: choose plan, edit, use this plan
5. Plan check (tracking)
6. Budgets and savings goals
7. Settings: currency, language, reminders, backup, Gemini key
8. Scan review and Import (version 2)

Navigation: four tabs (Home, Transactions, Plan/Goals, Reports) plus a central + button.

## 8. How it stands out from popular apps

Compared with YNAB, Goodbudget, EveryDollar, PocketGuard, Rocket Money, Lunch Money, Finny and Monefy:

- Plan chosen from simple templates, with live "Left to assign" check.
- Daily on-track warning with the effect on savings.
- AI scan and import using the user's own key, no subscription.
- Recurring transactions, backup and export (the most common missing features in reviews).
- No ads, offline first.

## 9. Still to decide

1. Who is the app for: you and your wife only, or published for everyone?
2. Platform: Android only, or Android and iPhone?
3. Language(s) for version 1.
4. Currency: one or several?
5. Data: phone only, or shared between you and your wife?
6. Wallets (cash, bank, e-wallet) in version 1 or later?
7. Monetization: free, paid, or optional extras?
8. PIN or fingerprint lock in version 1?
9. Project folder for the Flutter app.
