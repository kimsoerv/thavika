// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Thavika';

  @override
  String get tabHome => 'Home';

  @override
  String get tabTransactions => 'History';

  @override
  String get tabPlan => 'Plan';

  @override
  String get balanceThisMonth => 'Balance this month';

  @override
  String get homeBalance => 'Balance';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get spent => 'Spent';

  @override
  String get recent => 'Recent';

  @override
  String get spendingByCategory => 'Spending by category';

  @override
  String get noEntriesTitle => 'Start your first entry';

  @override
  String get noEntriesBody => 'Tap + to note an expense or income.';

  @override
  String get addTitle => 'Add';

  @override
  String get editTitle => 'Edit entry';

  @override
  String get noteHint => 'Add a note (optional)';

  @override
  String get save => 'Save';

  @override
  String get amountRequired => 'Enter an amount first';

  @override
  String get categoryRequired => 'Pick a category';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get addCategory => 'Add category';

  @override
  String get categoryName => 'Category name';

  @override
  String get categoryNameRequired => 'Enter a name';

  @override
  String get more => 'More';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get search => 'Search';

  @override
  String get all => 'All';

  @override
  String get entrySaved => 'Entry saved';

  @override
  String get entryDeleted => 'Entry deleted';

  @override
  String get undo => 'Undo';

  @override
  String get swipeHint => 'Swipe left to delete, tap to edit.';

  @override
  String get noMatches => 'No entries match.';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get otherSlice => 'Other';

  @override
  String get catHousing => 'Housing';

  @override
  String get catFood => 'Food';

  @override
  String get catTransport => 'Transport';

  @override
  String get catBills => 'Bills';

  @override
  String get catHealth => 'Health';

  @override
  String get catFamily => 'Family';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catFun => 'Fun';

  @override
  String get catPersonal => 'Personal';

  @override
  String get catOther => 'Other';

  @override
  String get catSalary => 'Salary';

  @override
  String get catBonus => 'Bonus';

  @override
  String get catOtherIncome => 'Other income';

  @override
  String get groupNeeds => 'Needs';

  @override
  String get groupWants => 'Wants';

  @override
  String get groupSavings => 'Savings';

  @override
  String get groupGiving => 'Giving and debt';

  @override
  String get groupSpending => 'Spending';

  @override
  String get itemEmergencyFund => 'Emergency fund';

  @override
  String get itemGoals => 'Goals';

  @override
  String get itemGiving => 'Giving';

  @override
  String get itemDebtPayment => 'Debt payment';

  @override
  String get tplBalanced => '50 / 30 / 20';

  @override
  String get tplBalancedHint => 'Best known';

  @override
  String get tplSeventy => '70 / 20 / 10';

  @override
  String get tplSeventyHint => 'Adds giving or debt';

  @override
  String get tplEighty => '80 / 20';

  @override
  String get tplEightyHint => 'Save first, simple';

  @override
  String get tplCustom => 'Custom';

  @override
  String get tplCustomHint => 'Start from zero';

  @override
  String get planSetupTitle => 'Choose your plan';

  @override
  String get planEditTitle => 'Edit your plan';

  @override
  String get planIncomeLabel => 'Monthly income after tax';

  @override
  String get planIncomeRequired => 'Enter your monthly income first';

  @override
  String get planIncomeHint => 'Enter your income to see the amounts.';

  @override
  String get planGuidance =>
      'These are common starting points, not advice. Change them to fit your life.';

  @override
  String get planEdit => 'Edit';

  @override
  String get planDone => 'Done';

  @override
  String get planReset => 'Reset';

  @override
  String get planUse => 'Use this plan';

  @override
  String get planYourCategories => 'Your categories';

  @override
  String planLeftToAssign(String amount) {
    return 'Left to assign: $amount';
  }

  @override
  String planOverIncome(String amount) {
    return 'Over your income by $amount';
  }

  @override
  String get planEveryDollar => 'Every dollar has a job';

  @override
  String get planYouWillSave => 'You will save';

  @override
  String planPerMonth(String amount) {
    return '$amount per month';
  }

  @override
  String planIn12Months(String amount) {
    return '$amount in 12 months';
  }

  @override
  String planAddTo(String group) {
    return 'Add to $group';
  }

  @override
  String get planItemName => 'Name';

  @override
  String get planItemNameRequired => 'Enter a name or pick a category';

  @override
  String get planLinkCategory => 'Check spending against a category';

  @override
  String get planNoTracking => 'Not tracked';

  @override
  String get planFixed => 'Fixed';

  @override
  String get planEmptyTitle => 'Make a plan';

  @override
  String get planEmptyBody =>
      'Pick a plan and Thavika will tell you if your spending is on track.';

  @override
  String get planChoose => 'Choose a plan';

  @override
  String get planChange => 'Edit plan';

  @override
  String get checkTitle => 'Plan check';

  @override
  String checkDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'Last day of the month',
    );
    return '$_temp0';
  }

  @override
  String get checkOnTrack => 'On track';

  @override
  String get checkSlightlyAhead => 'Slightly ahead';

  @override
  String get checkOffTrack => 'Off track';

  @override
  String get checkOver => 'Over budget';

  @override
  String get checkSummaryOn => 'On track';

  @override
  String get checkSummaryMostly => 'Mostly on track';

  @override
  String checkSummaryOff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Off track in $count categories',
      one: 'Off track in 1 category',
    );
    return '$_temp0';
  }

  @override
  String checkSavingEstimate(String amount, String planned) {
    return 'At this pace you would save $amount instead of $planned.';
  }

  @override
  String checkSavingOnPlan(String planned) {
    return 'You are on pace to save $planned this month.';
  }

  @override
  String get checkSafeToSpend => 'Safe to spend today';

  @override
  String get checkPaceLine => 'Black line = where you should be today';

  @override
  String get checkPlannedSaving => 'Planned saving';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersDaily => 'Daily reminder';

  @override
  String get remindersTime => 'Reminder time';

  @override
  String get remindersDenied =>
      'Notifications are off for Thavika. Turn them on in your phone settings to get reminders.';

  @override
  String get notifDailyBody => 'Did you record today\'s spending?';

  @override
  String notifPaceBody(
    String category,
    String spent,
    String budget,
    String left,
    String perDay,
  ) {
    return '$category: $spent of $budget used. $left left, about $perDay per day.';
  }

  @override
  String notifNearLimitBody(String category) {
    return '$category is at 80% of its budget.';
  }

  @override
  String notifOverBody(String category, String amount) {
    return '$category is over budget by $amount.';
  }

  @override
  String get tabReports => 'Reports';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get goalsTitle => 'Savings goals';

  @override
  String get goalsEmpty => 'Set a goal like a new phone or an emergency fund.';

  @override
  String get goalNew => 'New goal';

  @override
  String get goalEdit => 'Edit goal';

  @override
  String get goalName => 'Goal name';

  @override
  String get goalNameHint => 'New phone';

  @override
  String get goalNameRequired => 'Enter a name for the goal';

  @override
  String get goalTarget => 'Target amount';

  @override
  String get goalTargetRequired => 'Enter a target amount';

  @override
  String get goalTargetDate => 'Target date (optional)';

  @override
  String get goalNoDate => 'No date';

  @override
  String goalSavedOf(String saved, String target) {
    return '$saved of $target';
  }

  @override
  String goalRemaining(String amount) {
    return '$amount to go';
  }

  @override
  String goalPerMonth(String amount) {
    return 'Save $amount per month';
  }

  @override
  String goalDueBy(String date) {
    return 'By $date';
  }

  @override
  String get goalOverdue => 'The target date has passed';

  @override
  String get goalReached => 'Goal reached';

  @override
  String get goalAddMoney => 'Add money';

  @override
  String get goalAmountRequired => 'Enter an amount';

  @override
  String get goalHistory => 'Savings so far';

  @override
  String get goalNoHistory => 'No money added yet.';

  @override
  String get goalDeleteTitle => 'Delete this goal?';

  @override
  String get goalDeleteBody => 'Its savings history will be removed too.';

  @override
  String get recurringTitle => 'Recurring entries';

  @override
  String get recurringEmpty =>
      'Salary, rent, and subscriptions can repeat by themselves.';

  @override
  String get recurringNew => 'New recurring entry';

  @override
  String get recurringEdit => 'Edit recurring entry';

  @override
  String get recurringAdd => 'Add recurring entry';

  @override
  String recurringNext(String date) {
    return 'Next: $date';
  }

  @override
  String get recurringFirstDate => 'First date';

  @override
  String get recurringFrequency => 'Repeats';

  @override
  String get frequencyWeekly => 'Weekly';

  @override
  String get frequencyMonthly => 'Monthly';

  @override
  String get recurringActive => 'Active';

  @override
  String get recurringAmount => 'Amount';

  @override
  String get recurringDeleteTitle => 'Delete this recurring entry?';

  @override
  String get recurringDeleteBody =>
      'Entries already created stay in your list.';

  @override
  String get recurringPaused => 'Paused';

  @override
  String get reportLeftOver => 'Left over';

  @override
  String get reportNoSpending => 'No spending this month.';

  @override
  String reportLess(String amount) {
    return 'Spent $amount less than last month';
  }

  @override
  String reportMore(String amount) {
    return 'Spent $amount more than last month';
  }

  @override
  String get reportSame => 'Spent the same as last month';

  @override
  String get reportNoLast => 'No entries last month to compare with.';

  @override
  String get reportExportMonth => 'Export this month (CSV)';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsCurrencyLocked =>
      'Can\'t change after you add entries or a plan.';

  @override
  String get settingsRecurring => 'Recurring entries';

  @override
  String get settingsExportCsv => 'Export all entries (CSV)';

  @override
  String get settingsBackup => 'Back up your data';

  @override
  String get settingsBackupHint =>
      'Saves everything to one file you can keep in Drive or send to yourself.';

  @override
  String get settingsRestore => 'Restore from a backup';

  @override
  String get settingsData => 'Your data';

  @override
  String get settingsAbout => 'About Thavika';

  @override
  String get settingsAboutBody =>
      'Notes your spending, plans your month, and helps you save.';

  @override
  String get nothingToExport => 'There are no entries to export yet.';

  @override
  String get restoreConfirmTitle => 'Replace your data?';

  @override
  String get restoreConfirmBody =>
      'Everything on this phone will be replaced by the backup. This can\'t be undone.';

  @override
  String get restoreAction => 'Replace';

  @override
  String get restoreDone => 'Backup restored';

  @override
  String get restoreFailed => 'That file isn\'t a Thavika backup.';

  @override
  String get sheetShareFailed => 'Couldn\'t open the share sheet.';

  @override
  String get entryQuickHint => 'Type it: coffee 2.5';

  @override
  String get entryQuickApply => 'Fill the form';

  @override
  String get entryRepeat => 'Repeat';

  @override
  String get entryWallet => 'Wallet';

  @override
  String get entryChooseWallet => 'Choose a wallet';

  @override
  String get entryTags => 'Tags';

  @override
  String get entryTagsNone => 'No tags yet. Type a name to create one.';

  @override
  String get entryNewTag => 'New tag';

  @override
  String get entryAddTag => 'Add tag';

  @override
  String get entryReceipt => 'Receipt';

  @override
  String get entryReceiptTake => 'Take a photo';

  @override
  String get entryReceiptChoose => 'Choose from photos';

  @override
  String get entryReceiptRemove => 'Remove the photo';

  @override
  String get entrySplit => 'Split';

  @override
  String get entrySplitTitle => 'Split between categories';

  @override
  String get entrySplitAddPart => 'Add a part';

  @override
  String get entrySplitPickCategory => 'Category';

  @override
  String entrySplitLeft(String amount) {
    return 'Left to assign: $amount';
  }

  @override
  String entrySplitOver(String amount) {
    return 'Over by $amount';
  }

  @override
  String get entrySplitDone => 'Every part is assigned';

  @override
  String get entrySplitIncomplete => 'Give every part a category and an amount';

  @override
  String get entrySplitMismatch => 'The parts must add up to the total';

  @override
  String get entrySplitNeedAmount => 'Enter the total amount first';

  @override
  String get entryDuplicated => 'Entry copied to today';

  @override
  String get entryDuplicate => 'Copy to today';

  @override
  String get settingsWallets => 'Wallets';

  @override
  String get settingsTags => 'Tags';

  @override
  String get walletsTitle => 'Wallets';

  @override
  String get walletsTotal => 'Total in your wallets';

  @override
  String get walletNew => 'New wallet';

  @override
  String get walletEdit => 'Edit wallet';

  @override
  String get walletName => 'Wallet name';

  @override
  String get walletNameRequired => 'Enter a name';

  @override
  String get walletKind => 'Type';

  @override
  String get walletKindCash => 'Cash';

  @override
  String get walletKindBank => 'Bank';

  @override
  String get walletKindEwallet => 'E-wallet';

  @override
  String get walletKindOther => 'Other';

  @override
  String get walletStarting => 'Money in it at the start';

  @override
  String get walletArchive => 'Hide this wallet';

  @override
  String get walletArchived => 'Hidden';

  @override
  String get walletDeleteTitle => 'Delete this wallet?';

  @override
  String get walletDeleteBody => 'Its entries move to the wallet you pick.';

  @override
  String get walletMoveTo => 'Move entries to';

  @override
  String get walletOnlyOne => 'You need at least one wallet.';

  @override
  String get walletMoveMoney => 'Move money';

  @override
  String get walletNeedTwo =>
      'Add a second wallet to move money between wallets.';

  @override
  String get transferTitle => 'Move money';

  @override
  String get transferEdit => 'Edit transfer';

  @override
  String get transferFrom => 'From';

  @override
  String get transferTo => 'To';

  @override
  String get transferSame => 'Pick two different wallets';

  @override
  String get transferAmountRequired => 'Enter an amount';

  @override
  String get transferRecent => 'Recent transfers';

  @override
  String get transferNone => 'No transfers yet.';

  @override
  String transferLine(String from, String to) {
    return '$from to $to';
  }

  @override
  String get transferDeleted => 'Transfer deleted';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get tagsEmpty => 'Tags group entries, like #trip or #wedding.';

  @override
  String get tagNew => 'New tag';

  @override
  String get tagRename => 'Rename tag';

  @override
  String get tagName => 'Tag name';

  @override
  String get tagDeleteTitle => 'Delete this tag?';

  @override
  String get tagDeleteBody => 'It is removed from every entry.';

  @override
  String get filterWallet => 'Wallet';

  @override
  String get filterTag => 'Tag';

  @override
  String get filterAnyWallet => 'All wallets';

  @override
  String get filterAnyTag => 'All tags';

  @override
  String get homeWallets => 'Wallets';

  @override
  String get entryVoiceStart => 'Speak your entry';

  @override
  String get entryVoiceStop => 'Stop listening';

  @override
  String get entryVoiceListening => 'Listening...';

  @override
  String get entryVoiceUnavailable =>
      'Voice input isn\'t available. Check the microphone and speech permissions.';

  @override
  String get settingsCategories => 'Categories';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoryBuiltIn => 'Built in';

  @override
  String categoryEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
      zero: 'No entries',
    );
    return '$_temp0';
  }

  @override
  String get categoryEdit => 'Edit category';

  @override
  String get categoryShowInAdd => 'Show when adding';

  @override
  String get categoryDeleteTitle => 'Delete this category?';

  @override
  String get categoryDeleteBody =>
      'Entries, repeats and plan lines in it move to the category you pick.';

  @override
  String get categoryMoveTo => 'Move them to';

  @override
  String get categoryNone => 'No categories here.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'Phone language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKhmer => 'ខ្មែរ';

  @override
  String get setupWelcomeTitle => 'Welcome to Thavika';

  @override
  String get setupWelcomeBody =>
      'A minute of setup, then you are ready. You can change everything later.';

  @override
  String setupStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get setupCurrencyTitle => 'Which currency do you use?';

  @override
  String get setupCurrencyBody =>
      'You cannot change this after you add your first entry.';

  @override
  String get setupWalletTitle => 'How much money do you have now?';

  @override
  String get setupWalletBody =>
      'Cash and bank together. A rough number is fine. You can add more wallets later.';

  @override
  String get setupIncomeTitle => 'Your monthly money';

  @override
  String get setupRentLabel => 'Rent or housing per month';

  @override
  String get setupFoodLabel => 'Food per month';

  @override
  String get setupCostsHint =>
      'Leave out what you do not know. We will use typical amounts.';

  @override
  String get setupAdviceTitle => 'Which plan fits you?';

  @override
  String setupShareLine(int percent) {
    return 'Rent and food are $percent% of your income.';
  }

  @override
  String get setupAdviceBalanced =>
      'That leaves room for wants and savings, so 50 / 30 / 20 fits you.';

  @override
  String get setupAdviceSeventy =>
      'That is a big part of your income, so 70 / 20 / 10 is more realistic.';

  @override
  String get setupAdviceCustom =>
      'That takes most of your income. Start with your own plan and add what you can.';

  @override
  String get setupRecommended => 'Suggested';

  @override
  String get setupNext => 'Next';

  @override
  String get setupBack => 'Back';

  @override
  String get setupFinish => 'Create my plan';

  @override
  String get setupSkipPlan => 'Start without a plan';

  @override
  String get settingsLock => 'App lock';

  @override
  String get lockStatusOn => 'On';

  @override
  String get lockStatusOff => 'Off';

  @override
  String get lockChangePin => 'Change PIN';

  @override
  String get lockUseBiometric => 'Unlock with fingerprint or face';

  @override
  String get lockTurnOff => 'Turn off app lock';

  @override
  String get lockEnterCurrent => 'Enter your current PIN';

  @override
  String get lockEnterNew => 'Choose a 4-digit PIN';

  @override
  String get lockConfirmNew => 'Enter the PIN again';

  @override
  String get lockMismatch => 'The PINs do not match. Try again.';

  @override
  String get lockWrong => 'Wrong PIN';

  @override
  String lockWait(int seconds) {
    return 'Too many tries. Try again in $seconds s.';
  }

  @override
  String get lockTitle => 'Thavika is locked';

  @override
  String get lockEnterPin => 'Enter your PIN';

  @override
  String get lockBiometricReason => 'Unlock Thavika';

  @override
  String get lockBiometricButton => 'Use fingerprint or face';

  @override
  String get lockForgotWarning =>
      'If you forget your PIN, you cannot open the app. Make a backup first.';

  @override
  String get lockIsOn => 'App lock is on';

  @override
  String get lockIsOff => 'App lock is off';

  @override
  String notifSavingsBody(String amount) {
    return 'You planned to save $amount this month. Time to move it to your goals?';
  }

  @override
  String get notifSavingsGeneric =>
      'Time to move this month\'s savings to your goals.';

  @override
  String get notifMonthEndBody =>
      'The month is ending. Open Thavika to see how it went.';

  @override
  String notifBillBody(String name, String amount, String date) {
    return '$name: $amount is due on $date.';
  }

  @override
  String get remindersDailyHint =>
      'Only when you have not recorded anything that day';

  @override
  String get remindersSavings => 'Move your savings';

  @override
  String get remindersSavingsHint =>
      'On the 5th and 20th, if the planned saving is not moved yet';

  @override
  String get remindersMonthEnd => 'End of month';

  @override
  String get remindersMonthEndHint =>
      'An evening reminder on the last day of the month';

  @override
  String get remindersBills => 'Bills due';

  @override
  String get remindersBillsHint => 'For recurring entries you mark as a bill';

  @override
  String get remindersWarnings => 'Spending warnings';

  @override
  String get remindersWarningsHint =>
      'When a category goes off the plan, at most 2 a day';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get recurringIsBill => 'This is a bill';

  @override
  String get recurringIsBillHint => 'Remind me before it is due';

  @override
  String recurringRemindDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Remind me $days days before',
      one: 'Remind me 1 day before',
      zero: 'Remind me on the day',
    );
    return '$_temp0';
  }

  @override
  String get payFirstTitle => 'Pay yourself first';

  @override
  String payFirstBody(String income, String amount) {
    return 'You added $income. Your plan says to set aside $amount for your goals.';
  }

  @override
  String get payFirstGoal => 'Goal';

  @override
  String get payFirstSet => 'Set aside';

  @override
  String get payFirstSkip => 'Not now';

  @override
  String get planGoalsTitle => 'Goals first';

  @override
  String planGoalsBody(String amount, int percent) {
    return 'Your goals need $amount a month, $percent% of your income.';
  }

  @override
  String get planGoalsFit => 'Fit my plan to my goals';

  @override
  String get planGoalsHigh =>
      'That is a lot. Moving the date of a goal makes it lighter.';

  @override
  String get planNameLabel => 'Plan name (optional)';

  @override
  String get adviceTitle => 'Adjust to real life';

  @override
  String get adviceBody =>
      'Your last months ran differently from the plan. These moves would fit it better:';

  @override
  String adviceMove(String amount, String from, String to) {
    return 'Move $amount from $from to $to';
  }

  @override
  String get adviceApply => 'Update my plan';

  @override
  String get adviceDismiss => 'Not now';

  @override
  String get advicePlanUpdated => 'Plan updated';

  @override
  String get plansTitle => 'My plans';

  @override
  String get plansSaveCurrent => 'Save this plan as...';

  @override
  String get plansNameHint => 'Plan name';

  @override
  String get plansEmpty =>
      'Save your plan with a name to switch back to it later, for example for a month with less income.';

  @override
  String get plansUse => 'Use for this month';

  @override
  String plansUseBody(String name) {
    return '\"$name\" becomes your plan from this month on. Earlier months keep their plan.';
  }

  @override
  String get plansDeleteTitle => 'Delete this saved plan?';

  @override
  String get plansDeleteBody => 'Your current plan is not changed.';

  @override
  String get plansSaved => 'Plan saved';

  @override
  String get plansSwitched => 'Plan changed';

  @override
  String plansIncome(String amount) {
    return 'Income $amount';
  }

  @override
  String get planUnnamed => 'Your plan';

  @override
  String get billsTitle => 'Bills and subscriptions';

  @override
  String get billsEmpty =>
      'Add rent, internet, phone or a subscription and Thavika reminds you before it is due.';

  @override
  String get billsAdd => 'Add a bill';

  @override
  String billsMonthly(String amount) {
    return 'About $amount a month';
  }

  @override
  String get billDueToday => 'Due today';

  @override
  String billDueIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Due in $days days',
      one: 'Due tomorrow',
    );
    return '$_temp0';
  }

  @override
  String billOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String get billMarkPaid => 'Mark paid';

  @override
  String get billPaidTitle => 'How much did you pay?';

  @override
  String get billPaidDone => 'Marked as paid';

  @override
  String get recurringAutoCreate => 'Add the entry by itself on the due date';

  @override
  String get recurringAutoCreateOff =>
      'Off: I mark it paid myself, good for bills that change';

  @override
  String get challengeStart => 'Start a saving challenge';

  @override
  String get challengeKindStepUp =>
      'Step up: week 1 saves 1 unit, week 2 saves 2, week 3 saves 3...';

  @override
  String get challengeKindFixed => 'Same amount every week';

  @override
  String get challengeUnit => 'Amount of one unit';

  @override
  String get challengeWeeks => 'Number of weeks';

  @override
  String challengeTotalHint(String amount) {
    return 'In total this saves $amount.';
  }

  @override
  String get challengeCreate => 'Start';

  @override
  String get challengeStepUpTitle => 'Step-up challenge';

  @override
  String get challengeFixedTitle => 'Weekly challenge';

  @override
  String challengeStreak(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks in a row',
      one: '1 week in a row',
      zero: 'No streak yet',
    );
    return '$_temp0';
  }

  @override
  String challengeBehind(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks behind',
      one: '1 week behind',
    );
    return '$_temp0';
  }

  @override
  String challengeDone(int done, int total) {
    return '$done of $total weeks done';
  }

  @override
  String challengeStepTip(int week, String amount) {
    return 'Week $week: $amount';
  }

  @override
  String get challengeStop => 'Stop this challenge';

  @override
  String get challengeStopBody => 'The money already saved stays in your goal.';

  @override
  String get debtsTitle => 'Debts and money lent';

  @override
  String get debtsEmpty =>
      'Note money you lent or money you owe, and mark it paid back little by little.';

  @override
  String get debtAdd => 'Add a debt';

  @override
  String get debtEditTitle => 'Edit debt';

  @override
  String get debtOwedToMe => 'Owed to you';

  @override
  String get debtIOwe => 'You owe';

  @override
  String get debtLent => 'I lent money';

  @override
  String get debtBorrowed => 'I borrowed money';

  @override
  String get debtPerson => 'Who';

  @override
  String get debtPersonRequired => 'Enter a name';

  @override
  String get debtAmount => 'Amount';

  @override
  String get debtStarted => 'Date';

  @override
  String get debtDue => 'Due date (optional)';

  @override
  String get debtNoDue => 'No due date';

  @override
  String debtLeft(String amount) {
    return '$amount left';
  }

  @override
  String debtPaidOf(String paid, String total) {
    return '$paid of $total paid back';
  }

  @override
  String get debtSettled => 'Settled';

  @override
  String get debtOverdue => 'Overdue';

  @override
  String debtDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get debtAddPayment => 'Add a payment';

  @override
  String get debtPayments => 'Payments';

  @override
  String get debtNoPayments => 'No payments yet.';

  @override
  String get debtDeleteTitle => 'Delete this debt?';

  @override
  String get debtDeleteBody =>
      'Its payments are deleted too, and your wallet goes back to how it was before.';

  @override
  String get netWorthTitle => 'Net worth';

  @override
  String get netWorthWallets => 'In your wallets';

  @override
  String get netWorthGoals => 'Moved to goals';

  @override
  String get netWorthHint =>
      'Wallets, plus money moved to goals, plus what others owe you, minus what you owe.';

  @override
  String get reportDaily => 'Spending per day';

  @override
  String get reportTrend => 'Last 6 months';

  @override
  String get reportByWallet => 'By wallet';

  @override
  String get reportByTag => 'By tag';

  @override
  String get reportByTagHint => 'An entry with two tags counts for both.';

  @override
  String get reportExportExcel => 'Export this month (Excel)';

  @override
  String get settingsExportExcel => 'Export all entries (Excel)';

  @override
  String reportBusiestDay(String date, String amount) {
    return 'Most spent on $date: $amount';
  }

  @override
  String get widgetSafeLabel => 'Safe to spend today';

  @override
  String get accountTitle => 'Account and sync';

  @override
  String get accountGuest => 'Using without an account';

  @override
  String get accountGuestBody =>
      'Your data stays on this phone. Sign in to back it up and use it on more phones.';

  @override
  String get accountSignInGoogle => 'Sign in with Google';

  @override
  String get accountNotConfigured =>
      'Sync is not set up in this version of the app.';

  @override
  String accountSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get syncStatusSynced => 'Everything is saved to your account';

  @override
  String syncStatusPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get syncStatusSyncing => 'Syncing...';

  @override
  String get syncStatusOffline =>
      'No internet. Changes are saved on the phone and sync later.';

  @override
  String syncStatusError(String error) {
    return 'Sync problem: $error';
  }

  @override
  String syncLast(String time) {
    return 'Last synced $time';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutBody =>
      'Your data stays on this phone. Sync stops until you sign in again.';

  @override
  String get accountDelete => 'Delete my account';

  @override
  String get accountDeleteBody =>
      'This deletes your account and everything stored in the cloud. The data on this phone stays. This cannot be undone.';

  @override
  String get accountOtherDataTitle =>
      'Another account\'s data is on this phone';

  @override
  String get accountOtherDataBody =>
      'To sign in, that data is removed from this phone. It stays safe in its own account. Continue?';

  @override
  String get accountOtherDataContinue => 'Erase and sign in';

  @override
  String get accountAdoptNote =>
      'Your entries on this phone will be added to your account.';

  @override
  String accountSignInFailed(String error) {
    return 'Sign-in failed: $error';
  }
}
