import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PHA — Personal Health Assistant'**
  String get appTitle;

  /// No description provided for @appNameShort.
  ///
  /// In en, this message translates to:
  /// **'PHA'**
  String get appNameShort;

  /// No description provided for @personalHealthAssistant.
  ///
  /// In en, this message translates to:
  /// **'Personal Health Assistant'**
  String get personalHealthAssistant;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your health, our priority'**
  String get tagline;

  /// No description provided for @taglineBody.
  ///
  /// In en, this message translates to:
  /// **'Track, analyze and improve your health with PHA. Your data stays private and secure.'**
  String get taglineBody;

  /// No description provided for @startingPha.
  ///
  /// In en, this message translates to:
  /// **'Starting PHA…'**
  String get startingPha;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @startupFailed.
  ///
  /// In en, this message translates to:
  /// **'Startup failed'**
  String get startupFailed;

  /// No description provided for @noContent.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get noContent;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

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

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noDataYet;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @healthIndex.
  ///
  /// In en, this message translates to:
  /// **'Health Index'**
  String get healthIndex;

  /// No description provided for @healthMetrics.
  ///
  /// In en, this message translates to:
  /// **'Health Metrics'**
  String get healthMetrics;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @activeTime.
  ///
  /// In en, this message translates to:
  /// **'Active Time'**
  String get activeTime;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @bloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose'**
  String get bloodGlucose;

  /// No description provided for @bloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get bloodPressure;

  /// No description provided for @bpSystolic.
  ///
  /// In en, this message translates to:
  /// **'BP Systolic'**
  String get bpSystolic;

  /// No description provided for @bpDiastolic.
  ///
  /// In en, this message translates to:
  /// **'BP Diastolic'**
  String get bpDiastolic;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @chooseLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Profile.'**
  String get chooseLanguageSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'普通话'**
  String get languageChinese;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signUpForFree.
  ///
  /// In en, this message translates to:
  /// **'Sign up for free'**
  String get signUpForFree;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get dontHaveAccount;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @agreement.
  ///
  /// In en, this message translates to:
  /// **'Agreement'**
  String get agreement;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @acceptAgreement.
  ///
  /// In en, this message translates to:
  /// **'I accept the Agreement'**
  String get acceptAgreement;

  /// No description provided for @acceptPrivacy.
  ///
  /// In en, this message translates to:
  /// **'I accept the Privacy Policy'**
  String get acceptPrivacy;

  /// No description provided for @pleaseAcceptLegal.
  ///
  /// In en, this message translates to:
  /// **'Please read and accept the Agreement and Privacy Policy to continue.'**
  String get pleaseAcceptLegal;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordTooShort;

  /// No description provided for @featureTrackVitals.
  ///
  /// In en, this message translates to:
  /// **'Track vitals & glucose'**
  String get featureTrackVitals;

  /// No description provided for @featureAiInsights.
  ///
  /// In en, this message translates to:
  /// **'AI health insights'**
  String get featureAiInsights;

  /// No description provided for @featureSmartAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Smart analysis'**
  String get featureSmartAnalysis;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account settings'**
  String get profileSubtitle;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Health History'**
  String get historyTitle;

  /// No description provided for @historySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your recorded health metrics over time'**
  String get historySubtitle;

  /// No description provided for @stepsChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get stepsChartTitle;

  /// No description provided for @stepsAvgPerDay.
  ///
  /// In en, this message translates to:
  /// **'Avg {avg}/day'**
  String stepsAvgPerDay(String avg);

  /// No description provided for @days7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get days7;

  /// No description provided for @days30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get days30;

  /// No description provided for @days90.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get days90;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @recordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String recordsCount(int count);

  /// No description provided for @recordCountOne.
  ///
  /// In en, this message translates to:
  /// **'1 record'**
  String get recordCountOne;

  /// No description provided for @noMetricsYet.
  ///
  /// In en, this message translates to:
  /// **'No metrics recorded yet'**
  String get noMetricsYet;

  /// No description provided for @noMetricsHint.
  ///
  /// In en, this message translates to:
  /// **'Use the Log button on the dashboard to start tracking your health.'**
  String get noMetricsHint;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Insights'**
  String get insightsTitle;

  /// No description provided for @insightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trends and patterns from your health data'**
  String get insightsSubtitle;

  /// No description provided for @avgHealthIndex.
  ///
  /// In en, this message translates to:
  /// **'Avg Health Index'**
  String get avgHealthIndex;

  /// No description provided for @avgWellnessScore.
  ///
  /// In en, this message translates to:
  /// **'Avg Wellness Score'**
  String get avgWellnessScore;

  /// No description provided for @stepTrend.
  ///
  /// In en, this message translates to:
  /// **'Step Trend'**
  String get stepTrend;

  /// No description provided for @healthIndexHistory.
  ///
  /// In en, this message translates to:
  /// **'Health Index History'**
  String get healthIndexHistory;

  /// No description provided for @wellnessCheckHistory.
  ///
  /// In en, this message translates to:
  /// **'Wellness Check History'**
  String get wellnessCheckHistory;

  /// No description provided for @stepActivity.
  ///
  /// In en, this message translates to:
  /// **'Step Activity'**
  String get stepActivity;

  /// No description provided for @lastNDays.
  ///
  /// In en, this message translates to:
  /// **'Last {count} days'**
  String lastNDays(int count);

  /// No description provided for @minLabel.
  ///
  /// In en, this message translates to:
  /// **'Min: {value}'**
  String minLabel(String value);

  /// No description provided for @avgLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg: {value}'**
  String avgLabel(String value);

  /// No description provided for @maxLabel.
  ///
  /// In en, this message translates to:
  /// **'Max: {value}'**
  String maxLabel(String value);

  /// No description provided for @noInsightsYet.
  ///
  /// In en, this message translates to:
  /// **'No insights yet'**
  String get noInsightsYet;

  /// No description provided for @noInsightsHint.
  ///
  /// In en, this message translates to:
  /// **'Start tracking your health metrics and completing wellness checks to see insights here.'**
  String get noInsightsHint;

  /// No description provided for @noHealthIndexYet.
  ///
  /// In en, this message translates to:
  /// **'No health index data recorded yet'**
  String get noHealthIndexYet;

  /// No description provided for @noWellnessYet.
  ///
  /// In en, this message translates to:
  /// **'No wellness checks yet. Try the Wellness Check on the home screen.'**
  String get noWellnessYet;

  /// No description provided for @healthAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Health Analysis'**
  String get healthAnalysis;

  /// No description provided for @healthAnalysisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Same score as Health Index, with findings & advice'**
  String get healthAnalysisSubtitle;

  /// No description provided for @analyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get analyze;

  /// No description provided for @reAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Re-analyze'**
  String get reAnalyze;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get analyzing;

  /// No description provided for @noAnalysisYet.
  ///
  /// In en, this message translates to:
  /// **'No analysis yet. Press Analyze to get a personalized health conclusion based on your logged metrics.'**
  String get noAnalysisYet;

  /// No description provided for @metricFindings.
  ///
  /// In en, this message translates to:
  /// **'Metric Findings'**
  String get metricFindings;

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// No description provided for @lastAnalyzed.
  ///
  /// In en, this message translates to:
  /// **'Last analyzed: {when}'**
  String lastAnalyzed(String when);

  /// No description provided for @statusExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get statusExcellent;

  /// No description provided for @statusGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get statusGood;

  /// No description provided for @statusFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get statusFair;

  /// No description provided for @statusNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get statusNeedsAttention;

  /// No description provided for @actionUploadAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Upload Analysis'**
  String get actionUploadAnalysis;

  /// No description provided for @actionUploadAnalysisDesc.
  ///
  /// In en, this message translates to:
  /// **'Analyze PDFs or photos'**
  String get actionUploadAnalysisDesc;

  /// No description provided for @actionAiConsultation.
  ///
  /// In en, this message translates to:
  /// **'AI Consultation'**
  String get actionAiConsultation;

  /// No description provided for @actionAiConsultationDesc.
  ///
  /// In en, this message translates to:
  /// **'Chat with Ai Doc'**
  String get actionAiConsultationDesc;

  /// No description provided for @actionWellnessCheck.
  ///
  /// In en, this message translates to:
  /// **'Wellness Check'**
  String get actionWellnessCheck;

  /// No description provided for @actionWellnessCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'Check your wellbeing'**
  String get actionWellnessCheckDesc;

  /// No description provided for @actionBadHabits.
  ///
  /// In en, this message translates to:
  /// **'Check Your Bad Habits'**
  String get actionBadHabits;

  /// No description provided for @actionBadHabitsDesc.
  ///
  /// In en, this message translates to:
  /// **'Smoking, alcohol & screen time'**
  String get actionBadHabitsDesc;

  /// No description provided for @actionPhysicalActivity.
  ///
  /// In en, this message translates to:
  /// **'Start physical activity'**
  String get actionPhysicalActivity;

  /// No description provided for @actionPhysicalActivityDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose your daily workout program'**
  String get actionPhysicalActivityDesc;

  /// No description provided for @actionMealCalories.
  ///
  /// In en, this message translates to:
  /// **'Check Meal Calories'**
  String get actionMealCalories;

  /// No description provided for @actionMealCaloriesDesc.
  ///
  /// In en, this message translates to:
  /// **'Photo → calories & nutrition advice'**
  String get actionMealCaloriesDesc;

  /// No description provided for @actionPsychoTest.
  ///
  /// In en, this message translates to:
  /// **'PsychoTest'**
  String get actionPsychoTest;

  /// No description provided for @actionPsychoTestDesc.
  ///
  /// In en, this message translates to:
  /// **'Stress & psychosomatic assessment'**
  String get actionPsychoTestDesc;

  /// No description provided for @actionTreatmentSchedule.
  ///
  /// In en, this message translates to:
  /// **'Treatment Schedule'**
  String get actionTreatmentSchedule;

  /// No description provided for @actionTreatmentScheduleDesc.
  ///
  /// In en, this message translates to:
  /// **'Medicines & supplements reminders'**
  String get actionTreatmentScheduleDesc;

  /// No description provided for @actionFamilyHealth.
  ///
  /// In en, this message translates to:
  /// **'Family Health Tracking'**
  String get actionFamilyHealth;

  /// No description provided for @actionFamilyHealthDesc.
  ///
  /// In en, this message translates to:
  /// **'Add your family to track their health'**
  String get actionFamilyHealthDesc;

  /// No description provided for @logMetric.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get logMetric;

  /// No description provided for @todayVitals.
  ///
  /// In en, this message translates to:
  /// **'Today\'s vitals'**
  String get todayVitals;

  /// No description provided for @onboardingQuest1TitleBefore.
  ///
  /// In en, this message translates to:
  /// **'Quest 1: Choose your world'**
  String get onboardingQuest1TitleBefore;

  /// No description provided for @onboardingQuest1TitleAfter.
  ///
  /// In en, this message translates to:
  /// **'Pick your units'**
  String get onboardingQuest1TitleAfter;

  /// No description provided for @onboardingQuest1BodyBefore.
  ///
  /// In en, this message translates to:
  /// **'Start your health journey — 3 quick quests, then sign up.'**
  String get onboardingQuest1BodyBefore;

  /// No description provided for @onboardingQuest1BodyAfter.
  ///
  /// In en, this message translates to:
  /// **'Tailor charts and tips to your region.'**
  String get onboardingQuest1BodyAfter;

  /// No description provided for @onboardingQuest1CardTitle.
  ///
  /// In en, this message translates to:
  /// **'Quest 1 · Measurement realm'**
  String get onboardingQuest1CardTitle;

  /// No description provided for @onboardingQuest1CardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock charts in your language'**
  String get onboardingQuest1CardSubtitle;

  /// No description provided for @imperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get imperial;

  /// No description provided for @imperialUnits.
  ///
  /// In en, this message translates to:
  /// **'ft · lbs · mg/dL'**
  String get imperialUnits;

  /// No description provided for @metric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metric;

  /// No description provided for @metricUnits.
  ///
  /// In en, this message translates to:
  /// **'cm · kg · mmol/L'**
  String get metricUnits;

  /// No description provided for @startQuest1.
  ///
  /// In en, this message translates to:
  /// **'Start Quest 1 →'**
  String get startQuest1;

  /// No description provided for @onboardingQuest2Title.
  ///
  /// In en, this message translates to:
  /// **'Quest 2: About you'**
  String get onboardingQuest2Title;

  /// No description provided for @onboardingQuest3Title.
  ///
  /// In en, this message translates to:
  /// **'Quest 3: Your vitals'**
  String get onboardingQuest3Title;

  /// No description provided for @onboardingVictoryTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re ready!'**
  String get onboardingVictoryTitle;

  /// No description provided for @onboardingVictoryBody.
  ///
  /// In en, this message translates to:
  /// **'Your health journey starts now.'**
  String get onboardingVictoryBody;

  /// No description provided for @activityYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your activity plan'**
  String get activityYourPlan;

  /// No description provided for @activityCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get activityCurrentPlan;

  /// No description provided for @activityWhatsIncluded.
  ///
  /// In en, this message translates to:
  /// **'What\'s included'**
  String get activityWhatsIncluded;

  /// No description provided for @activityChangePlan.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get activityChangePlan;

  /// No description provided for @activityStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start physical activity'**
  String get activityStartTitle;

  /// No description provided for @activityChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get activityChangeTitle;

  /// No description provided for @activityChooseProgram.
  ///
  /// In en, this message translates to:
  /// **'Choose your program. Start your daily physical activity.'**
  String get activityChooseProgram;

  /// No description provided for @activityChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a new program. Your evening check-in will follow the new plan.'**
  String get activityChangeHint;

  /// No description provided for @activityKeepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keep current plan'**
  String get activityKeepCurrent;

  /// No description provided for @activityProgramStarted.
  ///
  /// In en, this message translates to:
  /// **'Program started'**
  String get activityProgramStarted;

  /// No description provided for @activityProgramSaved.
  ///
  /// In en, this message translates to:
  /// **'Your daily physical activity plan is saved. Every evening we will ask if you completed it.'**
  String get activityProgramSaved;

  /// No description provided for @activityStartThis.
  ///
  /// In en, this message translates to:
  /// **'Start this program'**
  String get activityStartThis;

  /// No description provided for @activitySwitchToThis.
  ///
  /// In en, this message translates to:
  /// **'Switch to this plan'**
  String get activitySwitchToThis;

  /// No description provided for @activityChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another'**
  String get activityChooseAnother;

  /// No description provided for @activityCurrentBadge.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get activityCurrentBadge;

  /// No description provided for @activityStarter.
  ///
  /// In en, this message translates to:
  /// **'Starter'**
  String get activityStarter;

  /// No description provided for @activityStarterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Begin your daily physical activity'**
  String get activityStarterSubtitle;

  /// No description provided for @activityAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get activityAdvanced;

  /// No description provided for @activityAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build consistency with structured sets'**
  String get activityAdvancedSubtitle;

  /// No description provided for @activityProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get activityProfessional;

  /// No description provided for @activityProfessionalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'High-volume daily bodyweight training'**
  String get activityProfessionalSubtitle;

  /// No description provided for @activitySuperman.
  ///
  /// In en, this message translates to:
  /// **'Superman'**
  String get activitySuperman;

  /// No description provided for @activitySupermanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Gym-based vigorous training'**
  String get activitySupermanSubtitle;

  /// No description provided for @partially.
  ///
  /// In en, this message translates to:
  /// **'Partially'**
  String get partially;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @phaPlus.
  ///
  /// In en, this message translates to:
  /// **'PHA Plus+'**
  String get phaPlus;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @trialExpired.
  ///
  /// In en, this message translates to:
  /// **'Trial expired'**
  String get trialExpired;

  /// No description provided for @unitSteps.
  ///
  /// In en, this message translates to:
  /// **'steps'**
  String get unitSteps;

  /// No description provided for @unitKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get unitKcal;

  /// No description provided for @unitMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get unitMin;

  /// No description provided for @unitMl.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get unitMl;

  /// No description provided for @unitMmhg.
  ///
  /// In en, this message translates to:
  /// **'mmHg'**
  String get unitMmhg;

  /// No description provided for @healthOverviewToday.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your health overview for today.'**
  String get healthOverviewToday;

  /// No description provided for @unitYears.
  ///
  /// In en, this message translates to:
  /// **'yrs'**
  String get unitYears;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitCm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitCm;

  /// No description provided for @unitLbs.
  ///
  /// In en, this message translates to:
  /// **'lbs'**
  String get unitLbs;

  /// No description provided for @unitMmol.
  ///
  /// In en, this message translates to:
  /// **'mmol/L'**
  String get unitMmol;

  /// No description provided for @unitMgdl.
  ///
  /// In en, this message translates to:
  /// **'mg/dL'**
  String get unitMgdl;

  /// No description provided for @unitKm.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get unitKm;

  /// No description provided for @unitMiles.
  ///
  /// In en, this message translates to:
  /// **'miles'**
  String get unitMiles;

  /// No description provided for @healthIndexAvgScore.
  ///
  /// In en, this message translates to:
  /// **'Avg {score}/100'**
  String healthIndexAvgScore(int score);

  /// No description provided for @indexCardExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent — keep it up.'**
  String get indexCardExcellent;

  /// No description provided for @indexCardGood.
  ///
  /// In en, this message translates to:
  /// **'You\'re doing well.'**
  String get indexCardGood;

  /// No description provided for @indexCardFair.
  ///
  /// In en, this message translates to:
  /// **'Some areas need attention.'**
  String get indexCardFair;

  /// No description provided for @indexCardNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs focus — review your habits.'**
  String get indexCardNeedsAttention;

  /// No description provided for @stepsMsgSedentary.
  ///
  /// In en, this message translates to:
  /// **'Low activity today. Start with a 15-minute walk — consistency beats intensity for long-term heart health.'**
  String get stepsMsgSedentary;

  /// No description provided for @stepsMsgBuilding.
  ///
  /// In en, this message translates to:
  /// **'You are building a walking habit. Aim toward {goal}+ steps for stronger cardiometabolic benefit.'**
  String stepsMsgBuilding(int goal);

  /// No description provided for @stepsMsgBaseline.
  ///
  /// In en, this message translates to:
  /// **'Solid baseline activity. A few more short walks can reach the {goal}+ range many guidelines treat as beneficial.'**
  String stepsMsgBaseline(int goal);

  /// No description provided for @stepsMsgStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong activity level — well above sedentary. Keep this rhythm; {goal} steps is a bonus goal, not a must.'**
  String stepsMsgStrong(int goal);

  /// No description provided for @stepsMsgGoal.
  ///
  /// In en, this message translates to:
  /// **'Excellent activity level — you are meeting the classic {goal}-step day.'**
  String stepsMsgGoal(int goal);

  /// No description provided for @stepsRangeSedentary.
  ///
  /// In en, this message translates to:
  /// **'0–{max} steps'**
  String stepsRangeSedentary(String max);

  /// No description provided for @stepsRangeBuilding.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} steps'**
  String stepsRangeBuilding(String min, String max);

  /// No description provided for @stepsRangeBaseline.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} steps'**
  String stepsRangeBaseline(String min, String max);

  /// No description provided for @stepsRangeStrong.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} steps'**
  String stepsRangeStrong(String min, String max);

  /// No description provided for @stepsRangeGoal.
  ///
  /// In en, this message translates to:
  /// **'{min}+ steps'**
  String stepsRangeGoal(String min);

  /// No description provided for @todaysNotifications.
  ///
  /// In en, this message translates to:
  /// **'Today\'s notifications'**
  String get todaysNotifications;

  /// No description provided for @morningNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Good morning — your health recap'**
  String get morningNotificationTitle;

  /// No description provided for @noNotificationsToday.
  ///
  /// In en, this message translates to:
  /// **'No notifications for today yet.'**
  String get noNotificationsToday;

  /// No description provided for @notificationsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Notifications that already arrived today appear here.'**
  String get notificationsAppearHere;

  /// No description provided for @phaPlusUnlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re on PHA Plus+!'**
  String get phaPlusUnlockedTitle;

  /// No description provided for @phaPlusUnlockedBody.
  ///
  /// In en, this message translates to:
  /// **'All features are now unlocked. Enjoy unlimited uploads, PsychoTest, and Treatment Schedule.'**
  String get phaPlusUnlockedBody;

  /// No description provided for @onboardingQuest2BuildAvatar.
  ///
  /// In en, this message translates to:
  /// **'Quest 2: Build your avatar'**
  String get onboardingQuest2BuildAvatar;

  /// No description provided for @onboardingQuest2FillFields.
  ///
  /// In en, this message translates to:
  /// **'Fill all 3 fields — earn +{hp} HP on complete.'**
  String onboardingQuest2FillFields(int hp);

  /// No description provided for @rewardedStats.
  ///
  /// In en, this message translates to:
  /// **'Rewarded stats'**
  String get rewardedStats;

  /// No description provided for @yourGender.
  ///
  /// In en, this message translates to:
  /// **'Your gender'**
  String get yourGender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @unitYearsLong.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get unitYearsLong;

  /// No description provided for @completeQuest2.
  ///
  /// In en, this message translates to:
  /// **'Complete Quest 2 (+{hp} HP)'**
  String completeQuest2(int hp);

  /// No description provided for @backToQuest2.
  ///
  /// In en, this message translates to:
  /// **'Back to Quest 2'**
  String get backToQuest2;

  /// No description provided for @onboardingQuest3PowerUp.
  ///
  /// In en, this message translates to:
  /// **'Quest 3: Power-up (bonus)'**
  String get onboardingQuest3PowerUp;

  /// No description provided for @onboardingQuest3BpDone.
  ///
  /// In en, this message translates to:
  /// **'You already logged BP and glucose today. Come back tomorrow for your next reading.'**
  String get onboardingQuest3BpDone;

  /// No description provided for @onboardingQuest3Optional.
  ///
  /// In en, this message translates to:
  /// **'Optional vitals — +{bpHp} HP for BP, +{glucoseHp} HP for glucose. Once per day.'**
  String onboardingQuest3Optional(int bpHp, int glucoseHp);

  /// No description provided for @onboardingAllQuestsComplete.
  ///
  /// In en, this message translates to:
  /// **'All quests complete!'**
  String get onboardingAllQuestsComplete;

  /// No description provided for @onboardingEarnedHp.
  ///
  /// In en, this message translates to:
  /// **'You earned {hp} HP · Level {level} {title}'**
  String onboardingEarnedHp(int hp, int level, String title);

  /// No description provided for @onboardingBonusVitals.
  ///
  /// In en, this message translates to:
  /// **'Bonus vitals unlocked extra insights!'**
  String get onboardingBonusVitals;

  /// No description provided for @healthPower.
  ///
  /// In en, this message translates to:
  /// **'Health Power'**
  String get healthPower;

  /// No description provided for @onboardingCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account and become healthy →'**
  String get onboardingCreateAccount;

  /// No description provided for @onboardingEnterDashboard.
  ///
  /// In en, this message translates to:
  /// **'Enter dashboard →'**
  String get onboardingEnterDashboard;

  /// No description provided for @badgeUnitPro.
  ///
  /// In en, this message translates to:
  /// **'Unit Pro'**
  String get badgeUnitPro;

  /// No description provided for @badgeFoundation.
  ///
  /// In en, this message translates to:
  /// **'Foundation'**
  String get badgeFoundation;

  /// No description provided for @badgeHeartTrack.
  ///
  /// In en, this message translates to:
  /// **'Heart Track'**
  String get badgeHeartTrack;

  /// No description provided for @badgeSugarSense.
  ///
  /// In en, this message translates to:
  /// **'Sugar Sense'**
  String get badgeSugarSense;

  /// No description provided for @badgeChampion.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get badgeChampion;

  /// No description provided for @levelHealthRookie.
  ///
  /// In en, this message translates to:
  /// **'Health Rookie'**
  String get levelHealthRookie;

  /// No description provided for @levelProfileBuilder.
  ///
  /// In en, this message translates to:
  /// **'Profile Builder'**
  String get levelProfileBuilder;

  /// No description provided for @levelVitalsPro.
  ///
  /// In en, this message translates to:
  /// **'Vitals Pro'**
  String get levelVitalsPro;

  /// No description provided for @picked.
  ///
  /// In en, this message translates to:
  /// **'PICKED'**
  String get picked;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @claimBonusFinish.
  ///
  /// In en, this message translates to:
  /// **'Claim bonus & finish 🏆'**
  String get claimBonusFinish;

  /// No description provided for @skipBonusQuest.
  ///
  /// In en, this message translates to:
  /// **'Skip bonus quest'**
  String get skipBonusQuest;

  /// No description provided for @calculatingRewards.
  ///
  /// In en, this message translates to:
  /// **'Calculating rewards…'**
  String get calculatingRewards;

  /// No description provided for @categoryBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get categoryBloodPressure;

  /// No description provided for @categoryBloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose'**
  String get categoryBloodGlucose;

  /// No description provided for @categoryWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get categoryWeight;

  /// No description provided for @categoryWeightBmi.
  ///
  /// In en, this message translates to:
  /// **'Weight / BMI'**
  String get categoryWeightBmi;

  /// No description provided for @categoryDailyActivity.
  ///
  /// In en, this message translates to:
  /// **'Daily Activity'**
  String get categoryDailyActivity;

  /// No description provided for @categoryCalorieBurn.
  ///
  /// In en, this message translates to:
  /// **'Calorie Burn'**
  String get categoryCalorieBurn;

  /// No description provided for @categoryMentalWellness.
  ///
  /// In en, this message translates to:
  /// **'Mental Wellness'**
  String get categoryMentalWellness;

  /// No description provided for @categorySmoking.
  ///
  /// In en, this message translates to:
  /// **'Smoking'**
  String get categorySmoking;

  /// No description provided for @categoryAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Alcohol'**
  String get categoryAlcohol;

  /// No description provided for @categoryScreenTime.
  ///
  /// In en, this message translates to:
  /// **'Screen Time'**
  String get categoryScreenTime;

  /// No description provided for @categoryNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get categoryNutrition;

  /// No description provided for @categoryPsychoTest.
  ///
  /// In en, this message translates to:
  /// **'PsychoTest'**
  String get categoryPsychoTest;

  /// No description provided for @categoryActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get categoryActivity;

  /// No description provided for @categoryHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate & Rhythm'**
  String get categoryHeartRate;

  /// No description provided for @categoryAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get categoryAge;

  /// No description provided for @categoryStress.
  ///
  /// In en, this message translates to:
  /// **'Stress (elevated pulse)'**
  String get categoryStress;

  /// No description provided for @analysisSummaryExcellent.
  ///
  /// In en, this message translates to:
  /// **'Your Health Index is excellent.'**
  String get analysisSummaryExcellent;

  /// No description provided for @analysisSummaryGood.
  ///
  /// In en, this message translates to:
  /// **'Your Health Index looks good overall.'**
  String get analysisSummaryGood;

  /// No description provided for @analysisSummaryFair.
  ///
  /// In en, this message translates to:
  /// **'Your Health Index is fair — a few levers will move it up.'**
  String get analysisSummaryFair;

  /// No description provided for @analysisSummaryNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Your Health Index needs attention — focus on the highest-impact gaps below.'**
  String get analysisSummaryNeedsAttention;

  /// No description provided for @analysisSummaryDefault.
  ///
  /// In en, this message translates to:
  /// **'Here is your health summary.'**
  String get analysisSummaryDefault;

  /// No description provided for @analysisScoreMatches.
  ///
  /// In en, this message translates to:
  /// **'Score {score}/100 matches the Home Health Index.'**
  String analysisScoreMatches(int score);

  /// No description provided for @analysisStrengths.
  ///
  /// In en, this message translates to:
  /// **'Strengths: {names}.'**
  String analysisStrengths(String names);

  /// No description provided for @analysisBiggestDrag.
  ///
  /// In en, this message translates to:
  /// **'Biggest Index drag right now: {names}.'**
  String analysisBiggestDrag(String names);

  /// No description provided for @glucoseMsgHypoglycemia.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose is low (hypoglycemia). Eat something with fast-acting carbohydrates and consult your doctor.'**
  String get glucoseMsgHypoglycemia;

  /// No description provided for @glucoseMsgNormal.
  ///
  /// In en, this message translates to:
  /// **'Fasting blood glucose is in the normal range. Good metabolic health.'**
  String get glucoseMsgNormal;

  /// No description provided for @glucoseMsgPrediabetes.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose is in the prediabetes range. Cut sugary drinks, add fiber at each meal, and walk 10–15 minutes after eating.'**
  String get glucoseMsgPrediabetes;

  /// No description provided for @glucoseMsgDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose is in the diabetes range. Please consult a healthcare provider for evaluation and a care plan.'**
  String get glucoseMsgDiabetes;

  /// No description provided for @bmiMsgWeightOnly.
  ///
  /// In en, this message translates to:
  /// **'Weight is recorded. Add your height in Profile so we can score BMI in your Health Index.'**
  String get bmiMsgWeightOnly;

  /// No description provided for @bmiMsgUnderweight.
  ///
  /// In en, this message translates to:
  /// **'Your weight is a bit low for your height. Eat protein-rich meals more often; ask a doctor if you did not mean to lose weight.'**
  String get bmiMsgUnderweight;

  /// No description provided for @bmiMsgHealthy.
  ///
  /// In en, this message translates to:
  /// **'Your weight looks healthy for your height. Well done!'**
  String get bmiMsgHealthy;

  /// No description provided for @bmiMsgOverweight.
  ///
  /// In en, this message translates to:
  /// **'Your weight is a bit above the healthy range. Aim for a gentle weekly loss, keep protein up, and protect your daily steps.'**
  String get bmiMsgOverweight;

  /// No description provided for @bmiMsgObeseI.
  ///
  /// In en, this message translates to:
  /// **'Your weight is clearly above the healthy range. This can raise blood pressure and blood sugar. Better food, more walking, and a doctor-guided plan help a lot.'**
  String get bmiMsgObeseI;

  /// No description provided for @bmiMsgObeseII.
  ///
  /// In en, this message translates to:
  /// **'Your weight is well above the healthy range. Please see a doctor for a safe plan to protect your heart and metabolism.'**
  String get bmiMsgObeseII;

  /// No description provided for @stepsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String stepsLabel(String count);

  /// No description provided for @calorieBurnGood.
  ///
  /// In en, this message translates to:
  /// **'Calorie expenditure looks consistent with your steps. Pair it with balanced meals to support recovery.'**
  String get calorieBurnGood;

  /// No description provided for @calorieBurnInfo.
  ///
  /// In en, this message translates to:
  /// **'You burned {calories} kcal from activity. Use meal logging to match intake to your goals.'**
  String calorieBurnInfo(int calories);

  /// No description provided for @wellnessMsgExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent wellness score — low stress load and solid mental resilience.'**
  String get wellnessMsgExcellent;

  /// No description provided for @wellnessMsgGood.
  ///
  /// In en, this message translates to:
  /// **'Good wellness. Small upgrades in sleep or recovery can push you to excellent.'**
  String get wellnessMsgGood;

  /// No description provided for @wellnessMsgModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate wellness. Try a short wind-down: 5 minutes of breathing, a walk outside, or earlier lights-out.'**
  String get wellnessMsgModerate;

  /// No description provided for @wellnessMsgNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Wellness score suggests elevated stress. Protect sleep, reduce late caffeine, and reconnect socially this week.'**
  String get wellnessMsgNeedsAttention;

  /// No description provided for @wellnessMsgCritical.
  ///
  /// In en, this message translates to:
  /// **'High stress load. Consider repeating the Wellness Check and talking with a mental health professional if this persists.'**
  String get wellnessMsgCritical;

  /// No description provided for @smokingGood.
  ///
  /// In en, this message translates to:
  /// **'No smoking reported — one of the strongest protective factors for heart and lung health.'**
  String get smokingGood;

  /// No description provided for @smokingLessPack.
  ///
  /// In en, this message translates to:
  /// **'<1 pack/day'**
  String get smokingLessPack;

  /// No description provided for @smokingOnePack.
  ///
  /// In en, this message translates to:
  /// **'~1 pack/day'**
  String get smokingOnePack;

  /// No description provided for @smokingMorePack.
  ///
  /// In en, this message translates to:
  /// **'>1 pack/day'**
  String get smokingMorePack;

  /// No description provided for @smokingActive.
  ///
  /// In en, this message translates to:
  /// **'Active smoker'**
  String get smokingActive;

  /// No description provided for @smokingNonSmoker.
  ///
  /// In en, this message translates to:
  /// **'Non-smoker'**
  String get smokingNonSmoker;

  /// No description provided for @smokingWarning.
  ///
  /// In en, this message translates to:
  /// **'Smoking is a top Health Index risk factor. Set a quit date, remove triggers, and use Plus+ → Check Your Bad Habits to track progress.'**
  String get smokingWarning;

  /// No description provided for @alcoholNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get alcoholNone;

  /// No description provided for @alcoholGood.
  ///
  /// In en, this message translates to:
  /// **'No alcohol use reported — helpful for BP, sleep, and liver health.'**
  String get alcoholGood;

  /// No description provided for @alcoholOccasional.
  ///
  /// In en, this message translates to:
  /// **'Occasional'**
  String get alcoholOccasional;

  /// No description provided for @alcoholOccasionalTip.
  ///
  /// In en, this message translates to:
  /// **'Keep alcohol occasional and alcohol-free most days of the week.'**
  String get alcoholOccasionalTip;

  /// No description provided for @alcoholRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get alcoholRegular;

  /// No description provided for @alcoholRegularTip.
  ///
  /// In en, this message translates to:
  /// **'Cut toward fewer drinking days; alcohol raises BP and calorie load.'**
  String get alcoholRegularTip;

  /// No description provided for @alcoholHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get alcoholHeavy;

  /// No description provided for @alcoholHeavyTip.
  ///
  /// In en, this message translates to:
  /// **'Heavy use strongly hurts your Health Index — seek support to cut down safely.'**
  String get alcoholHeavyTip;

  /// No description provided for @alcoholDefault.
  ///
  /// In en, this message translates to:
  /// **'Drinks alcohol'**
  String get alcoholDefault;

  /// No description provided for @alcoholDefaultTip.
  ///
  /// In en, this message translates to:
  /// **'Track frequency this week and aim for several alcohol-free days.'**
  String get alcoholDefaultTip;

  /// No description provided for @screenRarely.
  ///
  /// In en, this message translates to:
  /// **'Rarely'**
  String get screenRarely;

  /// No description provided for @screenRarelyTip.
  ///
  /// In en, this message translates to:
  /// **'Low social-media load — good for sleep and focus.'**
  String get screenRarelyTip;

  /// No description provided for @screenUnderHour.
  ///
  /// In en, this message translates to:
  /// **'<1 h/day'**
  String get screenUnderHour;

  /// No description provided for @screenUnderHourTip.
  ///
  /// In en, this message translates to:
  /// **'Reasonable screen habit. Keep phones out of the bedroom if sleep slips.'**
  String get screenUnderHourTip;

  /// No description provided for @screenOneTwoHours.
  ///
  /// In en, this message translates to:
  /// **'1–2 h/day'**
  String get screenOneTwoHours;

  /// No description provided for @screenOneTwoTip.
  ///
  /// In en, this message translates to:
  /// **'Moderate use. Try a 30-minute evening cutoff to protect recovery.'**
  String get screenOneTwoTip;

  /// No description provided for @screenConstant.
  ///
  /// In en, this message translates to:
  /// **'Constant'**
  String get screenConstant;

  /// No description provided for @screenConstantTip.
  ///
  /// In en, this message translates to:
  /// **'High screen time crowds out movement and sleep. Set app limits and swap one scroll block for a walk.'**
  String get screenConstantTip;

  /// No description provided for @screenDefaultTip.
  ///
  /// In en, this message translates to:
  /// **'Review screen habits — small evening limits often help wellness scores.'**
  String get screenDefaultTip;

  /// No description provided for @nutritionRecentMeals.
  ///
  /// In en, this message translates to:
  /// **'{count} recent meals'**
  String nutritionRecentMeals(int count);

  /// No description provided for @nutritionWarning.
  ///
  /// In en, this message translates to:
  /// **'Several recent meals need attention. Favor vegetables, protein, and fewer ultra-processed snacks; log the next meal for feedback.'**
  String get nutritionWarning;

  /// No description provided for @nutritionGood.
  ///
  /// In en, this message translates to:
  /// **'Recent meal quality looks strong. Keep the pattern — it supports glucose and weight in your Health Index.'**
  String get nutritionGood;

  /// No description provided for @nutritionInfo.
  ///
  /// In en, this message translates to:
  /// **'Mixed meal quality lately. Aim for one upgrade per day (more fiber or protein, less sugary drinks).'**
  String get nutritionInfo;

  /// No description provided for @psychoLoad.
  ///
  /// In en, this message translates to:
  /// **'Load {total} · {label}'**
  String psychoLoad(int total, String label);

  /// No description provided for @psychoLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get psychoLow;

  /// No description provided for @psychoModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get psychoModerate;

  /// No description provided for @psychoHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get psychoHigh;

  /// No description provided for @psychoLowMsg.
  ///
  /// In en, this message translates to:
  /// **'Psychosomatic indicators are within a healthy range. Keep maintaining your wellness habits.'**
  String get psychoLowMsg;

  /// No description provided for @psychoModerateMsg.
  ///
  /// In en, this message translates to:
  /// **'Moderate psychosomatic load. Pay attention to rest, relaxation routines, and healthy boundaries.'**
  String get psychoModerateMsg;

  /// No description provided for @psychoHighMsg.
  ///
  /// In en, this message translates to:
  /// **'Significant stress and psychosomatic tension. Consider speaking with a specialist and reducing your load.'**
  String get psychoHighMsg;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccess;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service & Disclaimer'**
  String get termsOfService;

  /// No description provided for @howWeHandleData.
  ///
  /// In en, this message translates to:
  /// **'How we handle your data'**
  String get howWeHandleData;

  /// No description provided for @sameScoreHint.
  ///
  /// In en, this message translates to:
  /// **'Same score as on Home'**
  String get sameScoreHint;

  /// No description provided for @eveningNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Evening check-in'**
  String get eveningNotificationTitle;

  /// No description provided for @bpMsgLow.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is below the usual adult range (hypotension). Stay hydrated and talk to a clinician if you feel dizzy or faint.'**
  String get bpMsgLow;

  /// No description provided for @bpMsgOptimal.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is optimal (<120/<80). Keep up the healthy lifestyle.'**
  String get bpMsgOptimal;

  /// No description provided for @bpMsgNormal.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is in the normal adult range (around 120/80). This is a healthy target for most adults — not hypertension.'**
  String get bpMsgNormal;

  /// No description provided for @bpMsgHighNormal.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is a little high (not hypertension yet). Monitor regularly; cut salt, stay active, and watch trends.'**
  String get bpMsgHighNormal;

  /// No description provided for @bpMsgGrade1.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is high. Lifestyle changes come first — less salt, more walking. Recheck and talk to a doctor if it stays up.'**
  String get bpMsgGrade1;

  /// No description provided for @bpMsgGrade2.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is clearly high. Please see a doctor soon.'**
  String get bpMsgGrade2;

  /// No description provided for @bpMsgGrade3.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is very high. Seek medical care without delay.'**
  String get bpMsgGrade3;

  /// No description provided for @bpMsgDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is very high. Seek medical care without delay.'**
  String get bpMsgDiabetes;

  /// No description provided for @uploadAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Analysis'**
  String get uploadAnalysisTitle;

  /// No description provided for @uploadFileType.
  ///
  /// In en, this message translates to:
  /// **'File Type'**
  String get uploadFileType;

  /// No description provided for @uploadPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF Document'**
  String get uploadPdf;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo / Image'**
  String get uploadPhoto;

  /// No description provided for @uploadSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get uploadSelectFile;

  /// No description provided for @uploadClickToSelect.
  ///
  /// In en, this message translates to:
  /// **'Click to select a file'**
  String get uploadClickToSelect;

  /// No description provided for @uploadClickToChange.
  ///
  /// In en, this message translates to:
  /// **'{size} KB — click to change'**
  String uploadClickToChange(int size);

  /// No description provided for @uploadLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Limit reached'**
  String get uploadLimitReached;

  /// No description provided for @uploadUpgradeMore.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to upload more'**
  String get uploadUpgradeMore;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get uploadFile;

  /// No description provided for @uploadAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get uploadAnalyzing;

  /// No description provided for @uploadAnalyzingAiDoc.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your file with Ai Doc…'**
  String get uploadAnalyzingAiDoc;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get uploadFailed;

  /// No description provided for @uploadCouldNotRead.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected file. Please pick it again.'**
  String get uploadCouldNotRead;

  /// No description provided for @uploadLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'Upload limit reached. Upgrade to PHA Plus+ for unlimited uploads.'**
  String get uploadLimitMessage;

  /// No description provided for @uploadFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan: {count}/2 uploads used. Max 2 pages per file.'**
  String uploadFreePlan(int count);

  /// No description provided for @mealTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take or upload a photo of your meal'**
  String get mealTakePhoto;

  /// No description provided for @mealAfterAnalysis.
  ///
  /// In en, this message translates to:
  /// **'After analysis, tap ✓ only if you ate this dish — it adds to today\'s calories.'**
  String get mealAfterAnalysis;

  /// No description provided for @mealCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get mealCamera;

  /// No description provided for @mealGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get mealGallery;

  /// No description provided for @mealAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze Meal'**
  String get mealAnalyze;

  /// No description provided for @mealAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get mealAnalyzing;

  /// No description provided for @mealFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed. Please try again.'**
  String get mealFailed;

  /// No description provided for @mealFreeLimit.
  ///
  /// In en, this message translates to:
  /// **'Free limit reached (2 meals per 24h). Upgrade to PHA Plus+ for unlimited meal checks.'**
  String get mealFreeLimit;

  /// No description provided for @mealFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan: {count}/{limit} meals logged in the last 24 hours.'**
  String mealFreePlan(int count, int limit);

  /// No description provided for @mealLogged.
  ///
  /// In en, this message translates to:
  /// **'Meal logged — counted in today\'s intake & Health Index.'**
  String get mealLogged;

  /// No description provided for @mealTapConfirm.
  ///
  /// In en, this message translates to:
  /// **'Tap ✓ to confirm you ate this — adds to today\'s intake.'**
  String get mealTapConfirm;

  /// No description provided for @mealDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get mealDiscard;

  /// No description provided for @mealTotalIntake.
  ///
  /// In en, this message translates to:
  /// **'Total Intake'**
  String get mealTotalIntake;

  /// No description provided for @mealCarb.
  ///
  /// In en, this message translates to:
  /// **'Carb'**
  String get mealCarb;

  /// No description provided for @mealProteins.
  ///
  /// In en, this message translates to:
  /// **'Proteins'**
  String get mealProteins;

  /// No description provided for @mealFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get mealFat;

  /// No description provided for @mealNoMealsToday.
  ///
  /// In en, this message translates to:
  /// **'No meals confirmed today yet.'**
  String get mealNoMealsToday;

  /// No description provided for @mealNoMealsLogged.
  ///
  /// In en, this message translates to:
  /// **'No meals logged · target ~{target} kcal'**
  String mealNoMealsLogged(int target);

  /// No description provided for @mealConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm meals after analysis to track intake.'**
  String get mealConfirmHint;

  /// No description provided for @aiDocTitle.
  ///
  /// In en, this message translates to:
  /// **'Ai Doc Assistant'**
  String get aiDocTitle;

  /// No description provided for @aiDocWelcome.
  ///
  /// In en, this message translates to:
  /// **'Hello! I\'m your Ai Doc Assistant. Would you like us to use the data you provided during onboarding? After that, you can describe your problem in detail — or share a photo of a meal, lab result, or anything health-related.'**
  String get aiDocWelcome;

  /// No description provided for @aiDocOffline.
  ///
  /// In en, this message translates to:
  /// **'Ai Doc is offline — API key not set.'**
  String get aiDocOffline;

  /// No description provided for @aiDocFreeLimit.
  ///
  /// In en, this message translates to:
  /// **'Free consultation limit reached.'**
  String get aiDocFreeLimit;

  /// No description provided for @aiDocFreeRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of 3 free consultations remaining.'**
  String aiDocFreeRemaining(int remaining);

  /// No description provided for @aiDocAnalyzingHealth.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your health data…'**
  String get aiDocAnalyzingHealth;

  /// No description provided for @aiDocLooking.
  ///
  /// In en, this message translates to:
  /// **'Looking at that…'**
  String get aiDocLooking;

  /// No description provided for @aiDocAskPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask about symptoms, or add a photo note'**
  String get aiDocAskPlaceholder;

  /// No description provided for @aiDocUpgradeChat.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to continue chatting…'**
  String get aiDocUpgradeChat;

  /// No description provided for @aiDocNoProblem.
  ///
  /// In en, this message translates to:
  /// **'No problem! Whenever you\'re ready, describe your symptoms or health concerns in detail — or share a photo.'**
  String get aiDocNoProblem;

  /// No description provided for @aiDocPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get aiDocPhoto;

  /// No description provided for @wellnessResults.
  ///
  /// In en, this message translates to:
  /// **'Wellness Results'**
  String get wellnessResults;

  /// No description provided for @wellnessQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String wellnessQuestion(int current, int total);

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String percentComplete(int percent);

  /// No description provided for @questionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Question unavailable'**
  String get questionUnavailable;

  /// No description provided for @wellnessVeryPoor.
  ///
  /// In en, this message translates to:
  /// **'Very poor'**
  String get wellnessVeryPoor;

  /// No description provided for @wellnessPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get wellnessPoor;

  /// No description provided for @wellnessModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get wellnessModerate;

  /// No description provided for @wellnessGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get wellnessGood;

  /// No description provided for @wellnessExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get wellnessExcellent;

  /// No description provided for @badHabitsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Bad Habits Summary'**
  String get badHabitsSummaryTitle;

  /// No description provided for @badHabitsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your health history. Honest tracking is the first step toward change.'**
  String get badHabitsSaved;

  /// No description provided for @badHabitsSocialMediaLabel.
  ///
  /// In en, this message translates to:
  /// **'Social media'**
  String get badHabitsSocialMediaLabel;

  /// No description provided for @badHabitsStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String badHabitsStep(int step, int total);

  /// No description provided for @badHabitsDoYouSmoke.
  ///
  /// In en, this message translates to:
  /// **'Do you smoke?'**
  String get badHabitsDoYouSmoke;

  /// No description provided for @badHabitsHowMuchSmoke.
  ///
  /// In en, this message translates to:
  /// **'How much do you smoke?'**
  String get badHabitsHowMuchSmoke;

  /// No description provided for @badHabitsDoYouDrink.
  ///
  /// In en, this message translates to:
  /// **'Do you drink alcohol?'**
  String get badHabitsDoYouDrink;

  /// No description provided for @badHabitsHowMuchDrink.
  ///
  /// In en, this message translates to:
  /// **'How often and how much do you drink?'**
  String get badHabitsHowMuchDrink;

  /// No description provided for @badHabitsSocialMedia.
  ///
  /// In en, this message translates to:
  /// **'How much time do you spend uselessly on social media?'**
  String get badHabitsSocialMedia;

  /// No description provided for @treatmentYourSchedule.
  ///
  /// In en, this message translates to:
  /// **'Your schedule'**
  String get treatmentYourSchedule;

  /// No description provided for @treatmentAddMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add medicine or supplement'**
  String get treatmentAddMedicine;

  /// No description provided for @treatmentNewEntry.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get treatmentNewEntry;

  /// No description provided for @treatmentMedicineName.
  ///
  /// In en, this message translates to:
  /// **'Name of medicine or dietary supplement'**
  String get treatmentMedicineName;

  /// No description provided for @treatmentMedicinePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Vitamin D, Metformin'**
  String get treatmentMedicinePlaceholder;

  /// No description provided for @treatmentHowManyTimes.
  ///
  /// In en, this message translates to:
  /// **'How many times a day'**
  String get treatmentHowManyTimes;

  /// No description provided for @treatmentDoseTime.
  ///
  /// In en, this message translates to:
  /// **'Dose {n} time'**
  String treatmentDoseTime(int n);

  /// No description provided for @treatmentAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get treatmentAddAnother;

  /// No description provided for @treatmentSaveSchedule.
  ///
  /// In en, this message translates to:
  /// **'Save schedule'**
  String get treatmentSaveSchedule;

  /// No description provided for @treatmentSaved.
  ///
  /// In en, this message translates to:
  /// **'Treatment schedule saved — pill reminders are on'**
  String get treatmentSaved;

  /// No description provided for @treatmentEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one medicine or supplement name.'**
  String get treatmentEnterName;

  /// No description provided for @treatmentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get treatmentSaveFailed;

  /// No description provided for @treatmentNotifOff.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved, but notifications are off. Enable alerts in Settings to get pill reminders.'**
  String get treatmentNotifOff;

  /// No description provided for @psychoTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stress & Psychosomatic Self-Assessment'**
  String get psychoTestSubtitle;

  /// No description provided for @psychoTestIntro.
  ///
  /// In en, this message translates to:
  /// **'This assessment contains 3 blocks with a total of 20 questions. Answer honestly — there are no right or wrong answers. Results are saved to your profile.'**
  String get psychoTestIntro;

  /// No description provided for @psychoBlock1Title.
  ///
  /// In en, this message translates to:
  /// **'BLOCK 1'**
  String get psychoBlock1Title;

  /// No description provided for @psychoBlock1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Stress Awareness'**
  String get psychoBlock1Subtitle;

  /// No description provided for @psychoBlock2Title.
  ///
  /// In en, this message translates to:
  /// **'BLOCK 2'**
  String get psychoBlock2Title;

  /// No description provided for @psychoBlock2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Physical Symptoms'**
  String get psychoBlock2Subtitle;

  /// No description provided for @psychoBlock3Title.
  ///
  /// In en, this message translates to:
  /// **'BLOCK 3'**
  String get psychoBlock3Title;

  /// No description provided for @psychoBlock3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Behavioral Profile'**
  String get psychoBlock3Subtitle;

  /// No description provided for @psychoAnswerHint.
  ///
  /// In en, this message translates to:
  /// **'Each question has 3 answer options: Never · Sometimes · Often'**
  String get psychoAnswerHint;

  /// No description provided for @psychoStartAssessment.
  ///
  /// In en, this message translates to:
  /// **'Start Assessment'**
  String get psychoStartAssessment;

  /// No description provided for @psychoYourResult.
  ///
  /// In en, this message translates to:
  /// **'YOUR RESULT'**
  String get psychoYourResult;

  /// No description provided for @psychoRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get psychoRetake;

  /// No description provided for @psychoNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get psychoNever;

  /// No description provided for @psychoSometimes.
  ///
  /// In en, this message translates to:
  /// **'Sometimes'**
  String get psychoSometimes;

  /// No description provided for @psychoOften.
  ///
  /// In en, this message translates to:
  /// **'Often'**
  String get psychoOften;

  /// No description provided for @psychoQuestionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String psychoQuestionsCount(int count);

  /// No description provided for @onboardingBackToQuest2.
  ///
  /// In en, this message translates to:
  /// **'Back to Quest 3'**
  String get onboardingBackToQuest2;

  /// No description provided for @onboardingBpGlucose.
  ///
  /// In en, this message translates to:
  /// **'BP / +{hp} HP'**
  String onboardingBpGlucose(int hp);

  /// No description provided for @onboardingGlucoseHp.
  ///
  /// In en, this message translates to:
  /// **'Glucose / +{hp} HP'**
  String onboardingGlucoseHp(int hp);

  /// No description provided for @onboardingSys.
  ///
  /// In en, this message translates to:
  /// **'Sys'**
  String get onboardingSys;

  /// No description provided for @onboardingDia.
  ///
  /// In en, this message translates to:
  /// **'Dia'**
  String get onboardingDia;

  /// No description provided for @onboardingReadyForPha.
  ///
  /// In en, this message translates to:
  /// **'{percent}% — ready for PHA'**
  String onboardingReadyForPha(int percent);

  /// No description provided for @onboardingRedeemHp.
  ///
  /// In en, this message translates to:
  /// **'Redeem your {hp} HP for {percent}% off your first 6-month or annual PHA Plus+ subscription.'**
  String onboardingRedeemHp(int hp, int percent);

  /// No description provided for @activityCurrentPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your current physical activity plan'**
  String get activityCurrentPlanSubtitle;

  /// No description provided for @activityCustomPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Your plan is active. Complete your daily workout and answer the evening check-in.'**
  String get activityCustomPlanHint;

  /// No description provided for @activityRestNote.
  ///
  /// In en, this message translates to:
  /// **'Rest no more than 2 minutes between sets.'**
  String get activityRestNote;

  /// No description provided for @dailyLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get dailyLabel;

  /// No description provided for @fileTypePdf.
  ///
  /// In en, this message translates to:
  /// **'PDF up to 2 pages (free plan)'**
  String get fileTypePdf;

  /// No description provided for @upgradeToPhaPlus.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to PHA Plus+'**
  String get upgradeToPhaPlus;

  /// No description provided for @healthAnalysisSubtitleShort.
  ///
  /// In en, this message translates to:
  /// **'Same score as Home Health Index'**
  String get healthAnalysisSubtitleShort;

  /// No description provided for @wellnessQ1.
  ///
  /// In en, this message translates to:
  /// **'How stressed do you feel right now?'**
  String get wellnessQ1;

  /// No description provided for @wellnessQ2.
  ///
  /// In en, this message translates to:
  /// **'How well did you sleep last night?'**
  String get wellnessQ2;

  /// No description provided for @wellnessQ3.
  ///
  /// In en, this message translates to:
  /// **'How is your energy level today?'**
  String get wellnessQ3;

  /// No description provided for @wellnessQ4.
  ///
  /// In en, this message translates to:
  /// **'How would you rate your mood?'**
  String get wellnessQ4;

  /// No description provided for @wellnessQ5.
  ///
  /// In en, this message translates to:
  /// **'How is your overall wellbeing?'**
  String get wellnessQ5;

  /// No description provided for @badHabitsSmokeLessPack.
  ///
  /// In en, this message translates to:
  /// **'Less than one pack a day'**
  String get badHabitsSmokeLessPack;

  /// No description provided for @badHabitsSmokeOnePack.
  ///
  /// In en, this message translates to:
  /// **'1 pack a day'**
  String get badHabitsSmokeOnePack;

  /// No description provided for @badHabitsSmokeMorePack.
  ///
  /// In en, this message translates to:
  /// **'More than one pack a day'**
  String get badHabitsSmokeMorePack;

  /// No description provided for @badHabitsAlcoholOccasionally.
  ///
  /// In en, this message translates to:
  /// **'Occasionally — less than 100 g strong alcohol, 1–2 glasses of wine, or up to 2 cans of beer per week'**
  String get badHabitsAlcoholOccasionally;

  /// No description provided for @badHabitsAlcoholRegularly.
  ///
  /// In en, this message translates to:
  /// **'Regularly — 200–300 g strong alcohol, 1–2 bottles of wine, or more than 2 L beer per week'**
  String get badHabitsAlcoholRegularly;

  /// No description provided for @badHabitsAlcoholHeavy.
  ///
  /// In en, this message translates to:
  /// **'I get drunk 1–2 times a week to the point of memory loss'**
  String get badHabitsAlcoholHeavy;

  /// No description provided for @badHabitsSocialRarely.
  ///
  /// In en, this message translates to:
  /// **'Rarely or never'**
  String get badHabitsSocialRarely;

  /// No description provided for @badHabitsSocialUnderHour.
  ///
  /// In en, this message translates to:
  /// **'Less than 1 hour a day'**
  String get badHabitsSocialUnderHour;

  /// No description provided for @badHabitsSocialOneTwoHours.
  ///
  /// In en, this message translates to:
  /// **'About 1–2 hours a day'**
  String get badHabitsSocialOneTwoHours;

  /// No description provided for @badHabitsSocialConstantly.
  ///
  /// In en, this message translates to:
  /// **'I constantly surf in my free time'**
  String get badHabitsSocialConstantly;

  /// No description provided for @activitySwitchHint.
  ///
  /// In en, this message translates to:
  /// **'Switch to this program:'**
  String get activitySwitchHint;

  /// No description provided for @activityStartHint.
  ///
  /// In en, this message translates to:
  /// **'Start your daily physical activity with this program:'**
  String get activityStartHint;

  /// No description provided for @activityStarterEx1.
  ///
  /// In en, this message translates to:
  /// **'I will do 15 push-ups throughout the day'**
  String get activityStarterEx1;

  /// No description provided for @activityStarterEx2.
  ///
  /// In en, this message translates to:
  /// **'20 squats per day'**
  String get activityStarterEx2;

  /// No description provided for @activityStarterEx3.
  ///
  /// In en, this message translates to:
  /// **'20 sit-ups'**
  String get activityStarterEx3;

  /// No description provided for @activityStarterEx4.
  ///
  /// In en, this message translates to:
  /// **'15 push-ups from a couch or other object behind your back'**
  String get activityStarterEx4;

  /// No description provided for @activityAdvancedEx1.
  ///
  /// In en, this message translates to:
  /// **'45 push-ups throughout the day. Recommended: 20, 15, 10'**
  String get activityAdvancedEx1;

  /// No description provided for @activityAdvancedEx2.
  ///
  /// In en, this message translates to:
  /// **'50 squats per day, 2 sets of 25'**
  String get activityAdvancedEx2;

  /// No description provided for @activityAdvancedEx3.
  ///
  /// In en, this message translates to:
  /// **'30 sit-ups, 20 front raises, and 10 leg raises with knees bent'**
  String get activityAdvancedEx3;

  /// No description provided for @activityAdvancedEx4.
  ///
  /// In en, this message translates to:
  /// **'25 push-ups from a couch or other object behind your back, 15, and 10'**
  String get activityAdvancedEx4;

  /// No description provided for @activityProEx1.
  ///
  /// In en, this message translates to:
  /// **'Over 100 push-ups per day'**
  String get activityProEx1;

  /// No description provided for @activityProEx2.
  ///
  /// In en, this message translates to:
  /// **'Over 100 squats throughout the day'**
  String get activityProEx2;

  /// No description provided for @activityProEx3.
  ///
  /// In en, this message translates to:
  /// **'Over 70 abdominal exercises per day'**
  String get activityProEx3;

  /// No description provided for @activityProEx4.
  ///
  /// In en, this message translates to:
  /// **'Over 60 push-ups behind the back throughout the day'**
  String get activityProEx4;

  /// No description provided for @activitySupermanEx1.
  ///
  /// In en, this message translates to:
  /// **'I work out in the gym 3 or more times a week for more than 60 minutes vigorously'**
  String get activitySupermanEx1;

  /// No description provided for @treatmentSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get treatmentSaving;

  /// No description provided for @treatmentEntryNumber.
  ///
  /// In en, this message translates to:
  /// **'Entry {n}'**
  String treatmentEntryNumber(int n);

  /// No description provided for @onboardingLevelShort.
  ///
  /// In en, this message translates to:
  /// **'Lv'**
  String get onboardingLevelShort;

  /// No description provided for @onboardingDayStreak.
  ///
  /// In en, this message translates to:
  /// **'{count}-day streak'**
  String onboardingDayStreak(int count);

  /// No description provided for @onboardingHudHealthPower.
  ///
  /// In en, this message translates to:
  /// **'Health Power'**
  String get onboardingHudHealthPower;

  /// No description provided for @onboardingQuest1Complete.
  ///
  /// In en, this message translates to:
  /// **'Quest 1 complete!'**
  String get onboardingQuest1Complete;

  /// No description provided for @onboardingQuest2Complete.
  ///
  /// In en, this message translates to:
  /// **'Quest 2 crushed!'**
  String get onboardingQuest2Complete;

  /// No description provided for @onboardingBonusComplete.
  ///
  /// In en, this message translates to:
  /// **'Bonus quest done!'**
  String get onboardingBonusComplete;

  /// No description provided for @featurePrivateSecure.
  ///
  /// In en, this message translates to:
  /// **'Private & secure'**
  String get featurePrivateSecure;

  /// No description provided for @loginHeroLine1.
  ///
  /// In en, this message translates to:
  /// **'Your health,'**
  String get loginHeroLine1;

  /// No description provided for @loginHeroLine2.
  ///
  /// In en, this message translates to:
  /// **'intelligently'**
  String get loginHeroLine2;

  /// No description provided for @loginHeroLine3.
  ///
  /// In en, this message translates to:
  /// **'tracked.'**
  String get loginHeroLine3;

  /// No description provided for @loginHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Monitor your metrics, get AI-powered insights, and take control of your wellness journey.'**
  String get loginHeroBody;

  /// No description provided for @loginTrustedBy.
  ///
  /// In en, this message translates to:
  /// **'Trusted by health-conscious individuals worldwide.'**
  String get loginTrustedBy;

  /// No description provided for @loginSignUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start tracking your health today — free forever.'**
  String get loginSignUpSubtitle;

  /// No description provided for @loginSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your health dashboard.'**
  String get loginSignInSubtitle;

  /// No description provided for @loginFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get loginFullName;

  /// No description provided for @loginNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Jane Smith'**
  String get loginNamePlaceholder;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get loginEmailLabel;

  /// No description provided for @loginEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get loginEmailPlaceholder;

  /// No description provided for @loginPasswordHintSignUp.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get loginPasswordHintSignUp;

  /// No description provided for @loginPasswordHintSignIn.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get loginPasswordHintSignIn;

  /// No description provided for @legalAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the '**
  String get legalAgreePrefix;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account…'**
  String get creatingAccount;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @loginLegalFooter.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our terms. This app provides wellness guidance, not medical diagnosis.'**
  String get loginLegalFooter;

  /// No description provided for @onboardingErrorAge.
  ///
  /// In en, this message translates to:
  /// **'Enter your age to earn the Foundation badge.'**
  String get onboardingErrorAge;

  /// No description provided for @onboardingErrorGender.
  ///
  /// In en, this message translates to:
  /// **'Select your gender.'**
  String get onboardingErrorGender;

  /// No description provided for @onboardingErrorHeightImperial.
  ///
  /// In en, this message translates to:
  /// **'Enter height (ft 1–8, in 0–11).'**
  String get onboardingErrorHeightImperial;

  /// No description provided for @onboardingErrorHeightMetric.
  ///
  /// In en, this message translates to:
  /// **'Enter height between 50–250 cm.'**
  String get onboardingErrorHeightMetric;

  /// No description provided for @onboardingErrorWeightImperial.
  ///
  /// In en, this message translates to:
  /// **'Enter weight between 44–660 lbs.'**
  String get onboardingErrorWeightImperial;

  /// No description provided for @onboardingErrorWeightMetric.
  ///
  /// In en, this message translates to:
  /// **'Enter weight between 20–300 kg.'**
  String get onboardingErrorWeightMetric;

  /// No description provided for @onboardingErrorQuest2First.
  ///
  /// In en, this message translates to:
  /// **'Complete Quest 2 first.'**
  String get onboardingErrorQuest2First;

  /// No description provided for @onboardingTrailUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get onboardingTrailUnits;

  /// No description provided for @onboardingTrailBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get onboardingTrailBasics;

  /// No description provided for @onboardingTrailBoost.
  ///
  /// In en, this message translates to:
  /// **'Boost'**
  String get onboardingTrailBoost;

  /// No description provided for @onboardingAgeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 32'**
  String get onboardingAgeHint;

  /// No description provided for @onboardingFtIn.
  ///
  /// In en, this message translates to:
  /// **'ft & in'**
  String get onboardingFtIn;

  /// No description provided for @onboardingHeightHintMetric.
  ///
  /// In en, this message translates to:
  /// **'e.g. 175'**
  String get onboardingHeightHintMetric;

  /// No description provided for @onboardingWeightHintImperial.
  ///
  /// In en, this message translates to:
  /// **'e.g. 165'**
  String get onboardingWeightHintImperial;

  /// No description provided for @onboardingWeightHintMetric.
  ///
  /// In en, this message translates to:
  /// **'e.g. 70'**
  String get onboardingWeightHintMetric;

  /// No description provided for @vitalsBpBothOrNone.
  ///
  /// In en, this message translates to:
  /// **'Enter both blood pressure values, or leave both empty.'**
  String get vitalsBpBothOrNone;

  /// No description provided for @vitalsDailyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Log blood pressure and glucose once per day. You can skip and log later.'**
  String get vitalsDailyPrompt;

  /// No description provided for @vitalsPromptTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn Off'**
  String get vitalsPromptTurnOff;

  /// No description provided for @vitalsPromptTurnOffHint.
  ///
  /// In en, this message translates to:
  /// **'Skip daily BP/glucose prompts.'**
  String get vitalsPromptTurnOffHint;

  /// No description provided for @vitalsPromptEvery5Days.
  ///
  /// In en, this message translates to:
  /// **'Ask once in 5 days'**
  String get vitalsPromptEvery5Days;

  /// No description provided for @vitalsPromptEvery5DaysHint.
  ///
  /// In en, this message translates to:
  /// **'Remind every 5 days, not daily.'**
  String get vitalsPromptEvery5DaysHint;

  /// No description provided for @vitalsBpLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure (mmHg)'**
  String get vitalsBpLabel;

  /// No description provided for @vitalsGlucoseLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose ({unit})'**
  String vitalsGlucoseLabel(String unit);

  /// No description provided for @vitalsGlucoseHintImperial.
  ///
  /// In en, this message translates to:
  /// **'e.g. 95'**
  String get vitalsGlucoseHintImperial;

  /// No description provided for @vitalsGlucoseHintMetric.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5.3'**
  String get vitalsGlucoseHintMetric;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @enterValidPositiveNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid positive number.'**
  String get enterValidPositiveNumber;

  /// No description provided for @logHealthMetric.
  ///
  /// In en, this message translates to:
  /// **'Log Health Metric'**
  String get logHealthMetric;

  /// No description provided for @metricSaved.
  ///
  /// In en, this message translates to:
  /// **'Metric saved!'**
  String get metricSaved;

  /// No description provided for @metricType.
  ///
  /// In en, this message translates to:
  /// **'Metric Type'**
  String get metricType;

  /// No description provided for @metricValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value ({unit})'**
  String metricValueLabel(String unit);

  /// No description provided for @metricNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get metricNotesOptional;

  /// No description provided for @metricNotesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Any additional notes...'**
  String get metricNotesPlaceholder;

  /// No description provided for @saveMetric.
  ///
  /// In en, this message translates to:
  /// **'Save Metric'**
  String get saveMetric;

  /// No description provided for @logMetricHintSteps.
  ///
  /// In en, this message translates to:
  /// **'e.g. 8000'**
  String get logMetricHintSteps;

  /// No description provided for @logMetricHintCalories.
  ///
  /// In en, this message translates to:
  /// **'e.g. 350'**
  String get logMetricHintCalories;

  /// No description provided for @logMetricHintDistanceImperial.
  ///
  /// In en, this message translates to:
  /// **'e.g. 3.2'**
  String get logMetricHintDistanceImperial;

  /// No description provided for @logMetricHintDistanceMetric.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5.2'**
  String get logMetricHintDistanceMetric;

  /// No description provided for @logMetricHintActiveTime.
  ///
  /// In en, this message translates to:
  /// **'e.g. 45'**
  String get logMetricHintActiveTime;

  /// No description provided for @logMetricHintWeightImperial.
  ///
  /// In en, this message translates to:
  /// **'e.g. 165'**
  String get logMetricHintWeightImperial;

  /// No description provided for @logMetricHintWeightMetric.
  ///
  /// In en, this message translates to:
  /// **'e.g. 72.5'**
  String get logMetricHintWeightMetric;

  /// No description provided for @logMetricHintWater.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2000'**
  String get logMetricHintWater;

  /// No description provided for @upgradeTrialTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock All Features of PHA Plus+'**
  String get upgradeTrialTitle;

  /// No description provided for @upgradeTrialBody1.
  ///
  /// In en, this message translates to:
  /// **'Take full control of your health! Unlock all premium options in PHA Plus+ and gain the ability to monitor your health, physical activity, nutrition, and medical indicators in real time.'**
  String get upgradeTrialBody1;

  /// No description provided for @upgradeTrialBody2.
  ///
  /// In en, this message translates to:
  /// **'Stay informed about potential risks and easily adjust your lifestyle. Count calories without any limits, correlate them with your daily activity levels, and receive personalized recommendations based on your medical data.'**
  String get upgradeTrialBody2;

  /// No description provided for @upgradeTagline.
  ///
  /// In en, this message translates to:
  /// **'Your health. Your control. Always.'**
  String get upgradeTagline;

  /// No description provided for @upgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock All Features'**
  String get upgradeTitle;

  /// No description provided for @upgradeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get the full power of your Personal Health Assistant'**
  String get upgradeSubtitle;

  /// No description provided for @upgradeHpBanner.
  ///
  /// In en, this message translates to:
  /// **'You have {hp} HP! Redeem for {percent}% off 6-month or annual plans.'**
  String upgradeHpBanner(int hp, int percent);

  /// No description provided for @upgradeTableFeature.
  ///
  /// In en, this message translates to:
  /// **'FEATURE'**
  String get upgradeTableFeature;

  /// No description provided for @upgradeTableFree.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get upgradeTableFree;

  /// No description provided for @upgradeTablePlus.
  ///
  /// In en, this message translates to:
  /// **'PLUS+'**
  String get upgradeTablePlus;

  /// No description provided for @upgradeFeatAnalysisUploads.
  ///
  /// In en, this message translates to:
  /// **'Analysis Uploads'**
  String get upgradeFeatAnalysisUploads;

  /// No description provided for @upgradeFeatMealCalories.
  ///
  /// In en, this message translates to:
  /// **'Meal Calorie Checks'**
  String get upgradeFeatMealCalories;

  /// No description provided for @upgradeFeatPagesPerFile.
  ///
  /// In en, this message translates to:
  /// **'Pages per File'**
  String get upgradeFeatPagesPerFile;

  /// No description provided for @upgradeFeatPsychoTest.
  ///
  /// In en, this message translates to:
  /// **'PsychoTest'**
  String get upgradeFeatPsychoTest;

  /// No description provided for @upgradeFeatTreatment.
  ///
  /// In en, this message translates to:
  /// **'Treatment Schedule'**
  String get upgradeFeatTreatment;

  /// No description provided for @upgradeFeatBadHabits.
  ///
  /// In en, this message translates to:
  /// **'Check Your Bad Habits'**
  String get upgradeFeatBadHabits;

  /// No description provided for @upgradeFeatActivity.
  ///
  /// In en, this message translates to:
  /// **'Start physical activity'**
  String get upgradeFeatActivity;

  /// No description provided for @upgradeFeatAiConsult.
  ///
  /// In en, this message translates to:
  /// **'AI Consultation'**
  String get upgradeFeatAiConsult;

  /// No description provided for @upgradeFeatWellness.
  ///
  /// In en, this message translates to:
  /// **'Wellness Check'**
  String get upgradeFeatWellness;

  /// No description provided for @upgradeVal2Files.
  ///
  /// In en, this message translates to:
  /// **'2 files'**
  String get upgradeVal2Files;

  /// No description provided for @upgradeVal2PerDay.
  ///
  /// In en, this message translates to:
  /// **'2 / 24h'**
  String get upgradeVal2PerDay;

  /// No description provided for @upgradeVal2Pages.
  ///
  /// In en, this message translates to:
  /// **'2 pages'**
  String get upgradeVal2Pages;

  /// No description provided for @upgradeValUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get upgradeValUnlimited;

  /// No description provided for @upgradeValLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get upgradeValLocked;

  /// No description provided for @upgradeValFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Full access'**
  String get upgradeValFullAccess;

  /// No description provided for @upgradeValIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get upgradeValIncluded;

  /// No description provided for @planMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get planMonthly;

  /// No description provided for @planBilledMonthly.
  ///
  /// In en, this message translates to:
  /// **'Billed monthly.'**
  String get planBilledMonthly;

  /// No description provided for @planSemiannual.
  ///
  /// In en, this message translates to:
  /// **'6 Months'**
  String get planSemiannual;

  /// No description provided for @planAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get planAnnual;

  /// No description provided for @planHpDiscountNote.
  ///
  /// In en, this message translates to:
  /// **'20% HP discount applied.'**
  String get planHpDiscountNote;

  /// No description provided for @planSave17.
  ///
  /// In en, this message translates to:
  /// **'Save ~17%.'**
  String get planSave17;

  /// No description provided for @planSave42.
  ///
  /// In en, this message translates to:
  /// **'Save ~42%.'**
  String get planSave42;

  /// No description provided for @planPerMonth.
  ///
  /// In en, this message translates to:
  /// **'/mo'**
  String get planPerMonth;

  /// No description provided for @planPer6Mo.
  ///
  /// In en, this message translates to:
  /// **'/6mo'**
  String get planPer6Mo;

  /// No description provided for @planPerYear.
  ///
  /// In en, this message translates to:
  /// **'/yr'**
  String get planPerYear;

  /// No description provided for @planBestBadge.
  ///
  /// In en, this message translates to:
  /// **'BEST'**
  String get planBestBadge;

  /// No description provided for @psychoTestPromoBody.
  ///
  /// In en, this message translates to:
  /// **'In-depth self-assessment for stress levels, psychosomatic patterns, and mental wellness indicators.'**
  String get psychoTestPromoBody;

  /// No description provided for @psychoQuestionOfBlock.
  ///
  /// In en, this message translates to:
  /// **'Q{current} of {total}'**
  String psychoQuestionOfBlock(int current, int total);

  /// No description provided for @psychoStressLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'{label} Stress Level'**
  String psychoStressLevelTitle(String label);

  /// No description provided for @analysisNoData.
  ///
  /// In en, this message translates to:
  /// **'No health data found. Please log some metrics first.'**
  String get analysisNoData;

  /// No description provided for @analysisAllSolid.
  ///
  /// In en, this message translates to:
  /// **'All scored Health Index factors look solid. Keep logging vitals, meals, and activity so trends stay visible.'**
  String get analysisAllSolid;

  /// No description provided for @syncPlatformOnly.
  ///
  /// In en, this message translates to:
  /// **'Device activity sync is only available on iOS and Android.'**
  String get syncPlatformOnly;

  /// No description provided for @syncPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Activity permission not granted.'**
  String get syncPermissionDenied;

  /// No description provided for @syncReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read activity data. Enable Steps and Walking + Running Distance in Health settings.'**
  String get syncReadFailed;

  /// No description provided for @aiDocNoOnboardingData.
  ///
  /// In en, this message translates to:
  /// **'I could not find your onboarding health data yet. Please complete onboarding first.'**
  String get aiDocNoOnboardingData;

  /// No description provided for @activityYourProgramFallback.
  ///
  /// In en, this message translates to:
  /// **'your program'**
  String get activityYourProgramFallback;

  /// No description provided for @trialSevenDayFree.
  ///
  /// In en, this message translates to:
  /// **'7-day free trial'**
  String get trialSevenDayFree;

  /// No description provided for @uploadImageFormats.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG, GIF'**
  String get uploadImageFormats;

  /// No description provided for @mealSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save meal: {error}'**
  String mealSaveFailed(String error);

  /// No description provided for @mealCaloriesShort.
  ///
  /// In en, this message translates to:
  /// **'{n} cal'**
  String mealCaloriesShort(int n);

  /// No description provided for @treatmentDosesDaily.
  ///
  /// In en, this message translates to:
  /// **'{n}× daily · {times}'**
  String treatmentDosesDaily(int n, String times);

  /// No description provided for @notifMorningFallback.
  ///
  /// In en, this message translates to:
  /// **'Good morning! Log your vitals and check your Health Index today.'**
  String get notifMorningFallback;

  /// No description provided for @notifEveningFallback.
  ///
  /// In en, this message translates to:
  /// **'Evening check-in: how did your health goals go today?'**
  String get notifEveningFallback;

  /// No description provided for @notifChannelName.
  ///
  /// In en, this message translates to:
  /// **'Daily health tips'**
  String get notifChannelName;

  /// No description provided for @notifChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Morning and evening wellness reminders'**
  String get notifChannelDesc;

  /// No description provided for @notifMedicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Medication: {name}'**
  String notifMedicationTitle(String name);

  /// No description provided for @notifMedicationBody.
  ///
  /// In en, this message translates to:
  /// **'Take {name}'**
  String notifMedicationBody(String name);

  /// No description provided for @notifActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Physical activity check-in'**
  String get notifActivityTitle;

  /// No description provided for @notifActivityBody.
  ///
  /// In en, this message translates to:
  /// **'Did you complete {label} today?'**
  String notifActivityBody(String label);

  /// No description provided for @notifIncompleteAssessmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your health checks'**
  String get notifIncompleteAssessmentsTitle;

  /// No description provided for @notifIncompleteAssessmentsBody.
  ///
  /// In en, this message translates to:
  /// **'Please complete: {items}. This improves your Health Index assessment.'**
  String notifIncompleteAssessmentsBody(String items);

  /// No description provided for @notifActivitySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {answer} — Health Index updated'**
  String notifActivitySaved(String answer);

  /// No description provided for @notifDoseLabel.
  ///
  /// In en, this message translates to:
  /// **'Dose {current} of {total} — '**
  String notifDoseLabel(int current, int total);

  /// No description provided for @validationBpCheck.
  ///
  /// In en, this message translates to:
  /// **'Check blood pressure values.'**
  String get validationBpCheck;

  /// No description provided for @validationBpRange.
  ///
  /// In en, this message translates to:
  /// **'Check blood pressure values ({sysMin}–{sysMax} / {diaMin}–{diaMax} mmHg).'**
  String validationBpRange(int sysMin, int sysMax, int diaMin, int diaMax);

  /// No description provided for @validationBpDiaLower.
  ///
  /// In en, this message translates to:
  /// **'Diastolic should be lower than systolic.'**
  String get validationBpDiaLower;

  /// No description provided for @validationGlucoseEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter a glucose value.'**
  String get validationGlucoseEnter;

  /// No description provided for @validationGlucoseRangeMgdl.
  ///
  /// In en, this message translates to:
  /// **'Glucose {min}–{max} mg/dL.'**
  String validationGlucoseRangeMgdl(int min, int max);

  /// No description provided for @validationGlucoseRangeMmol.
  ///
  /// In en, this message translates to:
  /// **'Glucose {min}–{max} mmol/L.'**
  String validationGlucoseRangeMmol(String min, String max);

  /// No description provided for @validationWeightEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid weight.'**
  String get validationWeightEnter;

  /// No description provided for @validationWeightRange.
  ///
  /// In en, this message translates to:
  /// **'Weight {min}–{max} kg.'**
  String validationWeightRange(int min, int max);

  /// No description provided for @validationHeightEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid height.'**
  String get validationHeightEnter;

  /// No description provided for @validationHeightRange.
  ///
  /// In en, this message translates to:
  /// **'Height {min}–{max} cm.'**
  String validationHeightRange(int min, int max);

  /// No description provided for @validationAgeEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid age.'**
  String get validationAgeEnter;

  /// No description provided for @validationAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Age {min}–{max}.'**
  String validationAgeRange(int min, int max);

  /// No description provided for @psychoQ1.
  ///
  /// In en, this message translates to:
  /// **'How often have you felt overwhelmed or unable to control important things in your life?'**
  String get psychoQ1;

  /// No description provided for @psychoQ2.
  ///
  /// In en, this message translates to:
  /// **'How often do you experience physical symptoms like headaches, muscle tension, or fatigue due to stress?'**
  String get psychoQ2;

  /// No description provided for @psychoQ3.
  ///
  /// In en, this message translates to:
  /// **'How often have you had trouble sleeping?'**
  String get psychoQ3;

  /// No description provided for @psychoQ4.
  ///
  /// In en, this message translates to:
  /// **'How often do you feel anxious, worried, or on edge?'**
  String get psychoQ4;

  /// No description provided for @psychoQ5.
  ///
  /// In en, this message translates to:
  /// **'How often do you find it hard to relax and unwind?'**
  String get psychoQ5;

  /// No description provided for @psychoQ6.
  ///
  /// In en, this message translates to:
  /// **'Do you often have:'**
  String get psychoQ6;

  /// No description provided for @psychoQ7.
  ///
  /// In en, this message translates to:
  /// **'Do your symptoms get worse after stress?'**
  String get psychoQ7;

  /// No description provided for @psychoQ8.
  ///
  /// In en, this message translates to:
  /// **'Do you have:'**
  String get psychoQ8;

  /// No description provided for @psychoQ9.
  ///
  /// In en, this message translates to:
  /// **'Do you have any gastrointestinal problems:'**
  String get psychoQ9;

  /// No description provided for @psychoQ10.
  ///
  /// In en, this message translates to:
  /// **'Do you feel short of breath?'**
  String get psychoQ10;

  /// No description provided for @psychoQ11.
  ///
  /// In en, this message translates to:
  /// **'Do you have chronic fatigue?'**
  String get psychoQ11;

  /// No description provided for @psychoQ12.
  ///
  /// In en, this message translates to:
  /// **'Do you have muscle tension?'**
  String get psychoQ12;

  /// No description provided for @psychoQ13.
  ///
  /// In en, this message translates to:
  /// **'Do your symptoms get worse during conflicts or anxiety?'**
  String get psychoQ13;

  /// No description provided for @psychoQ14.
  ///
  /// In en, this message translates to:
  /// **'Do you tend to:'**
  String get psychoQ14;

  /// No description provided for @psychoQ15.
  ///
  /// In en, this message translates to:
  /// **'Do you often:'**
  String get psychoQ15;

  /// No description provided for @psychoQ16.
  ///
  /// In en, this message translates to:
  /// **'Is it difficult for you to say \"no\"?'**
  String get psychoQ16;

  /// No description provided for @psychoQ17.
  ///
  /// In en, this message translates to:
  /// **'Do you have a fear of losing control?'**
  String get psychoQ17;

  /// No description provided for @psychoQ18.
  ///
  /// In en, this message translates to:
  /// **'Do you experience constant internal tension even in a calm environment?'**
  String get psychoQ18;

  /// No description provided for @psychoQ19.
  ///
  /// In en, this message translates to:
  /// **'Do you feel loneliness despite communication?'**
  String get psychoQ19;

  /// No description provided for @psychoQ20.
  ///
  /// In en, this message translates to:
  /// **'Do you often \"keep everything inside\"?'**
  String get psychoQ20;

  /// No description provided for @psychoSubHeadaches.
  ///
  /// In en, this message translates to:
  /// **'Headaches'**
  String get psychoSubHeadaches;

  /// No description provided for @psychoSubMuscleSpasms.
  ///
  /// In en, this message translates to:
  /// **'Muscle spasms'**
  String get psychoSubMuscleSpasms;

  /// No description provided for @psychoSubNeckPain.
  ///
  /// In en, this message translates to:
  /// **'Neck pain'**
  String get psychoSubNeckPain;

  /// No description provided for @psychoSubChestPressure.
  ///
  /// In en, this message translates to:
  /// **'Chest pressure'**
  String get psychoSubChestPressure;

  /// No description provided for @psychoSubStomachHeaviness.
  ///
  /// In en, this message translates to:
  /// **'Heaviness in the stomach'**
  String get psychoSubStomachHeaviness;

  /// No description provided for @psychoSubTachycardia.
  ///
  /// In en, this message translates to:
  /// **'Tachycardia'**
  String get psychoSubTachycardia;

  /// No description provided for @psychoSubBpSurges.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure surges'**
  String get psychoSubBpSurges;

  /// No description provided for @psychoSubSweating.
  ///
  /// In en, this message translates to:
  /// **'Sweating'**
  String get psychoSubSweating;

  /// No description provided for @psychoSubTrembling.
  ///
  /// In en, this message translates to:
  /// **'Trembling'**
  String get psychoSubTrembling;

  /// No description provided for @psychoSubBloating.
  ///
  /// In en, this message translates to:
  /// **'Bloating'**
  String get psychoSubBloating;

  /// No description provided for @psychoSubHeartburn.
  ///
  /// In en, this message translates to:
  /// **'Heartburn'**
  String get psychoSubHeartburn;

  /// No description provided for @psychoSubSpasms.
  ///
  /// In en, this message translates to:
  /// **'Spasms'**
  String get psychoSubSpasms;

  /// No description provided for @psychoSubDiarrheaConstipation.
  ///
  /// In en, this message translates to:
  /// **'Diarrhea / constipation'**
  String get psychoSubDiarrheaConstipation;

  /// No description provided for @psychoSubKeepControl.
  ///
  /// In en, this message translates to:
  /// **'Keep everything under control'**
  String get psychoSubKeepControl;

  /// No description provided for @psychoSubAvoidConflicts.
  ///
  /// In en, this message translates to:
  /// **'Avoid conflicts'**
  String get psychoSubAvoidConflicts;

  /// No description provided for @psychoSubAccumulateEmotions.
  ///
  /// In en, this message translates to:
  /// **'Accumulate emotions'**
  String get psychoSubAccumulateEmotions;

  /// No description provided for @psychoSubTakeResponsibility.
  ///
  /// In en, this message translates to:
  /// **'Take responsibility for everyone'**
  String get psychoSubTakeResponsibility;

  /// No description provided for @psychoSubWorkOvertime.
  ///
  /// In en, this message translates to:
  /// **'Work overtime'**
  String get psychoSubWorkOvertime;

  /// No description provided for @psychoSubDontRest.
  ///
  /// In en, this message translates to:
  /// **'Don\'t rest'**
  String get psychoSubDontRest;

  /// No description provided for @psychoSubFeelGuilty.
  ///
  /// In en, this message translates to:
  /// **'Feel guilty'**
  String get psychoSubFeelGuilty;

  /// No description provided for @clinicalCategoryHealthyWeight.
  ///
  /// In en, this message translates to:
  /// **'Healthy weight range'**
  String get clinicalCategoryHealthyWeight;

  /// No description provided for @clinicalCategoryMetabolic.
  ///
  /// In en, this message translates to:
  /// **'Metabolic health'**
  String get clinicalCategoryMetabolic;

  /// No description provided for @clinicalCategoryCombinedRisk.
  ///
  /// In en, this message translates to:
  /// **'Overall heart & sugar risk'**
  String get clinicalCategoryCombinedRisk;

  /// No description provided for @clinicalCategoryWhatMeans.
  ///
  /// In en, this message translates to:
  /// **'What this means'**
  String get clinicalCategoryWhatMeans;

  /// No description provided for @clinicalCategoryForAge.
  ///
  /// In en, this message translates to:
  /// **'For your age'**
  String get clinicalCategoryForAge;

  /// No description provided for @clinicalIdealWeightNote.
  ///
  /// In en, this message translates to:
  /// **'This is only a rough healthy-weight estimate. Your best range depends on muscle, body shape, and how you feel — not one formula.'**
  String get clinicalIdealWeightNote;

  /// No description provided for @clinicalAroundKg.
  ///
  /// In en, this message translates to:
  /// **'Around {kg} kg'**
  String clinicalAroundKg(int kg);

  /// No description provided for @clinicalBpHighNormalMsg.
  ///
  /// In en, this message translates to:
  /// **'Your reading looks a bit high-normal. Cut salt, stay active, and check BP again on another day.'**
  String get clinicalBpHighNormalMsg;

  /// No description provided for @clinicalWarningSigns.
  ///
  /// In en, this message translates to:
  /// **'{n} warning signs'**
  String clinicalWarningSigns(int n);

  /// No description provided for @clinicalLookingOkay.
  ///
  /// In en, this message translates to:
  /// **'Looking okay'**
  String get clinicalLookingOkay;

  /// No description provided for @clinicalRiskVeryHigh.
  ///
  /// In en, this message translates to:
  /// **'High — act now'**
  String get clinicalRiskVeryHigh;

  /// No description provided for @clinicalRiskElevated.
  ///
  /// In en, this message translates to:
  /// **'Elevated'**
  String get clinicalRiskElevated;

  /// No description provided for @clinicalRiskModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get clinicalRiskModerate;

  /// No description provided for @clinicalRiskLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get clinicalRiskLow;

  /// No description provided for @clinicalGlucoseTooLow.
  ///
  /// In en, this message translates to:
  /// **'Too low'**
  String get clinicalGlucoseTooLow;

  /// No description provided for @clinicalGlucoseNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get clinicalGlucoseNormal;

  /// No description provided for @clinicalGlucosePrediabetes.
  ///
  /// In en, this message translates to:
  /// **'Prediabetes range'**
  String get clinicalGlucosePrediabetes;

  /// No description provided for @clinicalGlucoseDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Diabetes range'**
  String get clinicalGlucoseDiabetes;

  /// No description provided for @clinicalBpVeryHigh.
  ///
  /// In en, this message translates to:
  /// **'Very high — seek care'**
  String get clinicalBpVeryHigh;

  /// No description provided for @clinicalBpHighGrade2.
  ///
  /// In en, this message translates to:
  /// **'High (grade 2)'**
  String get clinicalBpHighGrade2;

  /// No description provided for @clinicalBpHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get clinicalBpHigh;

  /// No description provided for @clinicalBpALittleHigh.
  ///
  /// In en, this message translates to:
  /// **'A little high'**
  String get clinicalBpALittleHigh;

  /// No description provided for @clinicalBpLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get clinicalBpLow;

  /// No description provided for @clinicalBmiActionOver.
  ///
  /// In en, this message translates to:
  /// **' Focus on smaller portions, more vegetables, and daily walks. A 5–7% weight loss already helps heart and blood sugar.'**
  String get clinicalBmiActionOver;

  /// No description provided for @clinicalBmiActionNormal.
  ///
  /// In en, this message translates to:
  /// **' Small daily habits (steps + protein at meals) help keep weight from creeping up.'**
  String get clinicalBmiActionNormal;

  /// No description provided for @clinicalBmiActionUnder.
  ///
  /// In en, this message translates to:
  /// **' Eat protein-rich meals more often and check with a doctor if weight loss was not planned.'**
  String get clinicalBmiActionUnder;

  /// No description provided for @activityCheckinSavedHint.
  ///
  /// In en, this message translates to:
  /// **'Your answer is saved to your health history.'**
  String get activityCheckinSavedHint;

  /// No description provided for @notifMorningFallbackDetailed.
  ///
  /// In en, this message translates to:
  /// **'Check PHA: yesterday\'s steps, meal calories, and a nutrition tip for today.'**
  String get notifMorningFallbackDetailed;

  /// No description provided for @notifEveningOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open PHA for your evening check-in — see how today compared to yesterday.'**
  String get notifEveningOpenApp;

  /// No description provided for @notifEveningStepsToday.
  ///
  /// In en, this message translates to:
  /// **'Today you logged {today} steps. Keep building the habit — open PHA for your full check-in.'**
  String notifEveningStepsToday(int today);

  /// No description provided for @notifEveningStepsUp.
  ///
  /// In en, this message translates to:
  /// **'Today you logged {today} steps, up from yesterday\'s {yesterday}. Nice progress — keep it going.'**
  String notifEveningStepsUp(int today, int yesterday);

  /// No description provided for @notifEveningStepsDown.
  ///
  /// In en, this message translates to:
  /// **'You slipped today with {today} steps, down from yesterday\'s {yesterday}. Let\'s get moving again tomorrow; even a short walk helps.'**
  String notifEveningStepsDown(int today, int yesterday);

  /// No description provided for @notifActivityChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder to log whether you completed your workout'**
  String get notifActivityChannelDesc;

  /// No description provided for @indexSummaryExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent — keep your healthy habits going.'**
  String get indexSummaryExcellent;

  /// No description provided for @indexSummaryGood.
  ///
  /// In en, this message translates to:
  /// **'You\'re doing well.'**
  String get indexSummaryGood;

  /// No description provided for @indexSummaryFair.
  ///
  /// In en, this message translates to:
  /// **'Some areas need attention — small daily changes help.'**
  String get indexSummaryFair;

  /// No description provided for @indexSummaryPoor.
  ///
  /// In en, this message translates to:
  /// **'Your health index needs focus — review vitals and habits.'**
  String get indexSummaryPoor;

  /// No description provided for @validationGlucoseOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Glucose out of allowed range.'**
  String get validationGlucoseOutOfRange;

  /// No description provided for @validationWeightOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Weight out of allowed range.'**
  String get validationWeightOutOfRange;

  /// No description provided for @validationStepsUnrealistic.
  ///
  /// In en, this message translates to:
  /// **'Steps look unrealistic.'**
  String get validationStepsUnrealistic;

  /// No description provided for @validationCaloriesUnrealistic.
  ///
  /// In en, this message translates to:
  /// **'Calories look unrealistic.'**
  String get validationCaloriesUnrealistic;

  /// No description provided for @validationWaterUnrealistic.
  ///
  /// In en, this message translates to:
  /// **'Water intake looks unrealistic.'**
  String get validationWaterUnrealistic;

  /// No description provided for @validationActiveTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Active time must be 0–1440 minutes.'**
  String get validationActiveTimeRange;

  /// No description provided for @validationDistanceUnrealistic.
  ///
  /// In en, this message translates to:
  /// **'Distance looks unrealistic.'**
  String get validationDistanceUnrealistic;

  /// No description provided for @mealQualityNoMeals.
  ///
  /// In en, this message translates to:
  /// **'No meals logged'**
  String get mealQualityNoMeals;

  /// No description provided for @mealQualityHeavyDay.
  ///
  /// In en, this message translates to:
  /// **'Heavy day'**
  String get mealQualityHeavyDay;

  /// No description provided for @mealQualityGoodChoices.
  ///
  /// In en, this message translates to:
  /// **'Good choices'**
  String get mealQualityGoodChoices;

  /// No description provided for @mealQualityOverTarget.
  ///
  /// In en, this message translates to:
  /// **'Over target'**
  String get mealQualityOverTarget;

  /// No description provided for @mealQualityUnderTarget.
  ///
  /// In en, this message translates to:
  /// **'Under target'**
  String get mealQualityUnderTarget;

  /// No description provided for @mealQualityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get mealQualityBalanced;

  /// No description provided for @mealQualityHeavyOverKcal.
  ///
  /// In en, this message translates to:
  /// **'About {over} kcal over your ~{target} kcal target.'**
  String mealQualityHeavyOverKcal(int over, int target);

  /// No description provided for @mealQualityHeavyHighCal.
  ///
  /// In en, this message translates to:
  /// **'Several high-calorie choices today — ease up next meals.'**
  String get mealQualityHeavyHighCal;

  /// No description provided for @mealQualityGoodUnderKcal.
  ///
  /// In en, this message translates to:
  /// **'Solid day — ~{under} kcal under your ~{target} kcal target.'**
  String mealQualityGoodUnderKcal(int under, int target);

  /// No description provided for @mealQualityGoodOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track with your ~{target} kcal target.'**
  String mealQualityGoodOnTrack(int target);

  /// No description provided for @mealQualityOverKcal.
  ///
  /// In en, this message translates to:
  /// **'About {over} kcal over ~{target} kcal — prefer lighter options next.'**
  String mealQualityOverKcal(int over, int target);

  /// No description provided for @mealQualityUnderKcal.
  ///
  /// In en, this message translates to:
  /// **'~{under} kcal under goal — make sure meals are logged if you ate more.'**
  String mealQualityUnderKcal(int under);

  /// No description provided for @mealQualityBalancedHint.
  ///
  /// In en, this message translates to:
  /// **'Intake ~{total} kcal vs ~{target} kcal target today.'**
  String mealQualityBalancedHint(int total, int target);

  /// No description provided for @mealQualityTargetLine.
  ///
  /// In en, this message translates to:
  /// **'{label} · target ~{target} kcal'**
  String mealQualityTargetLine(String label, int target);

  /// No description provided for @mealCategoryExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get mealCategoryExcellent;

  /// No description provided for @mealCategorySatisfactory.
  ///
  /// In en, this message translates to:
  /// **'Satisfactory'**
  String get mealCategorySatisfactory;

  /// No description provided for @mealCategoryAttention.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get mealCategoryAttention;

  /// No description provided for @mealFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get mealFallbackName;

  /// No description provided for @mealOneServing.
  ///
  /// In en, this message translates to:
  /// **'one serving'**
  String get mealOneServing;

  /// No description provided for @adviceProtectWhatWorks.
  ///
  /// In en, this message translates to:
  /// **'Protect what works: keep today\'s activity and meal pattern, and re-check BP/glucose on a consistent schedule.'**
  String get adviceProtectWhatWorks;

  /// No description provided for @adviceBloodPressure1.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure: measure at the same time of day, seated and rested. Cut packaged salt, and walk most days — lifestyle is first-line before medication decisions.'**
  String get adviceBloodPressure1;

  /// No description provided for @adviceBloodPressure2.
  ///
  /// In en, this message translates to:
  /// **'If readings stay ≥140/90 on repeat checks, book a clinician visit with your home log.'**
  String get adviceBloodPressure2;

  /// No description provided for @adviceSmoking.
  ///
  /// In en, this message translates to:
  /// **'Smoking: pick a quit day this week, tell someone, and remove cigarettes from easy reach. Update Plus+ → Check Your Bad Habits after you cut down.'**
  String get adviceSmoking;

  /// No description provided for @adviceGlucose1.
  ///
  /// In en, this message translates to:
  /// **'Glucose: swap sugary drinks for water, add fiber/protein to breakfast, and take a 10–15 minute walk after your largest meal.'**
  String get adviceGlucose1;

  /// No description provided for @adviceGlucose2.
  ///
  /// In en, this message translates to:
  /// **'If fasting glucose stays high, ask your clinician about labs (HbA1c) rather than relying on one reading.'**
  String get adviceGlucose2;

  /// No description provided for @adviceBmi1.
  ///
  /// In en, this message translates to:
  /// **'Weight: target a gentle weekly change, not a crash diet — prioritize protein, vegetables, and your step habit from Health Insights.'**
  String get adviceBmi1;

  /// No description provided for @adviceBmi2.
  ///
  /// In en, this message translates to:
  /// **'Log meals with Calorie Check so nutrition advice matches what you actually eat.'**
  String get adviceBmi2;

  /// No description provided for @adviceActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity: schedule two fixed walk slots (e.g. after lunch and evening). Answer the physical-activity check-in so adherence counts in your Index.'**
  String get adviceActivity;

  /// No description provided for @adviceAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Alcohol: plan alcohol-free days first, then shrink portion size on drinking days. This often improves sleep and next-day BP.'**
  String get adviceAlcohol;

  /// No description provided for @adviceNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition: upgrade one meal today — more plants and protein, less ultra-processed snacks. Re-scan a meal for fresh feedback.'**
  String get adviceNutrition;

  /// No description provided for @adviceWellness.
  ///
  /// In en, this message translates to:
  /// **'Wellness: protect a consistent sleep window and do one short recovery block daily (breathing, stretch, or outdoor light). Retake the Wellness Check after a few days.'**
  String get adviceWellness;

  /// No description provided for @advicePsychotest.
  ///
  /// In en, this message translates to:
  /// **'PsychoTest load: reduce stacked stressors where you can, and use brief body-calming routines. Retake PsychoTest when life is calmer to see the Index move.'**
  String get advicePsychotest;

  /// No description provided for @adviceScreenTime.
  ///
  /// In en, this message translates to:
  /// **'Screen time: set a hard evening cutoff and replace one scroll session with movement — it supports both activity and wellness scores.'**
  String get adviceScreenTime;

  /// No description provided for @adviceHeartRate1.
  ///
  /// In en, this message translates to:
  /// **'Heart rate: open Heart Rate & Rhythm after wearing your Apple Watch. Aim for calm evenings and consistent sleep — resting HR often improves with recovery.'**
  String get adviceHeartRate1;

  /// No description provided for @adviceHeartRate2.
  ///
  /// In en, this message translates to:
  /// **'If resting heart rate stays high for several days or irregular rhythm alerts continue, discuss them with a clinician and keep logging how you feel.'**
  String get adviceHeartRate2;

  /// No description provided for @adviceStress.
  ///
  /// In en, this message translates to:
  /// **'Elevated pulse without much activity often points to stress or poor recovery — prioritize sleep, short walks, and retake the Wellness Check.'**
  String get adviceStress;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @aiOfflineSleep1.
  ///
  /// In en, this message translates to:
  /// **'Getting adequate sleep is crucial for your health. Aim for 7-9 hours per night. Try maintaining a consistent sleep schedule and creating a relaxing bedtime routine.'**
  String get aiOfflineSleep1;

  /// No description provided for @aiOfflineSleep2.
  ///
  /// In en, this message translates to:
  /// **'Sleep affects your immune system, mood, and metabolism. If you\'re having trouble sleeping, consider limiting screen time before bed and avoiding caffeine late in the day.'**
  String get aiOfflineSleep2;

  /// No description provided for @aiOfflineExercise1.
  ///
  /// In en, this message translates to:
  /// **'Regular physical activity is key to good health. Aim for at least 150 minutes of moderate exercise per week. Find activities you enjoy!'**
  String get aiOfflineExercise1;

  /// No description provided for @aiOfflineExercise2.
  ///
  /// In en, this message translates to:
  /// **'Exercise improves cardiovascular health, mood, and energy levels. Start with activities you enjoy and gradually increase intensity.'**
  String get aiOfflineExercise2;

  /// No description provided for @aiOfflineStress1.
  ///
  /// In en, this message translates to:
  /// **'Managing stress is important for your well-being. Try meditation, deep breathing exercises, or activities you find relaxing.'**
  String get aiOfflineStress1;

  /// No description provided for @aiOfflineStress2.
  ///
  /// In en, this message translates to:
  /// **'High stress can affect your physical and mental health. Consider talking to someone you trust or seeking professional support if needed.'**
  String get aiOfflineStress2;

  /// No description provided for @aiOfflineNutrition1.
  ///
  /// In en, this message translates to:
  /// **'A balanced diet with plenty of fruits, vegetables, and whole grains supports your health. Stay hydrated and limit processed foods.'**
  String get aiOfflineNutrition1;

  /// No description provided for @aiOfflineNutrition2.
  ///
  /// In en, this message translates to:
  /// **'Good nutrition provides energy and supports all body functions. Consider consulting a nutritionist for personalized advice.'**
  String get aiOfflineNutrition2;

  /// No description provided for @aiOfflineWeight1.
  ///
  /// In en, this message translates to:
  /// **'Maintaining a healthy weight requires balanced diet and regular exercise. Small, sustainable changes are more effective than drastic ones.'**
  String get aiOfflineWeight1;

  /// No description provided for @aiOfflineWeight2.
  ///
  /// In en, this message translates to:
  /// **'Your weight is just one aspect of health. Focus on how you feel and building healthy habits rather than the number on the scale.'**
  String get aiOfflineWeight2;

  /// No description provided for @aiOfflineDefault1.
  ///
  /// In en, this message translates to:
  /// **'That\'s a great health question! Focus on balanced nutrition, regular exercise, adequate sleep, and stress management for overall wellness.'**
  String get aiOfflineDefault1;

  /// No description provided for @aiOfflineDefault2.
  ///
  /// In en, this message translates to:
  /// **'Taking care of your physical and mental health is important. Don\'t hesitate to consult with healthcare professionals for personalized advice.'**
  String get aiOfflineDefault2;

  /// No description provided for @clinicalBmiValue.
  ///
  /// In en, this message translates to:
  /// **'BMI {bmi}'**
  String clinicalBmiValue(String bmi);

  /// No description provided for @clinicalRecMetabolicCluster.
  ///
  /// In en, this message translates to:
  /// **'Several warning signs are present together (weight, blood pressure, or blood sugar). Lose a little weight if you can, eat more plants and less salt, walk most days, and ask your doctor for cholesterol and sugar blood tests.'**
  String get clinicalRecMetabolicCluster;

  /// No description provided for @clinicalRecCombinedHigh.
  ///
  /// In en, this message translates to:
  /// **'More than one risk is elevated. Book a checkup soon so your doctor can review blood pressure, blood sugar, and cholesterol with you.'**
  String get clinicalRecCombinedHigh;

  /// No description provided for @clinicalRecWeightLoss5to7.
  ///
  /// In en, this message translates to:
  /// **'Aim for a gentle 5–7% weight loss over a few months — that alone often improves blood pressure and blood sugar.'**
  String get clinicalRecWeightLoss5to7;

  /// No description provided for @clinicalRecPrediabetes.
  ///
  /// In en, this message translates to:
  /// **'Your sugar is in the prediabetes range. Cut sugary drinks, walk after meals, and recheck fasting glucose or HbA1c with your doctor.'**
  String get clinicalRecPrediabetes;

  /// No description provided for @clinicalRecHighBp.
  ///
  /// In en, this message translates to:
  /// **'Your blood pressure is high. Reduce salt, stay active, measure BP at home for a few days, and share the averages with your doctor.'**
  String get clinicalRecHighBp;

  /// No description provided for @clinicalMetabolicInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet. Log blood pressure, blood sugar, and weight (and waist if you can) so we can spot metabolic warning signs.'**
  String get clinicalMetabolicInsufficient;

  /// No description provided for @clinicalMetabolicPresent.
  ///
  /// In en, this message translates to:
  /// **'Several risk factors are present together (weight, blood pressure, or blood sugar). This raises heart and diabetes risk — see a doctor for cholesterol and sugar tests, and improve diet and activity.'**
  String get clinicalMetabolicPresent;

  /// No description provided for @clinicalMetabolicPartial.
  ///
  /// In en, this message translates to:
  /// **'A couple of warning signs are present. Improve diet, walk more, and watch weight — small changes help a lot.'**
  String get clinicalMetabolicPartial;

  /// No description provided for @clinicalMetabolicOk.
  ///
  /// In en, this message translates to:
  /// **'From the data we have, metabolic warning signs look under control.'**
  String get clinicalMetabolicOk;

  /// No description provided for @clinicalRiskMsgHigh.
  ///
  /// In en, this message translates to:
  /// **'Several risks are elevated together. This is a strong signal to improve food and activity and see a doctor for a checkup.'**
  String get clinicalRiskMsgHigh;

  /// No description provided for @clinicalRiskMsgModerate.
  ///
  /// In en, this message translates to:
  /// **'Your overall heart and sugar risk is higher than ideal. Small daily changes — walks, less salt and sugar — make a real difference.'**
  String get clinicalRiskMsgModerate;

  /// No description provided for @clinicalRiskMsgLow.
  ///
  /// In en, this message translates to:
  /// **'Your overall heart and sugar risk looks relatively low based on weight, blood pressure, and blood sugar.'**
  String get clinicalRiskMsgLow;

  /// No description provided for @clinicalFlagExtraWeightTitle.
  ///
  /// In en, this message translates to:
  /// **'Extra weight'**
  String get clinicalFlagExtraWeightTitle;

  /// No description provided for @clinicalFlagExtraWeightBody.
  ///
  /// In en, this message translates to:
  /// **'Carrying extra weight raises the chance of high blood sugar and heart problems. Smaller portions, more vegetables, and daily walks help.'**
  String get clinicalFlagExtraWeightBody;

  /// No description provided for @clinicalFlagTripleTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight + BP + sugar'**
  String get clinicalFlagTripleTitle;

  /// No description provided for @clinicalFlagTripleBody.
  ///
  /// In en, this message translates to:
  /// **'Extra weight, higher blood pressure, and higher blood sugar together greatly raise diabetes and heart risk. Focus on food, walks, and a doctor visit.'**
  String get clinicalFlagTripleBody;

  /// No description provided for @clinicalFlagLowWeightBpTitle.
  ///
  /// In en, this message translates to:
  /// **'Low weight + low BP'**
  String get clinicalFlagLowWeightBpTitle;

  /// No description provided for @clinicalFlagLowWeightBpBody.
  ///
  /// In en, this message translates to:
  /// **'Low weight with low blood pressure in older age can mean frailty. Eat enough protein and ask a doctor before cutting calories.'**
  String get clinicalFlagLowWeightBpBody;

  /// No description provided for @clinicalFlagLeanDiabetesTitle.
  ///
  /// In en, this message translates to:
  /// **'High sugar, not much weight'**
  String get clinicalFlagLeanDiabetesTitle;

  /// No description provided for @clinicalFlagLeanDiabetesBody.
  ///
  /// In en, this message translates to:
  /// **'Blood sugar is high even without much extra weight. A doctor should check what type of diabetes this might be.'**
  String get clinicalFlagLeanDiabetesBody;

  /// No description provided for @clinicalFlagYoungHtnTitle.
  ///
  /// In en, this message translates to:
  /// **'High BP under 40'**
  String get clinicalFlagYoungHtnTitle;

  /// No description provided for @clinicalFlagYoungHtnBody.
  ///
  /// In en, this message translates to:
  /// **'High blood pressure at a young age should be confirmed with repeat readings. Ask a doctor if another cause needs checking.'**
  String get clinicalFlagYoungHtnBody;

  /// No description provided for @clinicalAgePediatric.
  ///
  /// In en, this message translates to:
  /// **'Pediatric percentiles apply under 18 — adult BMI/BP/glucose cut-offs are not used here.'**
  String get clinicalAgePediatric;

  /// No description provided for @clinicalAge45WeightSugar.
  ///
  /// In en, this message translates to:
  /// **'After 45, extra weight plus higher blood sugar raise diabetes risk. Ask your doctor about a sugar check every 1–3 years.'**
  String get clinicalAge45WeightSugar;

  /// No description provided for @clinicalAge60Systolic.
  ///
  /// In en, this message translates to:
  /// **'After 60, the top blood-pressure number often rises first. Track home averages and share them with your doctor.'**
  String get clinicalAge60Systolic;

  /// No description provided for @clinicalAge65Target.
  ///
  /// In en, this message translates to:
  /// **'Over 65, many people aim for blood pressure under 140/90 if they feel well. Your doctor may set a different target if you are frail.'**
  String get clinicalAge65Target;

  /// No description provided for @clinicalAgeYoungDiabetesLean.
  ///
  /// In en, this message translates to:
  /// **'Under 40 with high blood sugar but normal weight — see a doctor to find out what type of diabetes this might be.'**
  String get clinicalAgeYoungDiabetesLean;

  /// No description provided for @clinicalBpOlderAdultSuffix.
  ///
  /// In en, this message translates to:
  /// **'In older adults, the top number often rises first — focus on that trend and share home averages with your doctor.'**
  String get clinicalBpOlderAdultSuffix;

  /// No description provided for @notifMorningShort.
  ///
  /// In en, this message translates to:
  /// **'Yesterday: {steps} steps (goal {goal}), meals {kcal} kcal. Health Index {score}/100 — {status}.'**
  String notifMorningShort(
    int steps,
    int goal,
    int kcal,
    int score,
    String status,
  );

  /// No description provided for @notifEveningShort.
  ///
  /// In en, this message translates to:
  /// **'Today {today} steps vs yesterday {yesterday}. Health Index {score}/100 — {status}.'**
  String notifEveningShort(int today, int yesterday, int score, String status);

  /// No description provided for @notifOpenHealthInsights.
  ///
  /// In en, this message translates to:
  /// **'Open Health Insights'**
  String get notifOpenHealthInsights;

  /// No description provided for @mealIntakeChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Calories from meals'**
  String get mealIntakeChartTitle;

  /// No description provided for @mealZoneDeficit.
  ///
  /// In en, this message translates to:
  /// **'≤{max} kcal — deficit (weight loss)'**
  String mealZoneDeficit(int max);

  /// No description provided for @mealZoneModerate.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} kcal — maintenance zone'**
  String mealZoneModerate(int min, int max);

  /// No description provided for @mealZoneSurplus.
  ///
  /// In en, this message translates to:
  /// **'>{max} kcal — surplus (weight gain risk)'**
  String mealZoneSurplus(int max);

  /// No description provided for @aiDocUploadedAnalysis.
  ///
  /// In en, this message translates to:
  /// **'I uploaded my analysis: {fileName}'**
  String aiDocUploadedAnalysis(String fileName);

  /// No description provided for @uploadDicom.
  ///
  /// In en, this message translates to:
  /// **'DICOM (medical imaging)'**
  String get uploadDicom;

  /// No description provided for @fileTypeDicom.
  ///
  /// In en, this message translates to:
  /// **'DICOM (.dcm) — in-depth AI pathology review'**
  String get fileTypeDicom;

  /// No description provided for @uploadAnalyzingDicom.
  ///
  /// In en, this message translates to:
  /// **'Analyzing DICOM with Ai Doc — thorough pathology review…'**
  String get uploadAnalyzingDicom;

  /// No description provided for @actionHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate & Rhythm'**
  String get actionHeartRate;

  /// No description provided for @actionHeartRateDesc.
  ///
  /// In en, this message translates to:
  /// **'Heart check with Smart Watch'**
  String get actionHeartRateDesc;

  /// No description provided for @unitBpm.
  ///
  /// In en, this message translates to:
  /// **'bpm'**
  String get unitBpm;

  /// No description provided for @unitMs.
  ///
  /// In en, this message translates to:
  /// **'ms'**
  String get unitMs;

  /// No description provided for @hrEvents.
  ///
  /// In en, this message translates to:
  /// **'events'**
  String get hrEvents;

  /// No description provided for @hrCurrent.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get hrCurrent;

  /// No description provided for @hrResting.
  ///
  /// In en, this message translates to:
  /// **'Resting'**
  String get hrResting;

  /// No description provided for @hrWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get hrWalking;

  /// No description provided for @hrHrv.
  ///
  /// In en, this message translates to:
  /// **'HRV'**
  String get hrHrv;

  /// No description provided for @hrAvg.
  ///
  /// In en, this message translates to:
  /// **'Avg heart rate'**
  String get hrAvg;

  /// No description provided for @hrStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get hrStatus;

  /// No description provided for @hrStatusNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get hrStatusNormal;

  /// No description provided for @hrStatusAttention.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get hrStatusAttention;

  /// No description provided for @hrStatusRisk.
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get hrStatusRisk;

  /// No description provided for @hrNormRange.
  ///
  /// In en, this message translates to:
  /// **'Resting range'**
  String get hrNormRange;

  /// No description provided for @hrNormRangeShort.
  ///
  /// In en, this message translates to:
  /// **'{low}–{high} bpm'**
  String hrNormRangeShort(int low, int high);

  /// No description provided for @hrReading.
  ///
  /// In en, this message translates to:
  /// **'Reading heart data…'**
  String get hrReading;

  /// No description provided for @hrReadingHint.
  ///
  /// In en, this message translates to:
  /// **'Syncing heart rate and rhythm from your Apple Watch via Apple Health.'**
  String get hrReadingHint;

  /// No description provided for @hrLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get hrLive;

  /// No description provided for @hrStale.
  ///
  /// In en, this message translates to:
  /// **'Last reading'**
  String get hrStale;

  /// No description provided for @hrUpdatedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Sample just now'**
  String get hrUpdatedJustNow;

  /// No description provided for @hrUpdatedSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'Sample {seconds}s ago'**
  String hrUpdatedSecondsAgo(int seconds);

  /// No description provided for @hrUpdatedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Sample {minutes}m ago'**
  String hrUpdatedMinutesAgo(int minutes);

  /// No description provided for @hrRefreshSame.
  ///
  /// In en, this message translates to:
  /// **'No newer sample in Apple Health yet'**
  String get hrRefreshSame;

  /// No description provided for @hrRefreshOk.
  ///
  /// In en, this message translates to:
  /// **'Loaded latest Apple Health sample'**
  String get hrRefreshOk;

  /// No description provided for @hrStaleHint.
  ///
  /// In en, this message translates to:
  /// **'No heart rate from your device. Put on your Apple Watch or fitness band.'**
  String get hrStaleHint;

  /// No description provided for @hrNoDeviceData.
  ///
  /// In en, this message translates to:
  /// **'No heart rate from your device. Put on your Apple Watch or fitness band.'**
  String get hrNoDeviceData;

  /// No description provided for @hrNeedPermission.
  ///
  /// In en, this message translates to:
  /// **'Apple Health access needed'**
  String get hrNeedPermission;

  /// No description provided for @hrNeedPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Allow PHA to read Heart Rate, Resting Heart Rate, HRV, and Irregular Rhythm from Apple Health.'**
  String get hrNeedPermissionBody;

  /// No description provided for @hrGrantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant access'**
  String get hrGrantAccess;

  /// No description provided for @hrNoData.
  ///
  /// In en, this message translates to:
  /// **'No heart data yet. Wear your Apple Watch, then tap Refresh. Make sure Heart Rate is enabled in Apple Health.'**
  String get hrNoData;

  /// No description provided for @hrRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get hrRefresh;

  /// No description provided for @hrExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get hrExport;

  /// No description provided for @hrExportTitle.
  ///
  /// In en, this message translates to:
  /// **'PHA Heart Rate & Rhythm summary'**
  String get hrExportTitle;

  /// No description provided for @hrExportCopied.
  ///
  /// In en, this message translates to:
  /// **'Summary copied to clipboard'**
  String get hrExportCopied;

  /// No description provided for @hrDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This is not a medical device. Smart-watch data does not replace a doctor’s advice. Seek care if you feel unwell.'**
  String get hrDisclaimer;

  /// No description provided for @hrChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart rate trend'**
  String get hrChartTitle;

  /// No description provided for @hrRange24h.
  ///
  /// In en, this message translates to:
  /// **'24h'**
  String get hrRange24h;

  /// No description provided for @hrRange7d.
  ///
  /// In en, this message translates to:
  /// **'7d'**
  String get hrRange7d;

  /// No description provided for @hrRange30d.
  ///
  /// In en, this message translates to:
  /// **'30d'**
  String get hrRange30d;

  /// No description provided for @hrNoChartData.
  ///
  /// In en, this message translates to:
  /// **'No chart data for this period'**
  String get hrNoChartData;

  /// No description provided for @hrWhatItMeans.
  ///
  /// In en, this message translates to:
  /// **'What this means'**
  String get hrWhatItMeans;

  /// No description provided for @hrWhatItMeansBody.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate and HRV reflect stress, recovery, and fitness. Sudden jumps or several high days in a row deserve attention.'**
  String get hrWhatItMeansBody;

  /// No description provided for @hrEcgTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent ECG (Apple Watch)'**
  String get hrEcgTitle;

  /// No description provided for @hrEcgSinusRhythm.
  ///
  /// In en, this message translates to:
  /// **'Sinus rhythm'**
  String get hrEcgSinusRhythm;

  /// No description provided for @hrEcgAtrialFibrillation.
  ///
  /// In en, this message translates to:
  /// **'Atrial fibrillation'**
  String get hrEcgAtrialFibrillation;

  /// No description provided for @hrEcgLowOrHighHr.
  ///
  /// In en, this message translates to:
  /// **'Low or high heart rate'**
  String get hrEcgLowOrHighHr;

  /// No description provided for @hrEcgInconclusive.
  ///
  /// In en, this message translates to:
  /// **'Inconclusive'**
  String get hrEcgInconclusive;

  /// No description provided for @hrEcgNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not classified'**
  String get hrEcgNotSet;

  /// No description provided for @hrIrregularRhythm.
  ///
  /// In en, this message translates to:
  /// **'Irregular rhythm alerts'**
  String get hrIrregularRhythm;

  /// No description provided for @hrTrendImproving.
  ///
  /// In en, this message translates to:
  /// **'Improving'**
  String get hrTrendImproving;

  /// No description provided for @hrTrendWorsening.
  ///
  /// In en, this message translates to:
  /// **'Worsening'**
  String get hrTrendWorsening;

  /// No description provided for @hrTrendStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get hrTrendStable;

  /// No description provided for @hrTrendUnknown.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get hrTrendUnknown;

  /// No description provided for @hrExplainNormal.
  ///
  /// In en, this message translates to:
  /// **'Your resting heart rate looks within a healthy wellness range for you.'**
  String get hrExplainNormal;

  /// No description provided for @hrExplainHighResting.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate is {bpm} bpm — above the usual {max} bpm comfort range. Stress, illness, caffeine, or low recovery can raise it.'**
  String hrExplainHighResting(int bpm, int max);

  /// No description provided for @hrExplainLowResting.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate is {bpm} bpm — below the usual {min} bpm range. Athletes often run lower; seek care if you feel dizzy or weak.'**
  String hrExplainLowResting(int bpm, int min);

  /// No description provided for @hrExplainLowHrv.
  ///
  /// In en, this message translates to:
  /// **'Heart-rate variability looks low. That can mean higher stress or incomplete recovery — prioritize sleep and rest.'**
  String get hrExplainLowHrv;

  /// No description provided for @hrExplainElevatedStreak.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate has stayed in the 80–95 bpm range for several days. Watch for stress, overtraining, or early illness.'**
  String get hrExplainElevatedStreak;

  /// No description provided for @hrExplainSpike.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate rose sharply day to day. Note how you feel and recheck tomorrow.'**
  String get hrExplainSpike;

  /// No description provided for @hrExplainIrregular.
  ///
  /// In en, this message translates to:
  /// **'Apple Watch reported irregular rhythm notifications. This is not a diagnosis — discuss with a clinician if alerts continue or you feel unwell.'**
  String get hrExplainIrregular;

  /// No description provided for @hrAlertRiskTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart rate alarm'**
  String get hrAlertRiskTitle;

  /// No description provided for @hrAlertAttentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Elevated resting heart rate'**
  String get hrAlertAttentionTitle;

  /// No description provided for @hrAlertGenericBody.
  ///
  /// In en, this message translates to:
  /// **'Your resting heart rate is stably high (80–95 bpm) or rising day to day. Open Heart Rate & Rhythm for details.'**
  String get hrAlertGenericBody;

  /// No description provided for @hrRestingChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate'**
  String get hrRestingChartTitle;

  /// No description provided for @hrAvgResting.
  ///
  /// In en, this message translates to:
  /// **'Avg {bpm} bpm'**
  String hrAvgResting(int bpm);

  /// No description provided for @hrZoneNormal.
  ///
  /// In en, this message translates to:
  /// **'Green — {low}–{high} bpm (normal)'**
  String hrZoneNormal(int low, int high);

  /// No description provided for @hrZoneAttention.
  ///
  /// In en, this message translates to:
  /// **'Yellow — mild deviation'**
  String get hrZoneAttention;

  /// No description provided for @hrZoneRisk.
  ///
  /// In en, this message translates to:
  /// **'Red — significant deviation / risk'**
  String get hrZoneRisk;
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
      <String>['ar', 'en', 'es', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
