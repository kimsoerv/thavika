import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Thavika'**
  String get appName;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabTransactions.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabTransactions;

  /// No description provided for @tabPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get tabPlan;

  /// No description provided for @balanceThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Balance this month'**
  String get balanceThisMonth;

  /// No description provided for @homeBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get homeBalance;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spent;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @spendingByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get spendingByCategory;

  /// No description provided for @noEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Start your first entry'**
  String get noEntriesTitle;

  /// No description provided for @noEntriesBody.
  ///
  /// In en, this message translates to:
  /// **'Tap + to note an expense or income.'**
  String get noEntriesBody;

  /// No description provided for @addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addTitle;

  /// No description provided for @editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editTitle;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get noteHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount first'**
  String get amountRequired;

  /// No description provided for @categoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get categoryRequired;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @categoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get categoryNameRequired;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @entrySaved.
  ///
  /// In en, this message translates to:
  /// **'Entry saved'**
  String get entrySaved;

  /// No description provided for @entryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Entry deleted'**
  String get entryDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @swipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left to delete, tap to edit.'**
  String get swipeHint;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No entries match.'**
  String get noMatches;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @otherSlice.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherSlice;

  /// No description provided for @catHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get catHousing;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get catTransport;

  /// No description provided for @catBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get catBills;

  /// No description provided for @catHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get catHealth;

  /// No description provided for @catFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get catFamily;

  /// No description provided for @catShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @catFun.
  ///
  /// In en, this message translates to:
  /// **'Fun'**
  String get catFun;

  /// No description provided for @catPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get catPersonal;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @catSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get catSalary;

  /// No description provided for @catBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get catBonus;

  /// No description provided for @catOtherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get catOtherIncome;

  /// No description provided for @groupNeeds.
  ///
  /// In en, this message translates to:
  /// **'Needs'**
  String get groupNeeds;

  /// No description provided for @groupWants.
  ///
  /// In en, this message translates to:
  /// **'Wants'**
  String get groupWants;

  /// No description provided for @groupSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get groupSavings;

  /// No description provided for @groupGiving.
  ///
  /// In en, this message translates to:
  /// **'Giving and debt'**
  String get groupGiving;

  /// No description provided for @groupSpending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get groupSpending;

  /// No description provided for @itemEmergencyFund.
  ///
  /// In en, this message translates to:
  /// **'Emergency fund'**
  String get itemEmergencyFund;

  /// No description provided for @itemGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get itemGoals;

  /// No description provided for @itemGiving.
  ///
  /// In en, this message translates to:
  /// **'Giving'**
  String get itemGiving;

  /// No description provided for @itemDebtPayment.
  ///
  /// In en, this message translates to:
  /// **'Debt payment'**
  String get itemDebtPayment;

  /// No description provided for @tplBalanced.
  ///
  /// In en, this message translates to:
  /// **'50 / 30 / 20'**
  String get tplBalanced;

  /// No description provided for @tplBalancedHint.
  ///
  /// In en, this message translates to:
  /// **'Best known'**
  String get tplBalancedHint;

  /// No description provided for @tplSeventy.
  ///
  /// In en, this message translates to:
  /// **'70 / 20 / 10'**
  String get tplSeventy;

  /// No description provided for @tplSeventyHint.
  ///
  /// In en, this message translates to:
  /// **'Adds giving or debt'**
  String get tplSeventyHint;

  /// No description provided for @tplEighty.
  ///
  /// In en, this message translates to:
  /// **'80 / 20'**
  String get tplEighty;

  /// No description provided for @tplEightyHint.
  ///
  /// In en, this message translates to:
  /// **'Save first, simple'**
  String get tplEightyHint;

  /// No description provided for @tplCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get tplCustom;

  /// No description provided for @tplCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Start from zero'**
  String get tplCustomHint;

  /// No description provided for @planSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your plan'**
  String get planSetupTitle;

  /// No description provided for @planEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit your plan'**
  String get planEditTitle;

  /// No description provided for @planIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly income after tax'**
  String get planIncomeLabel;

  /// No description provided for @planIncomeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your monthly income first'**
  String get planIncomeRequired;

  /// No description provided for @planIncomeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your income to see the amounts.'**
  String get planIncomeHint;

  /// No description provided for @planGuidance.
  ///
  /// In en, this message translates to:
  /// **'These are common starting points, not advice. Change them to fit your life.'**
  String get planGuidance;

  /// No description provided for @planEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get planEdit;

  /// No description provided for @planDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planDone;

  /// No description provided for @planReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get planReset;

  /// No description provided for @planUse.
  ///
  /// In en, this message translates to:
  /// **'Use this plan'**
  String get planUse;

  /// No description provided for @planYourCategories.
  ///
  /// In en, this message translates to:
  /// **'Your categories'**
  String get planYourCategories;

  /// No description provided for @planLeftToAssign.
  ///
  /// In en, this message translates to:
  /// **'Left to assign: {amount}'**
  String planLeftToAssign(String amount);

  /// No description provided for @planOverIncome.
  ///
  /// In en, this message translates to:
  /// **'Over your income by {amount}'**
  String planOverIncome(String amount);

  /// No description provided for @planEveryDollar.
  ///
  /// In en, this message translates to:
  /// **'Every dollar has a job'**
  String get planEveryDollar;

  /// No description provided for @planYouWillSave.
  ///
  /// In en, this message translates to:
  /// **'You will save'**
  String get planYouWillSave;

  /// No description provided for @planPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} per month'**
  String planPerMonth(String amount);

  /// No description provided for @planIn12Months.
  ///
  /// In en, this message translates to:
  /// **'{amount} in 12 months'**
  String planIn12Months(String amount);

  /// No description provided for @planAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to {group}'**
  String planAddTo(String group);

  /// No description provided for @planItemName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get planItemName;

  /// No description provided for @planItemNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name or pick a category'**
  String get planItemNameRequired;

  /// No description provided for @planLinkCategory.
  ///
  /// In en, this message translates to:
  /// **'Check spending against a category'**
  String get planLinkCategory;

  /// No description provided for @planNoTracking.
  ///
  /// In en, this message translates to:
  /// **'Not tracked'**
  String get planNoTracking;

  /// No description provided for @planFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get planFixed;

  /// No description provided for @planEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Make a plan'**
  String get planEmptyTitle;

  /// No description provided for @planEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a plan and Thavika will tell you if your spending is on track.'**
  String get planEmptyBody;

  /// No description provided for @planChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get planChoose;

  /// No description provided for @planChange.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get planChange;

  /// No description provided for @checkTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan check'**
  String get checkTitle;

  /// No description provided for @checkDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Last day of the month} =1{1 day left} other{{days} days left}}'**
  String checkDaysLeft(int days);

  /// No description provided for @checkOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get checkOnTrack;

  /// No description provided for @checkSlightlyAhead.
  ///
  /// In en, this message translates to:
  /// **'Slightly ahead'**
  String get checkSlightlyAhead;

  /// No description provided for @checkOffTrack.
  ///
  /// In en, this message translates to:
  /// **'Off track'**
  String get checkOffTrack;

  /// No description provided for @checkOver.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get checkOver;

  /// No description provided for @checkSummaryOn.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get checkSummaryOn;

  /// No description provided for @checkSummaryMostly.
  ///
  /// In en, this message translates to:
  /// **'Mostly on track'**
  String get checkSummaryMostly;

  /// No description provided for @checkSummaryOff.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Off track in 1 category} other{Off track in {count} categories}}'**
  String checkSummaryOff(int count);

  /// No description provided for @checkSavingEstimate.
  ///
  /// In en, this message translates to:
  /// **'At this pace you would save {amount} instead of {planned}.'**
  String checkSavingEstimate(String amount, String planned);

  /// No description provided for @checkSavingOnPlan.
  ///
  /// In en, this message translates to:
  /// **'You are on pace to save {planned} this month.'**
  String checkSavingOnPlan(String planned);

  /// No description provided for @checkSafeToSpend.
  ///
  /// In en, this message translates to:
  /// **'Safe to spend today'**
  String get checkSafeToSpend;

  /// No description provided for @checkPaceLine.
  ///
  /// In en, this message translates to:
  /// **'Black line = where you should be today'**
  String get checkPaceLine;

  /// No description provided for @checkPlannedSaving.
  ///
  /// In en, this message translates to:
  /// **'Planned saving'**
  String get checkPlannedSaving;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTitle;

  /// No description provided for @remindersDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get remindersDaily;

  /// No description provided for @remindersTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get remindersTime;

  /// No description provided for @remindersDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Thavika. Turn them on in your phone settings to get reminders.'**
  String get remindersDenied;

  /// No description provided for @notifDailyBody.
  ///
  /// In en, this message translates to:
  /// **'Did you record today\'s spending?'**
  String get notifDailyBody;

  /// No description provided for @notifPaceBody.
  ///
  /// In en, this message translates to:
  /// **'{category}: {spent} of {budget} used. {left} left, about {perDay} per day.'**
  String notifPaceBody(
    String category,
    String spent,
    String budget,
    String left,
    String perDay,
  );

  /// No description provided for @notifNearLimitBody.
  ///
  /// In en, this message translates to:
  /// **'{category} is at 80% of its budget.'**
  String notifNearLimitBody(String category);

  /// No description provided for @notifOverBody.
  ///
  /// In en, this message translates to:
  /// **'{category} is over budget by {amount}.'**
  String notifOverBody(String category, String amount);

  /// No description provided for @tabReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get tabReports;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings goals'**
  String get goalsTitle;

  /// No description provided for @goalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Set a goal like a new phone or an emergency fund.'**
  String get goalsEmpty;

  /// No description provided for @goalNew.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get goalNew;

  /// No description provided for @goalEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get goalEdit;

  /// No description provided for @goalName.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get goalName;

  /// No description provided for @goalNameHint.
  ///
  /// In en, this message translates to:
  /// **'New phone'**
  String get goalNameHint;

  /// No description provided for @goalNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the goal'**
  String get goalNameRequired;

  /// No description provided for @goalTarget.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get goalTarget;

  /// No description provided for @goalTargetRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a target amount'**
  String get goalTargetRequired;

  /// No description provided for @goalTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Target date (optional)'**
  String get goalTargetDate;

  /// No description provided for @goalNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get goalNoDate;

  /// No description provided for @goalSavedOf.
  ///
  /// In en, this message translates to:
  /// **'{saved} of {target}'**
  String goalSavedOf(String saved, String target);

  /// No description provided for @goalRemaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} to go'**
  String goalRemaining(String amount);

  /// No description provided for @goalPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Save {amount} per month'**
  String goalPerMonth(String amount);

  /// No description provided for @goalDueBy.
  ///
  /// In en, this message translates to:
  /// **'By {date}'**
  String goalDueBy(String date);

  /// No description provided for @goalOverdue.
  ///
  /// In en, this message translates to:
  /// **'The target date has passed'**
  String get goalOverdue;

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get goalReached;

  /// No description provided for @goalAddMoney.
  ///
  /// In en, this message translates to:
  /// **'Add money'**
  String get goalAddMoney;

  /// No description provided for @goalAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get goalAmountRequired;

  /// No description provided for @goalHistory.
  ///
  /// In en, this message translates to:
  /// **'Savings so far'**
  String get goalHistory;

  /// No description provided for @goalNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No money added yet.'**
  String get goalNoHistory;

  /// No description provided for @goalDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this goal?'**
  String get goalDeleteTitle;

  /// No description provided for @goalDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its savings history will be removed too.'**
  String get goalDeleteBody;

  /// No description provided for @recurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring entries'**
  String get recurringTitle;

  /// No description provided for @recurringEmpty.
  ///
  /// In en, this message translates to:
  /// **'Salary, rent, and subscriptions can repeat by themselves.'**
  String get recurringEmpty;

  /// No description provided for @recurringNew.
  ///
  /// In en, this message translates to:
  /// **'New recurring entry'**
  String get recurringNew;

  /// No description provided for @recurringEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring entry'**
  String get recurringEdit;

  /// No description provided for @recurringAdd.
  ///
  /// In en, this message translates to:
  /// **'Add recurring entry'**
  String get recurringAdd;

  /// No description provided for @recurringNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {date}'**
  String recurringNext(String date);

  /// No description provided for @recurringFirstDate.
  ///
  /// In en, this message translates to:
  /// **'First date'**
  String get recurringFirstDate;

  /// No description provided for @recurringFrequency.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get recurringFrequency;

  /// No description provided for @frequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get frequencyWeekly;

  /// No description provided for @frequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get frequencyMonthly;

  /// No description provided for @recurringActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get recurringActive;

  /// No description provided for @recurringAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get recurringAmount;

  /// No description provided for @recurringDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this recurring entry?'**
  String get recurringDeleteTitle;

  /// No description provided for @recurringDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Entries already created stay in your list.'**
  String get recurringDeleteBody;

  /// No description provided for @recurringPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recurringPaused;

  /// No description provided for @reportLeftOver.
  ///
  /// In en, this message translates to:
  /// **'Left over'**
  String get reportLeftOver;

  /// No description provided for @reportNoSpending.
  ///
  /// In en, this message translates to:
  /// **'No spending this month.'**
  String get reportNoSpending;

  /// No description provided for @reportLess.
  ///
  /// In en, this message translates to:
  /// **'Spent {amount} less than last month'**
  String reportLess(String amount);

  /// No description provided for @reportMore.
  ///
  /// In en, this message translates to:
  /// **'Spent {amount} more than last month'**
  String reportMore(String amount);

  /// No description provided for @reportSame.
  ///
  /// In en, this message translates to:
  /// **'Spent the same as last month'**
  String get reportSame;

  /// No description provided for @reportNoLast.
  ///
  /// In en, this message translates to:
  /// **'No entries last month to compare with.'**
  String get reportNoLast;

  /// No description provided for @reportExportMonth.
  ///
  /// In en, this message translates to:
  /// **'Export this month (CSV)'**
  String get reportExportMonth;

  /// No description provided for @settingsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// No description provided for @settingsCurrencyLocked.
  ///
  /// In en, this message translates to:
  /// **'Can\'t change after you add entries or a plan.'**
  String get settingsCurrencyLocked;

  /// No description provided for @settingsRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring entries'**
  String get settingsRecurring;

  /// No description provided for @settingsExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export all entries (CSV)'**
  String get settingsExportCsv;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Back up your data'**
  String get settingsBackup;

  /// No description provided for @settingsBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Saves everything to one file you can keep in Drive or send to yourself.'**
  String get settingsBackupHint;

  /// No description provided for @settingsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get settingsRestore;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsData;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Thavika'**
  String get settingsAbout;

  /// No description provided for @settingsAboutBody.
  ///
  /// In en, this message translates to:
  /// **'Notes your spending, plans your month, and helps you save.'**
  String get settingsAboutBody;

  /// No description provided for @nothingToExport.
  ///
  /// In en, this message translates to:
  /// **'There are no entries to export yet.'**
  String get nothingToExport;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace your data?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Everything on this phone will be replaced by the backup. This can\'t be undone.'**
  String get restoreConfirmBody;

  /// No description provided for @restoreAction.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get restoreAction;

  /// No description provided for @restoreDone.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get restoreDone;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t a Thavika backup.'**
  String get restoreFailed;

  /// No description provided for @sheetShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the share sheet.'**
  String get sheetShareFailed;

  /// No description provided for @entryQuickHint.
  ///
  /// In en, this message translates to:
  /// **'Type it: coffee 2.5'**
  String get entryQuickHint;

  /// No description provided for @entryQuickApply.
  ///
  /// In en, this message translates to:
  /// **'Fill the form'**
  String get entryQuickApply;

  /// No description provided for @entryRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get entryRepeat;

  /// No description provided for @entryWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get entryWallet;

  /// No description provided for @entryChooseWallet.
  ///
  /// In en, this message translates to:
  /// **'Choose a wallet'**
  String get entryChooseWallet;

  /// No description provided for @entryTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get entryTags;

  /// No description provided for @entryTagsNone.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Type a name to create one.'**
  String get entryTagsNone;

  /// No description provided for @entryNewTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get entryNewTag;

  /// No description provided for @entryAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get entryAddTag;

  /// No description provided for @entryReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get entryReceipt;

  /// No description provided for @entryReceiptTake.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get entryReceiptTake;

  /// No description provided for @entryReceiptChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose from photos'**
  String get entryReceiptChoose;

  /// No description provided for @entryReceiptRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the photo'**
  String get entryReceiptRemove;

  /// No description provided for @entrySplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get entrySplit;

  /// No description provided for @entryDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get entryDetails;

  /// No description provided for @saveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save expense'**
  String get saveExpense;

  /// No description provided for @saveIncome.
  ///
  /// In en, this message translates to:
  /// **'Save income'**
  String get saveIncome;

  /// No description provided for @entrySplitTitle.
  ///
  /// In en, this message translates to:
  /// **'Split between categories'**
  String get entrySplitTitle;

  /// No description provided for @entrySplitAddPart.
  ///
  /// In en, this message translates to:
  /// **'Add a part'**
  String get entrySplitAddPart;

  /// No description provided for @entrySplitPickCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get entrySplitPickCategory;

  /// No description provided for @entrySplitLeft.
  ///
  /// In en, this message translates to:
  /// **'Left to assign: {amount}'**
  String entrySplitLeft(String amount);

  /// No description provided for @entrySplitOver.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String entrySplitOver(String amount);

  /// No description provided for @entrySplitDone.
  ///
  /// In en, this message translates to:
  /// **'Every part is assigned'**
  String get entrySplitDone;

  /// No description provided for @entrySplitIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Give every part a category and an amount'**
  String get entrySplitIncomplete;

  /// No description provided for @entrySplitMismatch.
  ///
  /// In en, this message translates to:
  /// **'The parts must add up to the total'**
  String get entrySplitMismatch;

  /// No description provided for @entrySplitNeedAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the total amount first'**
  String get entrySplitNeedAmount;

  /// No description provided for @entryDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Entry copied to today'**
  String get entryDuplicated;

  /// No description provided for @entryDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Copy to today'**
  String get entryDuplicate;

  /// No description provided for @settingsWallets.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get settingsWallets;

  /// No description provided for @settingsTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get settingsTags;

  /// No description provided for @walletsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get walletsTitle;

  /// No description provided for @walletsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total in your wallets'**
  String get walletsTotal;

  /// No description provided for @walletNew.
  ///
  /// In en, this message translates to:
  /// **'New wallet'**
  String get walletNew;

  /// No description provided for @walletEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit wallet'**
  String get walletEdit;

  /// No description provided for @walletName.
  ///
  /// In en, this message translates to:
  /// **'Wallet name'**
  String get walletName;

  /// No description provided for @walletNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get walletNameRequired;

  /// No description provided for @walletKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get walletKind;

  /// No description provided for @walletKindCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get walletKindCash;

  /// No description provided for @walletKindBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get walletKindBank;

  /// No description provided for @walletKindEwallet.
  ///
  /// In en, this message translates to:
  /// **'E-wallet'**
  String get walletKindEwallet;

  /// No description provided for @walletKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get walletKindOther;

  /// No description provided for @walletStarting.
  ///
  /// In en, this message translates to:
  /// **'Money in it at the start'**
  String get walletStarting;

  /// No description provided for @walletArchive.
  ///
  /// In en, this message translates to:
  /// **'Hide this wallet'**
  String get walletArchive;

  /// No description provided for @walletArchived.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get walletArchived;

  /// No description provided for @walletDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this wallet?'**
  String get walletDeleteTitle;

  /// No description provided for @walletDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its entries move to the wallet you pick.'**
  String get walletDeleteBody;

  /// No description provided for @walletMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move entries to'**
  String get walletMoveTo;

  /// No description provided for @walletOnlyOne.
  ///
  /// In en, this message translates to:
  /// **'You need at least one wallet.'**
  String get walletOnlyOne;

  /// No description provided for @walletMoveMoney.
  ///
  /// In en, this message translates to:
  /// **'Move money'**
  String get walletMoveMoney;

  /// No description provided for @walletNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Add a second wallet to move money between wallets.'**
  String get walletNeedTwo;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Move money'**
  String get transferTitle;

  /// No description provided for @transferEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get transferEdit;

  /// No description provided for @transferFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transferFrom;

  /// No description provided for @transferTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transferTo;

  /// No description provided for @transferSame.
  ///
  /// In en, this message translates to:
  /// **'Pick two different wallets'**
  String get transferSame;

  /// No description provided for @transferAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get transferAmountRequired;

  /// No description provided for @transferRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent transfers'**
  String get transferRecent;

  /// No description provided for @transferNone.
  ///
  /// In en, this message translates to:
  /// **'No transfers yet.'**
  String get transferNone;

  /// No description provided for @transferLine.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String transferLine(String from, String to);

  /// No description provided for @transferDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transfer deleted'**
  String get transferDeleted;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @tagsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tags group entries, like #trip or #wedding.'**
  String get tagsEmpty;

  /// No description provided for @tagNew.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get tagNew;

  /// No description provided for @tagRename.
  ///
  /// In en, this message translates to:
  /// **'Rename tag'**
  String get tagRename;

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagName;

  /// No description provided for @tagDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this tag?'**
  String get tagDeleteTitle;

  /// No description provided for @tagDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It is removed from every entry.'**
  String get tagDeleteBody;

  /// No description provided for @filterWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get filterWallet;

  /// No description provided for @filterTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get filterTag;

  /// No description provided for @filterAnyWallet.
  ///
  /// In en, this message translates to:
  /// **'All wallets'**
  String get filterAnyWallet;

  /// No description provided for @filterAnyTag.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get filterAnyTag;

  /// No description provided for @homeWallets.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get homeWallets;

  /// No description provided for @entryVoiceStart.
  ///
  /// In en, this message translates to:
  /// **'Speak your entry'**
  String get entryVoiceStart;

  /// No description provided for @entryVoiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get entryVoiceStop;

  /// No description provided for @entryVoiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get entryVoiceListening;

  /// No description provided for @entryVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input isn\'t available. Check the microphone and speech permissions.'**
  String get entryVoiceUnavailable;

  /// No description provided for @settingsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategories;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoryBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built in'**
  String get categoryBuiltIn;

  /// No description provided for @categoryEntries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No entries} =1{1 entry} other{{count} entries}}'**
  String categoryEntries(int count);

  /// No description provided for @categoryEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get categoryEdit;

  /// No description provided for @categoryShowInAdd.
  ///
  /// In en, this message translates to:
  /// **'Show when adding'**
  String get categoryShowInAdd;

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this category?'**
  String get categoryDeleteTitle;

  /// No description provided for @categoryDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Entries, repeats and plan lines in it move to the category you pick.'**
  String get categoryDeleteBody;

  /// No description provided for @categoryMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move them to'**
  String get categoryMoveTo;

  /// No description provided for @categoryNone.
  ///
  /// In en, this message translates to:
  /// **'No categories here.'**
  String get categoryNone;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Phone language'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKhmer.
  ///
  /// In en, this message translates to:
  /// **'ខ្មែរ'**
  String get languageKhmer;

  /// No description provided for @setupWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Thavika'**
  String get setupWelcomeTitle;

  /// No description provided for @setupWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A minute of setup, then you are ready. You can change everything later.'**
  String get setupWelcomeBody;

  /// No description provided for @setupStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String setupStepOf(int step, int total);

  /// No description provided for @setupCurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Which currency do you use?'**
  String get setupCurrencyTitle;

  /// No description provided for @setupCurrencyBody.
  ///
  /// In en, this message translates to:
  /// **'You cannot change this after you add your first entry.'**
  String get setupCurrencyBody;

  /// No description provided for @setupWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'How much money do you have now?'**
  String get setupWalletTitle;

  /// No description provided for @setupWalletBody.
  ///
  /// In en, this message translates to:
  /// **'Cash and bank together. A rough number is fine. You can add more wallets later.'**
  String get setupWalletBody;

  /// No description provided for @setupIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your monthly money'**
  String get setupIncomeTitle;

  /// No description provided for @setupRentLabel.
  ///
  /// In en, this message translates to:
  /// **'Rent or housing per month'**
  String get setupRentLabel;

  /// No description provided for @setupFoodLabel.
  ///
  /// In en, this message translates to:
  /// **'Food per month'**
  String get setupFoodLabel;

  /// No description provided for @setupCostsHint.
  ///
  /// In en, this message translates to:
  /// **'Leave out what you do not know. We will use typical amounts.'**
  String get setupCostsHint;

  /// No description provided for @setupAdviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Which plan fits you?'**
  String get setupAdviceTitle;

  /// No description provided for @setupShareLine.
  ///
  /// In en, this message translates to:
  /// **'Rent and food are {percent}% of your income.'**
  String setupShareLine(int percent);

  /// No description provided for @setupAdviceBalanced.
  ///
  /// In en, this message translates to:
  /// **'That leaves room for wants and savings, so 50 / 30 / 20 fits you.'**
  String get setupAdviceBalanced;

  /// No description provided for @setupAdviceSeventy.
  ///
  /// In en, this message translates to:
  /// **'That is a big part of your income, so 70 / 20 / 10 is more realistic.'**
  String get setupAdviceSeventy;

  /// No description provided for @setupAdviceCustom.
  ///
  /// In en, this message translates to:
  /// **'That takes most of your income. Start with your own plan and add what you can.'**
  String get setupAdviceCustom;

  /// No description provided for @setupRecommended.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get setupRecommended;

  /// No description provided for @setupNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get setupNext;

  /// No description provided for @setupBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get setupBack;

  /// No description provided for @setupFinish.
  ///
  /// In en, this message translates to:
  /// **'Create my plan'**
  String get setupFinish;

  /// No description provided for @setupSkipPlan.
  ///
  /// In en, this message translates to:
  /// **'Start without a plan'**
  String get setupSkipPlan;

  /// No description provided for @settingsLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsLock;

  /// No description provided for @lockStatusOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get lockStatusOn;

  /// No description provided for @lockStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get lockStatusOff;

  /// No description provided for @lockChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get lockChangePin;

  /// No description provided for @lockUseBiometric.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint or face'**
  String get lockUseBiometric;

  /// No description provided for @lockTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off app lock'**
  String get lockTurnOff;

  /// No description provided for @lockEnterCurrent.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN'**
  String get lockEnterCurrent;

  /// No description provided for @lockEnterNew.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4-digit PIN'**
  String get lockEnterNew;

  /// No description provided for @lockConfirmNew.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN again'**
  String get lockConfirmNew;

  /// No description provided for @lockMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs do not match. Try again.'**
  String get lockMismatch;

  /// No description provided for @lockWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get lockWrong;

  /// No description provided for @lockWait.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again in {seconds} s.'**
  String lockWait(int seconds);

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Thavika is locked'**
  String get lockTitle;

  /// No description provided for @lockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get lockEnterPin;

  /// No description provided for @lockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Thavika'**
  String get lockBiometricReason;

  /// No description provided for @lockBiometricButton.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face'**
  String get lockBiometricButton;

  /// No description provided for @lockForgotWarning.
  ///
  /// In en, this message translates to:
  /// **'If you forget your PIN, you cannot open the app. Make a backup first.'**
  String get lockForgotWarning;

  /// No description provided for @lockIsOn.
  ///
  /// In en, this message translates to:
  /// **'App lock is on'**
  String get lockIsOn;

  /// No description provided for @lockIsOff.
  ///
  /// In en, this message translates to:
  /// **'App lock is off'**
  String get lockIsOff;

  /// No description provided for @notifSavingsBody.
  ///
  /// In en, this message translates to:
  /// **'You planned to save {amount} this month. Time to move it to your goals?'**
  String notifSavingsBody(String amount);

  /// No description provided for @notifSavingsGeneric.
  ///
  /// In en, this message translates to:
  /// **'Time to move this month\'s savings to your goals.'**
  String get notifSavingsGeneric;

  /// No description provided for @notifMonthEndBody.
  ///
  /// In en, this message translates to:
  /// **'The month is ending. Open Thavika to see how it went.'**
  String get notifMonthEndBody;

  /// No description provided for @notifBillBody.
  ///
  /// In en, this message translates to:
  /// **'{name}: {amount} is due on {date}.'**
  String notifBillBody(String name, String amount, String date);

  /// No description provided for @remindersDailyHint.
  ///
  /// In en, this message translates to:
  /// **'Only when you have not recorded anything that day'**
  String get remindersDailyHint;

  /// No description provided for @remindersSavings.
  ///
  /// In en, this message translates to:
  /// **'Move your savings'**
  String get remindersSavings;

  /// No description provided for @remindersSavingsHint.
  ///
  /// In en, this message translates to:
  /// **'On the 5th and 20th, if the planned saving is not moved yet'**
  String get remindersSavingsHint;

  /// No description provided for @remindersMonthEnd.
  ///
  /// In en, this message translates to:
  /// **'End of month'**
  String get remindersMonthEnd;

  /// No description provided for @remindersMonthEndHint.
  ///
  /// In en, this message translates to:
  /// **'An evening reminder on the last day of the month'**
  String get remindersMonthEndHint;

  /// No description provided for @remindersBills.
  ///
  /// In en, this message translates to:
  /// **'Bills due'**
  String get remindersBills;

  /// No description provided for @remindersBillsHint.
  ///
  /// In en, this message translates to:
  /// **'For recurring entries you mark as a bill'**
  String get remindersBillsHint;

  /// No description provided for @remindersWarnings.
  ///
  /// In en, this message translates to:
  /// **'Spending warnings'**
  String get remindersWarnings;

  /// No description provided for @remindersWarningsHint.
  ///
  /// In en, this message translates to:
  /// **'When a category goes off the plan, at most 2 a day'**
  String get remindersWarningsHint;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @recurringIsBill.
  ///
  /// In en, this message translates to:
  /// **'This is a bill'**
  String get recurringIsBill;

  /// No description provided for @recurringIsBillHint.
  ///
  /// In en, this message translates to:
  /// **'Remind me before it is due'**
  String get recurringIsBillHint;

  /// No description provided for @recurringRemindDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Remind me on the day} =1{Remind me 1 day before} other{Remind me {days} days before}}'**
  String recurringRemindDays(int days);

  /// No description provided for @payFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay yourself first'**
  String get payFirstTitle;

  /// No description provided for @payFirstBody.
  ///
  /// In en, this message translates to:
  /// **'You added {income}. Your plan says to set aside {amount} for your goals.'**
  String payFirstBody(String income, String amount);

  /// No description provided for @payFirstGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get payFirstGoal;

  /// No description provided for @payFirstSet.
  ///
  /// In en, this message translates to:
  /// **'Set aside'**
  String get payFirstSet;

  /// No description provided for @payFirstSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get payFirstSkip;

  /// No description provided for @planGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals first'**
  String get planGoalsTitle;

  /// No description provided for @planGoalsBody.
  ///
  /// In en, this message translates to:
  /// **'Your goals need {amount} a month, {percent}% of your income.'**
  String planGoalsBody(String amount, int percent);

  /// No description provided for @planGoalsFit.
  ///
  /// In en, this message translates to:
  /// **'Fit my plan to my goals'**
  String get planGoalsFit;

  /// No description provided for @planGoalsHigh.
  ///
  /// In en, this message translates to:
  /// **'That is a lot. Moving the date of a goal makes it lighter.'**
  String get planGoalsHigh;

  /// No description provided for @planNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan name (optional)'**
  String get planNameLabel;

  /// No description provided for @adviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust to real life'**
  String get adviceTitle;

  /// No description provided for @adviceBody.
  ///
  /// In en, this message translates to:
  /// **'Your last months ran differently from the plan. These moves would fit it better:'**
  String get adviceBody;

  /// No description provided for @adviceMove.
  ///
  /// In en, this message translates to:
  /// **'Move {amount} from {from} to {to}'**
  String adviceMove(String amount, String from, String to);

  /// No description provided for @adviceApply.
  ///
  /// In en, this message translates to:
  /// **'Update my plan'**
  String get adviceApply;

  /// No description provided for @adviceDismiss.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get adviceDismiss;

  /// No description provided for @advicePlanUpdated.
  ///
  /// In en, this message translates to:
  /// **'Plan updated'**
  String get advicePlanUpdated;

  /// No description provided for @plansTitle.
  ///
  /// In en, this message translates to:
  /// **'My plans'**
  String get plansTitle;

  /// No description provided for @plansSaveCurrent.
  ///
  /// In en, this message translates to:
  /// **'Save this plan as...'**
  String get plansSaveCurrent;

  /// No description provided for @plansNameHint.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get plansNameHint;

  /// No description provided for @plansEmpty.
  ///
  /// In en, this message translates to:
  /// **'Save your plan with a name to switch back to it later, for example for a month with less income.'**
  String get plansEmpty;

  /// No description provided for @plansUse.
  ///
  /// In en, this message translates to:
  /// **'Use for this month'**
  String get plansUse;

  /// No description provided for @plansUseBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" becomes your plan from this month on. Earlier months keep their plan.'**
  String plansUseBody(String name);

  /// No description provided for @plansDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this saved plan?'**
  String get plansDeleteTitle;

  /// No description provided for @plansDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Your current plan is not changed.'**
  String get plansDeleteBody;

  /// No description provided for @plansSaved.
  ///
  /// In en, this message translates to:
  /// **'Plan saved'**
  String get plansSaved;

  /// No description provided for @plansSwitched.
  ///
  /// In en, this message translates to:
  /// **'Plan changed'**
  String get plansSwitched;

  /// No description provided for @plansIncome.
  ///
  /// In en, this message translates to:
  /// **'Income {amount}'**
  String plansIncome(String amount);

  /// No description provided for @planUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get planUnnamed;

  /// No description provided for @billsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bills and subscriptions'**
  String get billsTitle;

  /// No description provided for @billsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add rent, internet, phone or a subscription and Thavika reminds you before it is due.'**
  String get billsEmpty;

  /// No description provided for @billsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a bill'**
  String get billsAdd;

  /// No description provided for @billsMonthly.
  ///
  /// In en, this message translates to:
  /// **'About {amount} a month'**
  String billsMonthly(String amount);

  /// No description provided for @billDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get billDueToday;

  /// No description provided for @billDueIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Due tomorrow} other{Due in {days} days}}'**
  String billDueIn(int days);

  /// No description provided for @billOverdue.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day overdue} other{{days} days overdue}}'**
  String billOverdue(int days);

  /// No description provided for @billMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark paid'**
  String get billMarkPaid;

  /// No description provided for @billPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'How much did you pay?'**
  String get billPaidTitle;

  /// No description provided for @billPaidDone.
  ///
  /// In en, this message translates to:
  /// **'Marked as paid'**
  String get billPaidDone;

  /// No description provided for @recurringAutoCreate.
  ///
  /// In en, this message translates to:
  /// **'Add the entry by itself on the due date'**
  String get recurringAutoCreate;

  /// No description provided for @recurringAutoCreateOff.
  ///
  /// In en, this message translates to:
  /// **'Off: I mark it paid myself, good for bills that change'**
  String get recurringAutoCreateOff;

  /// No description provided for @challengeStart.
  ///
  /// In en, this message translates to:
  /// **'Start a saving challenge'**
  String get challengeStart;

  /// No description provided for @challengeKindStepUp.
  ///
  /// In en, this message translates to:
  /// **'Step up: week 1 saves 1 unit, week 2 saves 2, week 3 saves 3...'**
  String get challengeKindStepUp;

  /// No description provided for @challengeKindFixed.
  ///
  /// In en, this message translates to:
  /// **'Same amount every week'**
  String get challengeKindFixed;

  /// No description provided for @challengeUnit.
  ///
  /// In en, this message translates to:
  /// **'Amount of one unit'**
  String get challengeUnit;

  /// No description provided for @challengeWeeks.
  ///
  /// In en, this message translates to:
  /// **'Number of weeks'**
  String get challengeWeeks;

  /// No description provided for @challengeTotalHint.
  ///
  /// In en, this message translates to:
  /// **'In total this saves {amount}.'**
  String challengeTotalHint(String amount);

  /// No description provided for @challengeCreate.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get challengeCreate;

  /// No description provided for @challengeStepUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Step-up challenge'**
  String get challengeStepUpTitle;

  /// No description provided for @challengeFixedTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly challenge'**
  String get challengeFixedTitle;

  /// No description provided for @challengeStreak.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =0{No streak yet} =1{1 week in a row} other{{weeks} weeks in a row}}'**
  String challengeStreak(int weeks);

  /// No description provided for @challengeBehind.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{1 week behind} other{{weeks} weeks behind}}'**
  String challengeBehind(int weeks);

  /// No description provided for @challengeDone.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} weeks done'**
  String challengeDone(int done, int total);

  /// No description provided for @challengeStepTip.
  ///
  /// In en, this message translates to:
  /// **'Week {week}: {amount}'**
  String challengeStepTip(int week, String amount);

  /// No description provided for @challengeStop.
  ///
  /// In en, this message translates to:
  /// **'Stop this challenge'**
  String get challengeStop;

  /// No description provided for @challengeStopBody.
  ///
  /// In en, this message translates to:
  /// **'The money already saved stays in your goal.'**
  String get challengeStopBody;

  /// No description provided for @debtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Debts and money lent'**
  String get debtsTitle;

  /// No description provided for @debtsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Note money you lent or money you owe, and mark it paid back little by little.'**
  String get debtsEmpty;

  /// No description provided for @debtAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a debt'**
  String get debtAdd;

  /// No description provided for @debtEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit debt'**
  String get debtEditTitle;

  /// No description provided for @debtOwedToMe.
  ///
  /// In en, this message translates to:
  /// **'Owed to you'**
  String get debtOwedToMe;

  /// No description provided for @debtIOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get debtIOwe;

  /// No description provided for @debtLent.
  ///
  /// In en, this message translates to:
  /// **'I lent money'**
  String get debtLent;

  /// No description provided for @debtBorrowed.
  ///
  /// In en, this message translates to:
  /// **'I borrowed money'**
  String get debtBorrowed;

  /// No description provided for @debtPerson.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get debtPerson;

  /// No description provided for @debtPersonRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get debtPersonRequired;

  /// No description provided for @debtAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get debtAmount;

  /// No description provided for @debtStarted.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get debtStarted;

  /// No description provided for @debtDue.
  ///
  /// In en, this message translates to:
  /// **'Due date (optional)'**
  String get debtDue;

  /// No description provided for @debtNoDue.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get debtNoDue;

  /// No description provided for @debtLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String debtLeft(String amount);

  /// No description provided for @debtPaidOf.
  ///
  /// In en, this message translates to:
  /// **'{paid} of {total} paid back'**
  String debtPaidOf(String paid, String total);

  /// No description provided for @debtSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get debtSettled;

  /// No description provided for @debtOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get debtOverdue;

  /// No description provided for @debtDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String debtDueOn(String date);

  /// No description provided for @debtAddPayment.
  ///
  /// In en, this message translates to:
  /// **'Add a payment'**
  String get debtAddPayment;

  /// No description provided for @debtPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get debtPayments;

  /// No description provided for @debtNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments yet.'**
  String get debtNoPayments;

  /// No description provided for @debtDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this debt?'**
  String get debtDeleteTitle;

  /// No description provided for @debtDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its payments are deleted too, and your wallet goes back to how it was before.'**
  String get debtDeleteBody;

  /// No description provided for @netWorthTitle.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get netWorthTitle;

  /// No description provided for @netWorthWallets.
  ///
  /// In en, this message translates to:
  /// **'In your wallets'**
  String get netWorthWallets;

  /// No description provided for @netWorthGoals.
  ///
  /// In en, this message translates to:
  /// **'Moved to goals'**
  String get netWorthGoals;

  /// No description provided for @netWorthHint.
  ///
  /// In en, this message translates to:
  /// **'Wallets, plus money moved to goals, plus what others owe you, minus what you owe.'**
  String get netWorthHint;

  /// No description provided for @reportDaily.
  ///
  /// In en, this message translates to:
  /// **'Spending per day'**
  String get reportDaily;

  /// No description provided for @reportTrend.
  ///
  /// In en, this message translates to:
  /// **'Last 6 months'**
  String get reportTrend;

  /// No description provided for @reportByWallet.
  ///
  /// In en, this message translates to:
  /// **'By wallet'**
  String get reportByWallet;

  /// No description provided for @reportByTag.
  ///
  /// In en, this message translates to:
  /// **'By tag'**
  String get reportByTag;

  /// No description provided for @reportByTagHint.
  ///
  /// In en, this message translates to:
  /// **'An entry with two tags counts for both.'**
  String get reportByTagHint;

  /// No description provided for @reportExportExcel.
  ///
  /// In en, this message translates to:
  /// **'Export this month (Excel)'**
  String get reportExportExcel;

  /// No description provided for @settingsExportExcel.
  ///
  /// In en, this message translates to:
  /// **'Export all entries (Excel)'**
  String get settingsExportExcel;

  /// No description provided for @reportBusiestDay.
  ///
  /// In en, this message translates to:
  /// **'Most spent on {date}: {amount}'**
  String reportBusiestDay(String date, String amount);

  /// No description provided for @widgetSafeLabel.
  ///
  /// In en, this message translates to:
  /// **'Safe to spend today'**
  String get widgetSafeLabel;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account and sync'**
  String get accountTitle;

  /// No description provided for @accountGuest.
  ///
  /// In en, this message translates to:
  /// **'Using without an account'**
  String get accountGuest;

  /// No description provided for @accountGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this phone. Sign in to back it up and use it on more phones.'**
  String get accountGuestBody;

  /// No description provided for @accountSignInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get accountSignInGoogle;

  /// No description provided for @accountNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Sync is not set up in this version of the app.'**
  String get accountNotConfigured;

  /// No description provided for @accountSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String accountSignedInAs(String email);

  /// No description provided for @syncStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'Everything is saved to your account'**
  String get syncStatusSynced;

  /// No description provided for @syncStatusPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync} other{{count} changes waiting to sync}}'**
  String syncStatusPending(int count);

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet. Changes are saved on the phone and sync later.'**
  String get syncStatusOffline;

  /// No description provided for @syncStatusError.
  ///
  /// In en, this message translates to:
  /// **'Sync problem: {error}'**
  String syncStatusError(String error);

  /// No description provided for @syncLast.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String syncLast(String time);

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this phone. Sync stops until you sign in again.'**
  String get accountSignOutBody;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get accountDelete;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes your account and everything stored in the cloud. The data on this phone stays. This cannot be undone.'**
  String get accountDeleteBody;

  /// No description provided for @accountOtherDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Another account\'s data is on this phone'**
  String get accountOtherDataTitle;

  /// No description provided for @accountOtherDataBody.
  ///
  /// In en, this message translates to:
  /// **'To sign in, that data is removed from this phone. It stays safe in its own account. Continue?'**
  String get accountOtherDataBody;

  /// No description provided for @accountOtherDataContinue.
  ///
  /// In en, this message translates to:
  /// **'Erase and sign in'**
  String get accountOtherDataContinue;

  /// No description provided for @accountAdoptNote.
  ///
  /// In en, this message translates to:
  /// **'Your entries on this phone will be added to your account.'**
  String get accountAdoptNote;

  /// No description provided for @accountSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String accountSignInFailed(String error);

  /// No description provided for @householdTitle.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get householdTitle;

  /// No description provided for @householdSubtitleNone.
  ///
  /// In en, this message translates to:
  /// **'Share with a partner or family'**
  String get householdSubtitleNone;

  /// No description provided for @householdNeedSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to share with someone else.'**
  String get householdNeedSignIn;

  /// No description provided for @householdIntro.
  ///
  /// In en, this message translates to:
  /// **'Share one set of entries, plan and goals with your partner or family. Everyone sees the same numbers.'**
  String get householdIntro;

  /// No description provided for @householdStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a household'**
  String get householdStartTitle;

  /// No description provided for @householdNameHint.
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get householdNameHint;

  /// No description provided for @householdStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get householdStart;

  /// No description provided for @householdStartConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Starting a household shares all your entries, plan and goals with the people you invite.'**
  String get householdStartConfirmBody;

  /// No description provided for @householdJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get householdJoinTitle;

  /// No description provided for @householdCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get householdCodeHint;

  /// No description provided for @householdJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get householdJoin;

  /// No description provided for @householdJoinConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Join this household?'**
  String get householdJoinConfirmTitle;

  /// No description provided for @householdJoinConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Joining shares all your entries, plan and goals with this household. Everyone in it will see them.'**
  String get householdJoinConfirmBody;

  /// No description provided for @householdMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get householdMembers;

  /// No description provided for @householdOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get householdOwner;

  /// No description provided for @householdYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get householdYou;

  /// No description provided for @householdInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get householdInvite;

  /// No description provided for @householdInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code: {code}'**
  String householdInviteCode(String code);

  /// No description provided for @householdInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Give this code to the person. It works for 7 days.'**
  String get householdInviteHint;

  /// No description provided for @householdCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get householdCopy;

  /// No description provided for @householdCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get householdCopied;

  /// No description provided for @householdRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get householdRename;

  /// No description provided for @householdRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get householdRemove;

  /// No description provided for @householdRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String householdRemoveConfirm(String name);

  /// No description provided for @householdRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer see this household. What they added stays here, and they keep a copy of their own entries.'**
  String householdRemoveBody(String name);

  /// No description provided for @householdLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave household'**
  String get householdLeave;

  /// No description provided for @householdLeaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}?'**
  String householdLeaveConfirmTitle(String name);

  /// No description provided for @householdLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You will no longer see the household\'s data. You keep a copy of what you added, and the plan. Everyone else keeps everything.'**
  String get householdLeaveBody;

  /// No description provided for @householdLeaveLast.
  ///
  /// In en, this message translates to:
  /// **'You are the last member. The household will end and everything in it will be yours.'**
  String get householdLeaveLast;

  /// No description provided for @householdErrorCode.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired.'**
  String get householdErrorCode;

  /// No description provided for @householdErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet. Try again when you are online.'**
  String get householdErrorOffline;

  /// No description provided for @householdErrorOwner.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can do that.'**
  String get householdErrorOwner;

  /// No description provided for @householdErrorAlready.
  ///
  /// In en, this message translates to:
  /// **'You are already in a household.'**
  String get householdErrorAlready;

  /// No description provided for @householdErrorOther.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get householdErrorOther;

  /// No description provided for @householdRemovedNotice.
  ///
  /// In en, this message translates to:
  /// **'You are no longer in {name}. A copy of what you added is now in your own data.'**
  String householdRemovedNotice(String name);

  /// No description provided for @householdOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get householdOk;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
