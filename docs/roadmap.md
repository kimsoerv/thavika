# Thavika: full roadmap (everything discussed, released together)

Decision: no feature is dropped. The app is released only when every item below is done.
Legend: [x] built and tested, [~] started, [ ] not started.

## Phase A: finish the offline app

Order matters: data model changes come first, because every new table or column must later be synced.

### A1. Data model upgrade (schema v4) - done
- [x] Wallets (cash, bank, e-wallet) with opening balance and live balances (screens come in A2/A3)
- [x] Transfers between wallets (kept apart from income and spending)
- [x] Tags (many per entry)
- [x] Entry extras in the database: wallet, receipt photo file, split group
- [x] Categories: hidden flag (rename, hide, delete screens come in A3)
- [x] Plan history per month: a new plan only applies from its month on, earlier months keep theirs
- [x] Also prepared: named plans, bills (flag, auto-create, remind days), debts and payments, savings challenges, goal money leaving a wallet
- [x] Upgrade from the old database keeps all data; backups include every table (old backups still restore)

### A2. Entry and daily use - done (see "not checked on a device" in the notes)
- [x] Quick add, edit, delete with Undo, frequent categories first
- [x] Repeat last entries (chips) and copy an entry to today (swipe right)
- [x] Note suggestions from earlier notes
- [x] One-line typed entry ("coffee 2.5", "+salary 2000")
- [x] Voice entry (English first; Khmer needs the phone's Khmer speech support)
- [x] Receipt photo on an entry (stored on the phone)
- [x] Split an entry between categories
- [x] Wallets screen (balances, add, edit, hide, delete with move), transfers, wallet picker on the add screen, wallet row on Home
- [x] Tags: create while adding, tags screen (rename, delete), tag and wallet filters, search by tag and amount

### A3. First run and settings - done (see "not checked on a device" in the notes)
- [x] First-time setup: language, currency, money you have now, monthly income, pick a plan
- [x] Asks "what do rent and food cost?" and suggests 50/30/20, 70/20/10 or Custom (rent + food up to 50% / up to 65% / more); the plan screen opens filled in with those amounts
- [x] Khmer language (draft translations, **need review by a native speaker**) and language switch (Settings, or the first screen)
- [x] PIN lock (4 digits, stored only as a salted hash in the phone's secure storage, waiting time after 5 wrong tries, locks again after 1 minute in the background) and fingerprint / face unlock
- [x] Manage categories, wallets and tags screens
- [x] App icon (placeholder sprout, replace with a designed one before release), splash screen, app name "Thavika" on Android and iPhone

### A4. Plan, tracking, reminders - done (see "not checked on a device" in the notes)
- [x] Four plans, edit mode, budgets, plan check, safe to spend
- [x] Daily reminder and over-pace warnings
- [x] Smart "nothing recorded today" reminder: scheduled for the next 7 days, today's is dropped once an entry exists
- [x] "Move your savings" reminder on the 5th and 20th when the planned saving is not moved to goals yet
- [x] End-of-month notification (a plain "the month is ending" nudge; the full summary screen comes with A6 reports)
- [x] Bill due-date reminders (mark a recurring expense as "a bill" and choose how many days before)
- [x] Turn each reminder type on or off (Settings > Reminders)
- [x] Pay yourself first: after recording income, offers to move the planned saving (its share of that income) to a goal
- [x] Goal-first planning: the plan screen shows what your goals need per month and fits the plan to it
- [x] Adjust to real life: compares the last 1-2 months with the plan and suggests moving budget from lines that run low to lines that run over; one tap applies it
- [x] Named plans: name a plan, save several, switch the plan for this month (earlier months keep theirs)

### A5. Savings, bills, debts - done (see "not checked on a device" in the notes)
- [x] Savings goals with progress and monthly amount
- [x] Savings streaks and challenges: a step-up (52-week style) or same-amount weekly challenge on a goal; tick a week and its money goes into the goal; streak and "weeks behind"
- [x] Bills and subscriptions tracker (Plan tab): due dates, overdue/due soon, monthly total, "Mark paid" with the real amount for bills that change
- [x] Recurring entries
- [x] Debts and money lent (Settings): lent or borrowed, payments, due date, progress; they move the wallet balance (lent takes money out, paying back returns it)
- [x] Net worth view (Settings): wallets + money moved to goals + owed to you - you owe

### A6. Reports and data - done on Android; the iPhone widget is left for Phase E (see below)
- [x] Monthly report, comparison with last month, category bars
- [x] Charts: spending per day, last 6 months income vs spending
- [x] Wallet report (when there is more than one wallet) and tag report
- [x] Excel (.xlsx) export: all entries or one month, with a totals-per-category sheet
- [x] CSV export, JSON backup and restore
- [x] Android home-screen widget: safe to spend today (or the month balance without a plan) and a + button that opens the add screen
- [ ] iPhone widget: needs a WidgetKit extension created in Xcode with an App Group, so it is done together with the Apple developer account in Phase E

## Phase B: online (sign-in and sync)
- [~] Supabase tables, security rules (SQL written, not yet run)
- [ ] Google sign-in (guest mode stays)
- [ ] Sync engine (outbox, push, pull, retry, last write wins), all tables including Phase A ones
- [ ] "Waiting to sync" badge and sync status
- [ ] Guest to signed-in upload, switching accounts safely
- [ ] Delete my account and cloud data
- [ ] Receipt photos in cloud storage (decision needed: phone only, or Supabase storage)

## Phase C: household
- [ ] Create household, invite code or link, join with confirmation
- [ ] Share everything, one household plan with combined income
- [ ] Members screen, owner role, remove member, no member limit
- [ ] Leave household (keep a copy of own entries and the plan)
- [ ] Each entry shows who added it
- [ ] Live updates between phones
- [ ] Instant alerts about a partner's spending (push notifications; needs a small server function)

## Phase D: Gemini (user's own key)
- [ ] Settings: paste key, test key, secure storage
- [ ] Photo scan of handwriting or receipts
- [ ] Excel/CSV import: column mapping, batch categorising, saved bank mappings
- [ ] Review screen: edit, low-confidence flags, duplicate skipping
- [ ] Learning rules from corrections
- [ ] Gemini tips on the plan check (optional)

## Phase E: release
- [ ] Full test pass on Android and iPhone, real devices, dark mode, small screens
- [ ] Performance with thousands of entries
- [ ] Privacy policy and data deletion page, store listings in English and Khmer
- [ ] Android signing and Play Store; iPhone: paid Apple developer account, "Sign in with Apple" if required
- [ ] Trademark and name availability check for "Thavika"

## Things to know
- Voice entry: speech recognition quality in Khmer is not guaranteed; English will work first.
- Home-screen widget needs native code on each platform (Android widget, iPhone WidgetKit), so it is a larger item.
- Instant partner alerts need push notifications: a server function plus Apple/Google push setup.
- Receipt photos make backups and sync bigger; Supabase free storage is 1 GB.
