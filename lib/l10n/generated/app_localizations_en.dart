// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PHA — Personal Health Assistant';

  @override
  String get appNameShort => 'PHA';

  @override
  String get personalHealthAssistant => 'Personal Health Assistant';

  @override
  String get tagline => 'Your health, our priority';

  @override
  String get taglineBody =>
      'Track, analyze and improve your health with PHA. Your data stays private and secure.';

  @override
  String get startingPha => 'Starting PHA…';

  @override
  String get loading => 'Loading…';

  @override
  String get startupFailed => 'Startup failed';

  @override
  String get noContent => 'No content';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get save => 'Save';

  @override
  String get continueAction => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get noDataYet => 'No data yet';

  @override
  String get noData => 'No data';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navInsights => 'Insights';

  @override
  String get navProfile => 'Profile';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get healthIndex => 'Health Index';

  @override
  String get healthMetrics => 'Health Metrics';

  @override
  String get steps => 'Steps';

  @override
  String get calories => 'Calories';

  @override
  String get distance => 'Distance';

  @override
  String get activeTime => 'Active Time';

  @override
  String get weight => 'Weight';

  @override
  String get height => 'Height';

  @override
  String get water => 'Water';

  @override
  String get bloodGlucose => 'Blood Glucose';

  @override
  String get bloodPressure => 'Blood Pressure';

  @override
  String get bpSystolic => 'BP Systolic';

  @override
  String get bpDiastolic => 'BP Diastolic';

  @override
  String get language => 'Language';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get chooseLanguageSubtitle => 'You can change this later in Profile.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageChinese => '普通话';

  @override
  String get languageArabic => 'العربية';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appearance => 'Appearance';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get createYourAccount => 'Create your account';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get createAccount => 'Create account';

  @override
  String get signUpForFree => 'Sign up for free';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Sign up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get displayName => 'Display Name';

  @override
  String get yourName => 'Your name';

  @override
  String get signOut => 'Sign out';

  @override
  String get account => 'Account';

  @override
  String get agreement => 'Agreement';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get acceptAgreement => 'I accept the Agreement';

  @override
  String get acceptPrivacy => 'I accept the Privacy Policy';

  @override
  String get pleaseAcceptLegal =>
      'Please read and accept the Agreement and Privacy Policy to continue.';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters.';

  @override
  String get featureTrackVitals => 'Track vitals & glucose';

  @override
  String get featureAiInsights => 'AI health insights';

  @override
  String get featureSmartAnalysis => 'Smart analysis';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSubtitle => 'Manage your account settings';

  @override
  String get age => 'Age';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get historyTitle => 'Health History';

  @override
  String get historySubtitle => 'Your recorded health metrics over time';

  @override
  String get stepsChartTitle => 'Steps';

  @override
  String stepsAvgPerDay(String avg) {
    return 'Avg $avg/day';
  }

  @override
  String get days7 => '7 days';

  @override
  String get days30 => '30 days';

  @override
  String get days90 => '90 days';

  @override
  String get allFilter => 'All';

  @override
  String recordsCount(int count) {
    return '$count records';
  }

  @override
  String get recordCountOne => '1 record';

  @override
  String get noMetricsYet => 'No metrics recorded yet';

  @override
  String get noMetricsHint =>
      'Use the Log button on the dashboard to start tracking your health.';

  @override
  String get insightsTitle => 'Health Insights';

  @override
  String get insightsSubtitle => 'Trends and patterns from your health data';

  @override
  String get avgHealthIndex => 'Avg Health Index';

  @override
  String get avgWellnessScore => 'Avg Wellness Score';

  @override
  String get stepTrend => 'Step Trend';

  @override
  String get healthIndexHistory => 'Health Index History';

  @override
  String get wellnessCheckHistory => 'Wellness Check History';

  @override
  String get stepActivity => 'Step Activity';

  @override
  String lastNDays(int count) {
    return 'Last $count days';
  }

  @override
  String minLabel(String value) {
    return 'Min: $value';
  }

  @override
  String avgLabel(String value) {
    return 'Avg: $value';
  }

  @override
  String maxLabel(String value) {
    return 'Max: $value';
  }

  @override
  String get noInsightsYet => 'No insights yet';

  @override
  String get noInsightsHint =>
      'Start tracking your health metrics and completing wellness checks to see insights here.';

  @override
  String get noHealthIndexYet => 'No health index data recorded yet';

  @override
  String get noWellnessYet =>
      'No wellness checks yet. Try the Wellness Check on the home screen.';

  @override
  String get healthAnalysis => 'Health Analysis';

  @override
  String get healthAnalysisSubtitle =>
      'Same score as Health Index, with findings & advice';

  @override
  String get analyze => 'Analyze';

  @override
  String get reAnalyze => 'Re-analyze';

  @override
  String get analyzing => 'Analyzing…';

  @override
  String get noAnalysisYet =>
      'No analysis yet. Press Analyze to get a personalized health conclusion based on your logged metrics.';

  @override
  String get metricFindings => 'Metric Findings';

  @override
  String get recommendations => 'Recommendations';

  @override
  String lastAnalyzed(String when) {
    return 'Last analyzed: $when';
  }

  @override
  String get statusExcellent => 'Excellent';

  @override
  String get statusGood => 'Good';

  @override
  String get statusFair => 'Fair';

  @override
  String get statusNeedsAttention => 'Needs Attention';

  @override
  String get actionUploadAnalysis => 'Upload Analysis';

  @override
  String get actionUploadAnalysisDesc => 'Analyze PDFs or photos';

  @override
  String get actionAiConsultation => 'AI Consultation';

  @override
  String get actionAiConsultationDesc => 'Chat with Ai Doc';

  @override
  String get actionWellnessCheck => 'Wellness Check';

  @override
  String get actionWellnessCheckDesc => 'Check your wellbeing';

  @override
  String get actionBadHabits => 'Check Your Bad Habits';

  @override
  String get actionBadHabitsDesc => 'Smoking, alcohol & screen time';

  @override
  String get actionPhysicalActivity => 'Start physical activity';

  @override
  String get actionPhysicalActivityDesc => 'Choose your daily workout program';

  @override
  String get actionMealCalories => 'Check Meal Calories';

  @override
  String get actionMealCaloriesDesc => 'Photo → calories & nutrition advice';

  @override
  String get actionPsychoTest => 'PsychoTest';

  @override
  String get actionPsychoTestDesc => 'Stress & psychosomatic assessment';

  @override
  String get actionTreatmentSchedule => 'Treatment Schedule';

  @override
  String get actionTreatmentScheduleDesc => 'Medicines & supplements reminders';

  @override
  String get actionFamilyHealth => 'Family Health Tracking';

  @override
  String get actionFamilyHealthDesc => 'Add your family to track their health';

  @override
  String get logMetric => 'Log';

  @override
  String get todayVitals => 'Today\'s vitals';

  @override
  String get onboardingQuest1TitleBefore => 'Quest 1: Choose your world';

  @override
  String get onboardingQuest1TitleAfter => 'Pick your units';

  @override
  String get onboardingQuest1BodyBefore =>
      'Start your health journey — 3 quick quests, then sign up.';

  @override
  String get onboardingQuest1BodyAfter =>
      'Tailor charts and tips to your region.';

  @override
  String get onboardingQuest1CardTitle => 'Quest 1 · Measurement realm';

  @override
  String get onboardingQuest1CardSubtitle => 'Unlock charts in your language';

  @override
  String get imperial => 'Imperial';

  @override
  String get imperialUnits => 'ft · lbs · mg/dL';

  @override
  String get metric => 'Metric';

  @override
  String get metricUnits => 'cm · kg · mmol/L';

  @override
  String get startQuest1 => 'Start Quest 1 →';

  @override
  String get onboardingQuest2Title => 'Quest 2: About you';

  @override
  String get onboardingQuest3Title => 'Quest 3: Your vitals';

  @override
  String get onboardingVictoryTitle => 'You\'re ready!';

  @override
  String get onboardingVictoryBody => 'Your health journey starts now.';

  @override
  String get activityYourPlan => 'Your activity plan';

  @override
  String get activityCurrentPlan => 'Current plan';

  @override
  String get activityWhatsIncluded => 'What\'s included';

  @override
  String get activityChangePlan => 'Change plan';

  @override
  String get activityStartTitle => 'Start physical activity';

  @override
  String get activityChangeTitle => 'Change plan';

  @override
  String get activityChooseProgram =>
      'Choose your program. Start your daily physical activity.';

  @override
  String get activityChangeHint =>
      'Pick a new program. Your evening check-in will follow the new plan.';

  @override
  String get activityKeepCurrent => 'Keep current plan';

  @override
  String get activityProgramStarted => 'Program started';

  @override
  String get activityProgramSaved =>
      'Your daily physical activity plan is saved. Every evening we will ask if you completed it.';

  @override
  String get activityStartThis => 'Start this program';

  @override
  String get activitySwitchToThis => 'Switch to this plan';

  @override
  String get activityChooseAnother => 'Choose another';

  @override
  String get activityCurrentBadge => 'Current';

  @override
  String get activityStarter => 'Starter';

  @override
  String get activityStarterSubtitle => 'Begin your daily physical activity';

  @override
  String get activityAdvanced => 'Advanced';

  @override
  String get activityAdvancedSubtitle =>
      'Build consistency with structured sets';

  @override
  String get activityProfessional => 'Professional';

  @override
  String get activityProfessionalSubtitle =>
      'High-volume daily bodyweight training';

  @override
  String get activitySuperman => 'Superman';

  @override
  String get activitySupermanSubtitle => 'Gym-based vigorous training';

  @override
  String get partially => 'Partially';

  @override
  String get notifications => 'Notifications';

  @override
  String get phaPlus => 'PHA Plus+';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get trialExpired => 'Trial expired';

  @override
  String get unitSteps => 'steps';

  @override
  String get unitKcal => 'kcal';

  @override
  String get unitMin => 'min';

  @override
  String get unitMl => 'ml';

  @override
  String get unitMmhg => 'mmHg';

  @override
  String get healthOverviewToday => 'Here\'s your health overview for today.';

  @override
  String get unitYears => 'yrs';

  @override
  String get unitKg => 'kg';

  @override
  String get unitCm => 'cm';

  @override
  String get unitLbs => 'lbs';

  @override
  String get unitMmol => 'mmol/L';

  @override
  String get unitMgdl => 'mg/dL';

  @override
  String get unitKm => 'km';

  @override
  String get unitMiles => 'miles';

  @override
  String healthIndexAvgScore(int score) {
    return 'Avg $score/100';
  }

  @override
  String get indexCardExcellent => 'Excellent — keep it up.';

  @override
  String get indexCardGood => 'You\'re doing well.';

  @override
  String get indexCardFair => 'Some areas need attention.';

  @override
  String get indexCardNeedsAttention => 'Needs focus — review your habits.';

  @override
  String get stepsMsgSedentary =>
      'Low activity today. Start with a 15-minute walk — consistency beats intensity for long-term heart health.';

  @override
  String stepsMsgBuilding(int goal) {
    return 'You are building a walking habit. Aim toward $goal+ steps for stronger cardiometabolic benefit.';
  }

  @override
  String stepsMsgBaseline(int goal) {
    return 'Solid baseline activity. A few more short walks can reach the $goal+ range many guidelines treat as beneficial.';
  }

  @override
  String stepsMsgStrong(int goal) {
    return 'Strong activity level — well above sedentary. Keep this rhythm; $goal steps is a bonus goal, not a must.';
  }

  @override
  String stepsMsgGoal(int goal) {
    return 'Excellent activity level — you are meeting the classic $goal-step day.';
  }

  @override
  String stepsRangeSedentary(String max) {
    return '0–$max steps';
  }

  @override
  String stepsRangeBuilding(String min, String max) {
    return '$min–$max steps';
  }

  @override
  String stepsRangeBaseline(String min, String max) {
    return '$min–$max steps';
  }

  @override
  String stepsRangeStrong(String min, String max) {
    return '$min–$max steps';
  }

  @override
  String stepsRangeGoal(String min) {
    return '$min+ steps';
  }

  @override
  String get todaysNotifications => 'Today\'s notifications';

  @override
  String get morningNotificationTitle => 'Good morning — your health recap';

  @override
  String get noNotificationsToday => 'No notifications for today yet.';

  @override
  String get notificationsAppearHere =>
      'Notifications that already arrived today appear here.';

  @override
  String get phaPlusUnlockedTitle => 'You\'re on PHA Plus+!';

  @override
  String get phaPlusUnlockedBody =>
      'All features are now unlocked. Enjoy unlimited uploads, PsychoTest, and Treatment Schedule.';

  @override
  String get onboardingQuest2BuildAvatar => 'Quest 2: Build your avatar';

  @override
  String onboardingQuest2FillFields(int hp) {
    return 'Fill all 3 fields — earn +$hp HP on complete.';
  }

  @override
  String get rewardedStats => 'Rewarded stats';

  @override
  String get yourGender => 'Your gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get unitYearsLong => 'years';

  @override
  String completeQuest2(int hp) {
    return 'Complete Quest 2 (+$hp HP)';
  }

  @override
  String get backToQuest2 => 'Back to Quest 2';

  @override
  String get onboardingQuest3PowerUp => 'Quest 3: Power-up (bonus)';

  @override
  String get onboardingQuest3BpDone =>
      'You already logged BP and glucose today. Come back tomorrow for your next reading.';

  @override
  String onboardingQuest3Optional(int bpHp, int glucoseHp) {
    return 'Optional vitals — +$bpHp HP for BP, +$glucoseHp HP for glucose. Once per day.';
  }

  @override
  String get onboardingAllQuestsComplete => 'All quests complete!';

  @override
  String onboardingEarnedHp(int hp, int level, String title) {
    return 'You earned $hp HP · Level $level $title';
  }

  @override
  String get onboardingBonusVitals => 'Bonus vitals unlocked extra insights!';

  @override
  String get healthPower => 'Health Power';

  @override
  String get onboardingCreateAccount => 'Create account and become healthy →';

  @override
  String get onboardingEnterDashboard => 'Enter dashboard →';

  @override
  String get badgeUnitPro => 'Unit Pro';

  @override
  String get badgeFoundation => 'Foundation';

  @override
  String get badgeHeartTrack => 'Heart Track';

  @override
  String get badgeSugarSense => 'Sugar Sense';

  @override
  String get badgeChampion => 'Champion';

  @override
  String get levelHealthRookie => 'Health Rookie';

  @override
  String get levelProfileBuilder => 'Profile Builder';

  @override
  String get levelVitalsPro => 'Vitals Pro';

  @override
  String get picked => 'PICKED';

  @override
  String get saving => 'Saving…';

  @override
  String get claimBonusFinish => 'Claim bonus & finish 🏆';

  @override
  String get skipBonusQuest => 'Skip bonus quest';

  @override
  String get calculatingRewards => 'Calculating rewards…';

  @override
  String get categoryBloodPressure => 'Blood Pressure';

  @override
  String get categoryBloodGlucose => 'Blood Glucose';

  @override
  String get categoryWeight => 'Weight';

  @override
  String get categoryWeightBmi => 'Weight / BMI';

  @override
  String get categoryDailyActivity => 'Daily Activity';

  @override
  String get categoryCalorieBurn => 'Calorie Burn';

  @override
  String get categoryMentalWellness => 'Mental Wellness';

  @override
  String get categorySmoking => 'Smoking';

  @override
  String get categoryAlcohol => 'Alcohol';

  @override
  String get categoryScreenTime => 'Screen Time';

  @override
  String get categoryNutrition => 'Nutrition';

  @override
  String get categoryPsychoTest => 'PsychoTest';

  @override
  String get categoryActivity => 'Activity';

  @override
  String get categoryHeartRate => 'Heart Rate & Rhythm';

  @override
  String get categoryAge => 'Age';

  @override
  String get categoryStress => 'Stress (elevated pulse)';

  @override
  String get analysisSummaryExcellent => 'Your Health Index is excellent.';

  @override
  String get analysisSummaryGood => 'Your Health Index looks good overall.';

  @override
  String get analysisSummaryFair =>
      'Your Health Index is fair — a few levers will move it up.';

  @override
  String get analysisSummaryNeedsAttention =>
      'Your Health Index needs attention — focus on the highest-impact gaps below.';

  @override
  String get analysisSummaryDefault => 'Here is your health summary.';

  @override
  String analysisScoreMatches(int score) {
    return 'Score $score/100 matches the Home Health Index.';
  }

  @override
  String analysisStrengths(String names) {
    return 'Strengths: $names.';
  }

  @override
  String analysisBiggestDrag(String names) {
    return 'Biggest Index drag right now: $names.';
  }

  @override
  String get glucoseMsgHypoglycemia =>
      'Blood glucose is low (hypoglycemia). Eat something with fast-acting carbohydrates and consult your doctor.';

  @override
  String get glucoseMsgNormal =>
      'Fasting blood glucose is in the normal range. Good metabolic health.';

  @override
  String get glucoseMsgPrediabetes =>
      'Blood glucose is in the prediabetes range. Cut sugary drinks, add fiber at each meal, and walk 10–15 minutes after eating.';

  @override
  String get glucoseMsgDiabetes =>
      'Blood glucose is in the diabetes range. Please consult a healthcare provider for evaluation and a care plan.';

  @override
  String get bmiMsgWeightOnly =>
      'Weight is recorded. Add your height in Profile so we can score BMI in your Health Index.';

  @override
  String get bmiMsgUnderweight =>
      'Your weight is a bit low for your height. Eat protein-rich meals more often; ask a doctor if you did not mean to lose weight.';

  @override
  String get bmiMsgHealthy =>
      'Your weight looks healthy for your height. Well done!';

  @override
  String get bmiMsgOverweight =>
      'Your weight is a bit above the healthy range. Aim for a gentle weekly loss, keep protein up, and protect your daily steps.';

  @override
  String get bmiMsgObeseI =>
      'Your weight is clearly above the healthy range. This can raise blood pressure and blood sugar. Better food, more walking, and a doctor-guided plan help a lot.';

  @override
  String get bmiMsgObeseII =>
      'Your weight is well above the healthy range. Please see a doctor for a safe plan to protect your heart and metabolism.';

  @override
  String stepsLabel(String count) {
    return '$count steps';
  }

  @override
  String get calorieBurnGood =>
      'Calorie expenditure looks consistent with your steps. Pair it with balanced meals to support recovery.';

  @override
  String calorieBurnInfo(int calories) {
    return 'You burned $calories kcal from activity. Use meal logging to match intake to your goals.';
  }

  @override
  String get wellnessMsgExcellent =>
      'Excellent wellness score — low stress load and solid mental resilience.';

  @override
  String get wellnessMsgGood =>
      'Good wellness. Small upgrades in sleep or recovery can push you to excellent.';

  @override
  String get wellnessMsgModerate =>
      'Moderate wellness. Try a short wind-down: 5 minutes of breathing, a walk outside, or earlier lights-out.';

  @override
  String get wellnessMsgNeedsAttention =>
      'Wellness score suggests elevated stress. Protect sleep, reduce late caffeine, and reconnect socially this week.';

  @override
  String get wellnessMsgCritical =>
      'High stress load. Consider repeating the Wellness Check and talking with a mental health professional if this persists.';

  @override
  String get smokingGood =>
      'No smoking reported — one of the strongest protective factors for heart and lung health.';

  @override
  String get smokingLessPack => '<1 pack/day';

  @override
  String get smokingOnePack => '~1 pack/day';

  @override
  String get smokingMorePack => '>1 pack/day';

  @override
  String get smokingActive => 'Active smoker';

  @override
  String get smokingNonSmoker => 'Non-smoker';

  @override
  String get smokingWarning =>
      'Smoking is a top Health Index risk factor. Set a quit date, remove triggers, and use Plus+ → Check Your Bad Habits to track progress.';

  @override
  String get alcoholNone => 'None';

  @override
  String get alcoholGood =>
      'No alcohol use reported — helpful for BP, sleep, and liver health.';

  @override
  String get alcoholOccasional => 'Occasional';

  @override
  String get alcoholOccasionalTip =>
      'Keep alcohol occasional and alcohol-free most days of the week.';

  @override
  String get alcoholRegular => 'Regular';

  @override
  String get alcoholRegularTip =>
      'Cut toward fewer drinking days; alcohol raises BP and calorie load.';

  @override
  String get alcoholHeavy => 'Heavy';

  @override
  String get alcoholHeavyTip =>
      'Heavy use strongly hurts your Health Index — seek support to cut down safely.';

  @override
  String get alcoholDefault => 'Drinks alcohol';

  @override
  String get alcoholDefaultTip =>
      'Track frequency this week and aim for several alcohol-free days.';

  @override
  String get screenRarely => 'Rarely';

  @override
  String get screenRarelyTip =>
      'Low social-media load — good for sleep and focus.';

  @override
  String get screenUnderHour => '<1 h/day';

  @override
  String get screenUnderHourTip =>
      'Reasonable screen habit. Keep phones out of the bedroom if sleep slips.';

  @override
  String get screenOneTwoHours => '1–2 h/day';

  @override
  String get screenOneTwoTip =>
      'Moderate use. Try a 30-minute evening cutoff to protect recovery.';

  @override
  String get screenConstant => 'Constant';

  @override
  String get screenConstantTip =>
      'High screen time crowds out movement and sleep. Set app limits and swap one scroll block for a walk.';

  @override
  String get screenDefaultTip =>
      'Review screen habits — small evening limits often help wellness scores.';

  @override
  String nutritionRecentMeals(int count) {
    return '$count recent meals';
  }

  @override
  String get nutritionWarning =>
      'Several recent meals need attention. Favor vegetables, protein, and fewer ultra-processed snacks; log the next meal for feedback.';

  @override
  String get nutritionGood =>
      'Recent meal quality looks strong. Keep the pattern — it supports glucose and weight in your Health Index.';

  @override
  String get nutritionInfo =>
      'Mixed meal quality lately. Aim for one upgrade per day (more fiber or protein, less sugary drinks).';

  @override
  String psychoLoad(int total, String label) {
    return 'Load $total · $label';
  }

  @override
  String get psychoLow => 'Low';

  @override
  String get psychoModerate => 'Moderate';

  @override
  String get psychoHigh => 'High';

  @override
  String get psychoLowMsg =>
      'Psychosomatic indicators are within a healthy range. Keep maintaining your wellness habits.';

  @override
  String get psychoModerateMsg =>
      'Moderate psychosomatic load. Pay attention to rest, relaxation routines, and healthy boundaries.';

  @override
  String get psychoHighMsg =>
      'Significant stress and psychosomatic tension. Consider speaking with a specialist and reducing your load.';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityLow => 'Low';

  @override
  String get profileUpdatedSuccess => 'Profile updated successfully!';

  @override
  String get termsOfService => 'Terms of Service & Disclaimer';

  @override
  String get howWeHandleData => 'How we handle your data';

  @override
  String get sameScoreHint => 'Same score as on Home';

  @override
  String get eveningNotificationTitle => 'Evening check-in';

  @override
  String get bpMsgLow =>
      'Blood pressure is below the usual adult range (hypotension). Stay hydrated and talk to a clinician if you feel dizzy or faint.';

  @override
  String get bpMsgOptimal =>
      'Blood pressure is optimal (<120/<80). Keep up the healthy lifestyle.';

  @override
  String get bpMsgNormal =>
      'Blood pressure is in the normal adult range (around 120/80). This is a healthy target for most adults — not hypertension.';

  @override
  String get bpMsgHighNormal =>
      'Blood pressure is a little high (not hypertension yet). Monitor regularly; cut salt, stay active, and watch trends.';

  @override
  String get bpMsgGrade1 =>
      'Blood pressure is high. Lifestyle changes come first — less salt, more walking. Recheck and talk to a doctor if it stays up.';

  @override
  String get bpMsgGrade2 =>
      'Blood pressure is clearly high. Please see a doctor soon.';

  @override
  String get bpMsgGrade3 =>
      'Blood pressure is very high. Seek medical care without delay.';

  @override
  String get bpMsgDiabetes =>
      'Blood pressure is very high. Seek medical care without delay.';

  @override
  String get uploadAnalysisTitle => 'Upload Analysis';

  @override
  String get uploadFileType => 'File Type';

  @override
  String get uploadPdf => 'PDF Document';

  @override
  String get uploadPhoto => 'Photo / Image';

  @override
  String get uploadSelectFile => 'Select File';

  @override
  String get uploadClickToSelect => 'Click to select a file';

  @override
  String uploadClickToChange(int size) {
    return '$size KB — click to change';
  }

  @override
  String get uploadLimitReached => 'Limit reached';

  @override
  String get uploadUpgradeMore => 'Upgrade to upload more';

  @override
  String get uploadFile => 'Upload File';

  @override
  String get uploadAnalyzing => 'Analyzing...';

  @override
  String get uploadAnalyzingAiDoc => 'Analyzing your file with Ai Doc…';

  @override
  String get uploadFailed => 'Upload failed. Please try again.';

  @override
  String get uploadCouldNotRead =>
      'Could not read the selected file. Please pick it again.';

  @override
  String get uploadLimitMessage =>
      'Upload limit reached. Upgrade to PHA Plus+ for unlimited uploads.';

  @override
  String uploadFreePlan(int count) {
    return 'Free plan: $count/2 uploads used. Max 2 pages per file.';
  }

  @override
  String get mealTakePhoto => 'Take or upload a photo of your meal';

  @override
  String get mealAfterAnalysis =>
      'After analysis, tap ✓ only if you ate this dish — it adds to today\'s calories.';

  @override
  String get mealCamera => 'Camera';

  @override
  String get mealGallery => 'Gallery';

  @override
  String get mealAnalyze => 'Analyze Meal';

  @override
  String get mealAnalyzing => 'Analyzing…';

  @override
  String get mealFailed => 'Analysis failed. Please try again.';

  @override
  String get mealFreeLimit =>
      'Free limit reached (2 meals per 24h). Upgrade to PHA Plus+ for unlimited meal checks.';

  @override
  String mealFreePlan(int count, int limit) {
    return 'Free plan: $count/$limit meals logged in the last 24 hours.';
  }

  @override
  String get mealLogged =>
      'Meal logged — counted in today\'s intake & Health Index.';

  @override
  String get mealTapConfirm =>
      'Tap ✓ to confirm you ate this — adds to today\'s intake.';

  @override
  String get mealDiscard => 'Discard';

  @override
  String get mealTotalIntake => 'Total Intake';

  @override
  String get mealCarb => 'Carb';

  @override
  String get mealProteins => 'Proteins';

  @override
  String get mealFat => 'Fat';

  @override
  String get mealNoMealsToday => 'No meals confirmed today yet.';

  @override
  String mealNoMealsLogged(int target) {
    return 'No meals logged · target ~$target kcal';
  }

  @override
  String get mealConfirmHint => 'Confirm meals after analysis to track intake.';

  @override
  String get aiDocTitle => 'Ai Doc Assistant';

  @override
  String get aiDocWelcome =>
      'Hello! I\'m your Ai Doc Assistant. Would you like us to use the data you provided during onboarding? After that, you can describe your problem in detail — or share a photo of a meal, lab result, or anything health-related.';

  @override
  String get aiDocOffline => 'Ai Doc is offline — API key not set.';

  @override
  String get aiDocFreeLimit => 'Free consultation limit reached.';

  @override
  String aiDocFreeRemaining(int remaining) {
    return '$remaining of 3 free consultations remaining.';
  }

  @override
  String get aiDocAnalyzingHealth => 'Analyzing your health data…';

  @override
  String get aiDocLooking => 'Looking at that…';

  @override
  String get aiDocAskPlaceholder => 'Ask about symptoms, or add a photo note';

  @override
  String get aiDocUpgradeChat => 'Upgrade to continue chatting…';

  @override
  String get aiDocNoProblem =>
      'No problem! Whenever you\'re ready, describe your symptoms or health concerns in detail — or share a photo.';

  @override
  String get aiDocPhoto => 'Photo';

  @override
  String get wellnessResults => 'Wellness Results';

  @override
  String wellnessQuestion(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String percentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String get questionUnavailable => 'Question unavailable';

  @override
  String get wellnessVeryPoor => 'Very poor';

  @override
  String get wellnessPoor => 'Poor';

  @override
  String get wellnessModerate => 'Moderate';

  @override
  String get wellnessGood => 'Good';

  @override
  String get wellnessExcellent => 'Excellent';

  @override
  String get badHabitsSummaryTitle => 'Bad Habits Summary';

  @override
  String get badHabitsSaved =>
      'Saved to your health history. Honest tracking is the first step toward change.';

  @override
  String get badHabitsSocialMediaLabel => 'Social media';

  @override
  String badHabitsStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get badHabitsDoYouSmoke => 'Do you smoke?';

  @override
  String get badHabitsHowMuchSmoke => 'How much do you smoke?';

  @override
  String get badHabitsDoYouDrink => 'Do you drink alcohol?';

  @override
  String get badHabitsHowMuchDrink => 'How often and how much do you drink?';

  @override
  String get badHabitsSocialMedia =>
      'How much time do you spend uselessly on social media?';

  @override
  String get treatmentYourSchedule => 'Your schedule';

  @override
  String get treatmentAddMedicine => 'Add medicine or supplement';

  @override
  String get treatmentNewEntry => 'New entry';

  @override
  String get treatmentMedicineName => 'Name of medicine or dietary supplement';

  @override
  String get treatmentMedicinePlaceholder => 'e.g. Vitamin D, Metformin';

  @override
  String get treatmentHowManyTimes => 'How many times a day';

  @override
  String treatmentDoseTime(int n) {
    return 'Dose $n time';
  }

  @override
  String get treatmentAddAnother => 'Add another';

  @override
  String get treatmentSaveSchedule => 'Save schedule';

  @override
  String get treatmentSaved =>
      'Treatment schedule saved — pill reminders are on';

  @override
  String get treatmentEnterName =>
      'Enter at least one medicine or supplement name.';

  @override
  String get treatmentSaveFailed => 'Could not save. Please try again.';

  @override
  String get treatmentNotifOff =>
      'Schedule saved, but notifications are off. Enable alerts in Settings to get pill reminders.';

  @override
  String get psychoTestSubtitle => 'Stress & Psychosomatic Self-Assessment';

  @override
  String get psychoTestIntro =>
      'This assessment contains 3 blocks with a total of 20 questions. Answer honestly — there are no right or wrong answers. Results are saved to your profile.';

  @override
  String get psychoBlock1Title => 'BLOCK 1';

  @override
  String get psychoBlock1Subtitle => 'Stress Awareness';

  @override
  String get psychoBlock2Title => 'BLOCK 2';

  @override
  String get psychoBlock2Subtitle => 'Physical Symptoms';

  @override
  String get psychoBlock3Title => 'BLOCK 3';

  @override
  String get psychoBlock3Subtitle => 'Behavioral Profile';

  @override
  String get psychoAnswerHint =>
      'Each question has 3 answer options: Never · Sometimes · Often';

  @override
  String get psychoStartAssessment => 'Start Assessment';

  @override
  String get psychoYourResult => 'YOUR RESULT';

  @override
  String get psychoRetake => 'Retake';

  @override
  String get psychoNever => 'Never';

  @override
  String get psychoSometimes => 'Sometimes';

  @override
  String get psychoOften => 'Often';

  @override
  String psychoQuestionsCount(int count) {
    return '$count questions';
  }

  @override
  String get onboardingBackToQuest2 => 'Back to Quest 3';

  @override
  String onboardingBpGlucose(int hp) {
    return 'BP / +$hp HP';
  }

  @override
  String onboardingGlucoseHp(int hp) {
    return 'Glucose / +$hp HP';
  }

  @override
  String get onboardingSys => 'Sys';

  @override
  String get onboardingDia => 'Dia';

  @override
  String onboardingReadyForPha(int percent) {
    return '$percent% — ready for PHA';
  }

  @override
  String onboardingRedeemHp(int hp, int percent) {
    return 'Redeem your $hp HP for $percent% off your first 6-month or annual PHA Plus+ subscription.';
  }

  @override
  String get activityCurrentPlanSubtitle =>
      'Your current physical activity plan';

  @override
  String get activityCustomPlanHint =>
      'Your plan is active. Complete your daily workout and answer the evening check-in.';

  @override
  String get activityRestNote => 'Rest no more than 2 minutes between sets.';

  @override
  String get dailyLabel => 'Daily';

  @override
  String get fileTypePdf => 'PDF up to 2 pages (free plan)';

  @override
  String get upgradeToPhaPlus => 'Upgrade to PHA Plus+';

  @override
  String get healthAnalysisSubtitleShort => 'Same score as Home Health Index';

  @override
  String get wellnessQ1 => 'How stressed do you feel right now?';

  @override
  String get wellnessQ2 => 'How well did you sleep last night?';

  @override
  String get wellnessQ3 => 'How is your energy level today?';

  @override
  String get wellnessQ4 => 'How would you rate your mood?';

  @override
  String get wellnessQ5 => 'How is your overall wellbeing?';

  @override
  String get badHabitsSmokeLessPack => 'Less than one pack a day';

  @override
  String get badHabitsSmokeOnePack => '1 pack a day';

  @override
  String get badHabitsSmokeMorePack => 'More than one pack a day';

  @override
  String get badHabitsAlcoholOccasionally =>
      'Occasionally — less than 100 g strong alcohol, 1–2 glasses of wine, or up to 2 cans of beer per week';

  @override
  String get badHabitsAlcoholRegularly =>
      'Regularly — 200–300 g strong alcohol, 1–2 bottles of wine, or more than 2 L beer per week';

  @override
  String get badHabitsAlcoholHeavy =>
      'I get drunk 1–2 times a week to the point of memory loss';

  @override
  String get badHabitsSocialRarely => 'Rarely or never';

  @override
  String get badHabitsSocialUnderHour => 'Less than 1 hour a day';

  @override
  String get badHabitsSocialOneTwoHours => 'About 1–2 hours a day';

  @override
  String get badHabitsSocialConstantly => 'I constantly surf in my free time';

  @override
  String get activitySwitchHint => 'Switch to this program:';

  @override
  String get activityStartHint =>
      'Start your daily physical activity with this program:';

  @override
  String get activityStarterEx1 => 'I will do 15 push-ups throughout the day';

  @override
  String get activityStarterEx2 => '20 squats per day';

  @override
  String get activityStarterEx3 => '20 sit-ups';

  @override
  String get activityStarterEx4 =>
      '15 push-ups from a couch or other object behind your back';

  @override
  String get activityAdvancedEx1 =>
      '45 push-ups throughout the day. Recommended: 20, 15, 10';

  @override
  String get activityAdvancedEx2 => '50 squats per day, 2 sets of 25';

  @override
  String get activityAdvancedEx3 =>
      '30 sit-ups, 20 front raises, and 10 leg raises with knees bent';

  @override
  String get activityAdvancedEx4 =>
      '25 push-ups from a couch or other object behind your back, 15, and 10';

  @override
  String get activityProEx1 => 'Over 100 push-ups per day';

  @override
  String get activityProEx2 => 'Over 100 squats throughout the day';

  @override
  String get activityProEx3 => 'Over 70 abdominal exercises per day';

  @override
  String get activityProEx4 =>
      'Over 60 push-ups behind the back throughout the day';

  @override
  String get activitySupermanEx1 =>
      'I work out in the gym 3 or more times a week for more than 60 minutes vigorously';

  @override
  String get treatmentSaving => 'Saving...';

  @override
  String treatmentEntryNumber(int n) {
    return 'Entry $n';
  }

  @override
  String get onboardingLevelShort => 'Lv';

  @override
  String onboardingDayStreak(int count) {
    return '$count-day streak';
  }

  @override
  String get onboardingHudHealthPower => 'Health Power';

  @override
  String get onboardingQuest1Complete => 'Quest 1 complete!';

  @override
  String get onboardingQuest2Complete => 'Quest 2 crushed!';

  @override
  String get onboardingBonusComplete => 'Bonus quest done!';

  @override
  String get featurePrivateSecure => 'Private & secure';

  @override
  String get loginHeroLine1 => 'Your health,';

  @override
  String get loginHeroLine2 => 'intelligently';

  @override
  String get loginHeroLine3 => 'tracked.';

  @override
  String get loginHeroBody =>
      'Monitor your metrics, get AI-powered insights, and take control of your wellness journey.';

  @override
  String get loginTrustedBy =>
      'Trusted by health-conscious individuals worldwide.';

  @override
  String get loginSignUpSubtitle =>
      'Start tracking your health today — free forever.';

  @override
  String get loginSignInSubtitle => 'Sign in to access your health dashboard.';

  @override
  String get loginFullName => 'Full name';

  @override
  String get loginNamePlaceholder => 'Jane Smith';

  @override
  String get loginEmailLabel => 'Email address';

  @override
  String get loginEmailPlaceholder => 'you@example.com';

  @override
  String get loginPasswordHintSignUp => 'At least 8 characters';

  @override
  String get loginPasswordHintSignIn => '••••••••';

  @override
  String get legalAgreePrefix => 'I have read and agree to the ';

  @override
  String get creatingAccount => 'Creating account…';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get loginLegalFooter =>
      'By continuing, you agree to our terms. This app provides wellness guidance, not medical diagnosis.';

  @override
  String get onboardingErrorAge =>
      'Enter your age to earn the Foundation badge.';

  @override
  String get onboardingErrorGender => 'Select your gender.';

  @override
  String get onboardingErrorHeightImperial => 'Enter height (ft 1–8, in 0–11).';

  @override
  String get onboardingErrorHeightMetric => 'Enter height between 50–250 cm.';

  @override
  String get onboardingErrorWeightImperial =>
      'Enter weight between 44–660 lbs.';

  @override
  String get onboardingErrorWeightMetric => 'Enter weight between 20–300 kg.';

  @override
  String get onboardingErrorQuest2First => 'Complete Quest 2 first.';

  @override
  String get onboardingTrailUnits => 'Units';

  @override
  String get onboardingTrailBasics => 'Basics';

  @override
  String get onboardingTrailBoost => 'Boost';

  @override
  String get onboardingAgeHint => 'e.g. 32';

  @override
  String get onboardingFtIn => 'ft & in';

  @override
  String get onboardingHeightHintMetric => 'e.g. 175';

  @override
  String get onboardingWeightHintImperial => 'e.g. 165';

  @override
  String get onboardingWeightHintMetric => 'e.g. 70';

  @override
  String get vitalsBpBothOrNone =>
      'Enter both blood pressure values, or leave both empty.';

  @override
  String get vitalsDailyPrompt =>
      'Log blood pressure and glucose once per day. You can skip and log later.';

  @override
  String get vitalsPromptTurnOff => 'Turn Off';

  @override
  String get vitalsPromptTurnOffHint => 'Skip daily BP/glucose prompts.';

  @override
  String get vitalsPromptEvery5Days => 'Ask once in 5 days';

  @override
  String get vitalsPromptEvery5DaysHint => 'Remind every 5 days, not daily.';

  @override
  String get vitalsBpLabel => 'Blood pressure (mmHg)';

  @override
  String vitalsGlucoseLabel(String unit) {
    return 'Blood glucose ($unit)';
  }

  @override
  String get vitalsGlucoseHintImperial => 'e.g. 95';

  @override
  String get vitalsGlucoseHintMetric => 'e.g. 5.3';

  @override
  String get notNow => 'Not now';

  @override
  String get enterValidPositiveNumber =>
      'Please enter a valid positive number.';

  @override
  String get logHealthMetric => 'Log Health Metric';

  @override
  String get metricSaved => 'Metric saved!';

  @override
  String get metricType => 'Metric Type';

  @override
  String metricValueLabel(String unit) {
    return 'Value ($unit)';
  }

  @override
  String get metricNotesOptional => 'Notes (optional)';

  @override
  String get metricNotesPlaceholder => 'Any additional notes...';

  @override
  String get saveMetric => 'Save Metric';

  @override
  String get logMetricHintSteps => 'e.g. 8000';

  @override
  String get logMetricHintCalories => 'e.g. 350';

  @override
  String get logMetricHintDistanceImperial => 'e.g. 3.2';

  @override
  String get logMetricHintDistanceMetric => 'e.g. 5.2';

  @override
  String get logMetricHintActiveTime => 'e.g. 45';

  @override
  String get logMetricHintWeightImperial => 'e.g. 165';

  @override
  String get logMetricHintWeightMetric => 'e.g. 72.5';

  @override
  String get logMetricHintWater => 'e.g. 2000';

  @override
  String get upgradeTrialTitle => 'Unlock All Features of PHA Plus+';

  @override
  String get upgradeTrialBody1 =>
      'Take full control of your health! Unlock all premium options in PHA Plus+ and gain the ability to monitor your health, physical activity, nutrition, and medical indicators in real time.';

  @override
  String get upgradeTrialBody2 =>
      'Stay informed about potential risks and easily adjust your lifestyle. Count calories without any limits, correlate them with your daily activity levels, and receive personalized recommendations based on your medical data.';

  @override
  String get upgradeTagline => 'Your health. Your control. Always.';

  @override
  String get upgradeTitle => 'Unlock All Features';

  @override
  String get upgradeSubtitle =>
      'Get the full power of your Personal Health Assistant';

  @override
  String upgradeHpBanner(int hp, int percent) {
    return 'You have $hp HP! Redeem for $percent% off 6-month or annual plans.';
  }

  @override
  String get upgradeTableFeature => 'FEATURE';

  @override
  String get upgradeTableFree => 'FREE';

  @override
  String get upgradeTablePlus => 'PLUS+';

  @override
  String get upgradeFeatAnalysisUploads => 'Analysis Uploads';

  @override
  String get upgradeFeatMealCalories => 'Meal Calorie Checks';

  @override
  String get upgradeFeatPagesPerFile => 'Pages per File';

  @override
  String get upgradeFeatPsychoTest => 'PsychoTest';

  @override
  String get upgradeFeatTreatment => 'Treatment Schedule';

  @override
  String get upgradeFeatBadHabits => 'Check Your Bad Habits';

  @override
  String get upgradeFeatActivity => 'Start physical activity';

  @override
  String get upgradeFeatAiConsult => 'AI Consultation';

  @override
  String get upgradeFeatWellness => 'Wellness Check';

  @override
  String get upgradeVal2Files => '2 files';

  @override
  String get upgradeVal2PerDay => '2 / 24h';

  @override
  String get upgradeVal2Pages => '2 pages';

  @override
  String get upgradeValUnlimited => 'Unlimited';

  @override
  String get upgradeValLocked => 'Locked';

  @override
  String get upgradeValFullAccess => 'Full access';

  @override
  String get upgradeValIncluded => 'Included';

  @override
  String get planMonthly => 'Monthly';

  @override
  String get planBilledMonthly => 'Billed monthly.';

  @override
  String get planSemiannual => '6 Months';

  @override
  String get planAnnual => 'Annual';

  @override
  String get planHpDiscountNote => '20% HP discount applied.';

  @override
  String get planSave17 => 'Save ~17%.';

  @override
  String get planSave42 => 'Save ~42%.';

  @override
  String get planPerMonth => '/mo';

  @override
  String get planPer6Mo => '/6mo';

  @override
  String get planPerYear => '/yr';

  @override
  String get planBestBadge => 'BEST';

  @override
  String get psychoTestPromoBody =>
      'In-depth self-assessment for stress levels, psychosomatic patterns, and mental wellness indicators.';

  @override
  String psychoQuestionOfBlock(int current, int total) {
    return 'Q$current of $total';
  }

  @override
  String psychoStressLevelTitle(String label) {
    return '$label Stress Level';
  }

  @override
  String get analysisNoData =>
      'No health data found. Please log some metrics first.';

  @override
  String get analysisAllSolid =>
      'All scored Health Index factors look solid. Keep logging vitals, meals, and activity so trends stay visible.';

  @override
  String get syncPlatformOnly =>
      'Device activity sync is only available on iOS and Android.';

  @override
  String get syncPermissionDenied => 'Activity permission not granted.';

  @override
  String get syncReadFailed =>
      'Could not read activity data. Enable Steps and Walking + Running Distance in Health settings.';

  @override
  String get aiDocNoOnboardingData =>
      'I could not find your onboarding health data yet. Please complete onboarding first.';

  @override
  String get activityYourProgramFallback => 'your program';

  @override
  String get trialSevenDayFree => '7-day free trial';

  @override
  String get uploadImageFormats => 'JPG, PNG, GIF';

  @override
  String mealSaveFailed(String error) {
    return 'Could not save meal: $error';
  }

  @override
  String mealCaloriesShort(int n) {
    return '$n cal';
  }

  @override
  String treatmentDosesDaily(int n, String times) {
    return '$n× daily · $times';
  }

  @override
  String get notifMorningFallback =>
      'Good morning! Log your vitals and check your Health Index today.';

  @override
  String get notifEveningFallback =>
      'Evening check-in: how did your health goals go today?';

  @override
  String get notifChannelName => 'Daily health tips';

  @override
  String get notifChannelDesc => 'Morning and evening wellness reminders';

  @override
  String notifMedicationTitle(String name) {
    return 'Medication: $name';
  }

  @override
  String notifMedicationBody(String name) {
    return 'Take $name';
  }

  @override
  String get notifActivityTitle => 'Physical activity check-in';

  @override
  String notifActivityBody(String label) {
    return 'Did you complete $label today?';
  }

  @override
  String get notifIncompleteAssessmentsTitle => 'Complete your health checks';

  @override
  String notifIncompleteAssessmentsBody(String items) {
    return 'Please complete: $items. This improves your Health Index assessment.';
  }

  @override
  String notifActivitySaved(String answer) {
    return 'Saved: $answer — Health Index updated';
  }

  @override
  String notifDoseLabel(int current, int total) {
    return 'Dose $current of $total — ';
  }

  @override
  String get validationBpCheck => 'Check blood pressure values.';

  @override
  String validationBpRange(int sysMin, int sysMax, int diaMin, int diaMax) {
    return 'Check blood pressure values ($sysMin–$sysMax / $diaMin–$diaMax mmHg).';
  }

  @override
  String get validationBpDiaLower => 'Diastolic should be lower than systolic.';

  @override
  String get validationGlucoseEnter => 'Enter a glucose value.';

  @override
  String validationGlucoseRangeMgdl(int min, int max) {
    return 'Glucose $min–$max mg/dL.';
  }

  @override
  String validationGlucoseRangeMmol(String min, String max) {
    return 'Glucose $min–$max mmol/L.';
  }

  @override
  String get validationWeightEnter => 'Enter a valid weight.';

  @override
  String validationWeightRange(int min, int max) {
    return 'Weight $min–$max kg.';
  }

  @override
  String get validationHeightEnter => 'Enter a valid height.';

  @override
  String validationHeightRange(int min, int max) {
    return 'Height $min–$max cm.';
  }

  @override
  String get validationAgeEnter => 'Enter a valid age.';

  @override
  String validationAgeRange(int min, int max) {
    return 'Age $min–$max.';
  }

  @override
  String get psychoQ1 =>
      'How often have you felt overwhelmed or unable to control important things in your life?';

  @override
  String get psychoQ2 =>
      'How often do you experience physical symptoms like headaches, muscle tension, or fatigue due to stress?';

  @override
  String get psychoQ3 => 'How often have you had trouble sleeping?';

  @override
  String get psychoQ4 => 'How often do you feel anxious, worried, or on edge?';

  @override
  String get psychoQ5 => 'How often do you find it hard to relax and unwind?';

  @override
  String get psychoQ6 => 'Do you often have:';

  @override
  String get psychoQ7 => 'Do your symptoms get worse after stress?';

  @override
  String get psychoQ8 => 'Do you have:';

  @override
  String get psychoQ9 => 'Do you have any gastrointestinal problems:';

  @override
  String get psychoQ10 => 'Do you feel short of breath?';

  @override
  String get psychoQ11 => 'Do you have chronic fatigue?';

  @override
  String get psychoQ12 => 'Do you have muscle tension?';

  @override
  String get psychoQ13 =>
      'Do your symptoms get worse during conflicts or anxiety?';

  @override
  String get psychoQ14 => 'Do you tend to:';

  @override
  String get psychoQ15 => 'Do you often:';

  @override
  String get psychoQ16 => 'Is it difficult for you to say \"no\"?';

  @override
  String get psychoQ17 => 'Do you have a fear of losing control?';

  @override
  String get psychoQ18 =>
      'Do you experience constant internal tension even in a calm environment?';

  @override
  String get psychoQ19 => 'Do you feel loneliness despite communication?';

  @override
  String get psychoQ20 => 'Do you often \"keep everything inside\"?';

  @override
  String get psychoSubHeadaches => 'Headaches';

  @override
  String get psychoSubMuscleSpasms => 'Muscle spasms';

  @override
  String get psychoSubNeckPain => 'Neck pain';

  @override
  String get psychoSubChestPressure => 'Chest pressure';

  @override
  String get psychoSubStomachHeaviness => 'Heaviness in the stomach';

  @override
  String get psychoSubTachycardia => 'Tachycardia';

  @override
  String get psychoSubBpSurges => 'Blood pressure surges';

  @override
  String get psychoSubSweating => 'Sweating';

  @override
  String get psychoSubTrembling => 'Trembling';

  @override
  String get psychoSubBloating => 'Bloating';

  @override
  String get psychoSubHeartburn => 'Heartburn';

  @override
  String get psychoSubSpasms => 'Spasms';

  @override
  String get psychoSubDiarrheaConstipation => 'Diarrhea / constipation';

  @override
  String get psychoSubKeepControl => 'Keep everything under control';

  @override
  String get psychoSubAvoidConflicts => 'Avoid conflicts';

  @override
  String get psychoSubAccumulateEmotions => 'Accumulate emotions';

  @override
  String get psychoSubTakeResponsibility => 'Take responsibility for everyone';

  @override
  String get psychoSubWorkOvertime => 'Work overtime';

  @override
  String get psychoSubDontRest => 'Don\'t rest';

  @override
  String get psychoSubFeelGuilty => 'Feel guilty';

  @override
  String get clinicalCategoryHealthyWeight => 'Healthy weight range';

  @override
  String get clinicalCategoryMetabolic => 'Metabolic health';

  @override
  String get clinicalCategoryCombinedRisk => 'Overall heart & sugar risk';

  @override
  String get clinicalCategoryWhatMeans => 'What this means';

  @override
  String get clinicalCategoryForAge => 'For your age';

  @override
  String get clinicalIdealWeightNote =>
      'This is only a rough healthy-weight estimate. Your best range depends on muscle, body shape, and how you feel — not one formula.';

  @override
  String clinicalAroundKg(int kg) {
    return 'Around $kg kg';
  }

  @override
  String get clinicalBpHighNormalMsg =>
      'Your reading looks a bit high-normal. Cut salt, stay active, and check BP again on another day.';

  @override
  String clinicalWarningSigns(int n) {
    return '$n warning signs';
  }

  @override
  String get clinicalLookingOkay => 'Looking okay';

  @override
  String get clinicalRiskVeryHigh => 'High — act now';

  @override
  String get clinicalRiskElevated => 'Elevated';

  @override
  String get clinicalRiskModerate => 'Moderate';

  @override
  String get clinicalRiskLow => 'Low';

  @override
  String get clinicalGlucoseTooLow => 'Too low';

  @override
  String get clinicalGlucoseNormal => 'Normal';

  @override
  String get clinicalGlucosePrediabetes => 'Prediabetes range';

  @override
  String get clinicalGlucoseDiabetes => 'Diabetes range';

  @override
  String get clinicalBpVeryHigh => 'Very high — seek care';

  @override
  String get clinicalBpHighGrade2 => 'High (grade 2)';

  @override
  String get clinicalBpHigh => 'High';

  @override
  String get clinicalBpALittleHigh => 'A little high';

  @override
  String get clinicalBpLow => 'Low';

  @override
  String get clinicalBmiActionOver =>
      ' Focus on smaller portions, more vegetables, and daily walks. A 5–7% weight loss already helps heart and blood sugar.';

  @override
  String get clinicalBmiActionNormal =>
      ' Small daily habits (steps + protein at meals) help keep weight from creeping up.';

  @override
  String get clinicalBmiActionUnder =>
      ' Eat protein-rich meals more often and check with a doctor if weight loss was not planned.';

  @override
  String get activityCheckinSavedHint =>
      'Your answer is saved to your health history.';

  @override
  String get notifMorningFallbackDetailed =>
      'Check PHA: yesterday\'s steps, meal calories, and a nutrition tip for today.';

  @override
  String get notifEveningOpenApp =>
      'Open PHA for your evening check-in — see how today compared to yesterday.';

  @override
  String notifEveningStepsToday(int today) {
    return 'Today you logged $today steps. Keep building the habit — open PHA for your full check-in.';
  }

  @override
  String notifEveningStepsUp(int today, int yesterday) {
    return 'Today you logged $today steps, up from yesterday\'s $yesterday. Nice progress — keep it going.';
  }

  @override
  String notifEveningStepsDown(int today, int yesterday) {
    return 'You slipped today with $today steps, down from yesterday\'s $yesterday. Let\'s get moving again tomorrow; even a short walk helps.';
  }

  @override
  String get notifActivityChannelDesc =>
      'Daily reminder to log whether you completed your workout';

  @override
  String get indexSummaryExcellent =>
      'Excellent — keep your healthy habits going.';

  @override
  String get indexSummaryGood => 'You\'re doing well.';

  @override
  String get indexSummaryFair =>
      'Some areas need attention — small daily changes help.';

  @override
  String get indexSummaryPoor =>
      'Your health index needs focus — review vitals and habits.';

  @override
  String get validationGlucoseOutOfRange => 'Glucose out of allowed range.';

  @override
  String get validationWeightOutOfRange => 'Weight out of allowed range.';

  @override
  String get validationStepsUnrealistic => 'Steps look unrealistic.';

  @override
  String get validationCaloriesUnrealistic => 'Calories look unrealistic.';

  @override
  String get validationWaterUnrealistic => 'Water intake looks unrealistic.';

  @override
  String get validationActiveTimeRange => 'Active time must be 0–1440 minutes.';

  @override
  String get validationDistanceUnrealistic => 'Distance looks unrealistic.';

  @override
  String get mealQualityNoMeals => 'No meals logged';

  @override
  String get mealQualityHeavyDay => 'Heavy day';

  @override
  String get mealQualityGoodChoices => 'Good choices';

  @override
  String get mealQualityOverTarget => 'Over target';

  @override
  String get mealQualityUnderTarget => 'Under target';

  @override
  String get mealQualityBalanced => 'Balanced';

  @override
  String mealQualityHeavyOverKcal(int over, int target) {
    return 'About $over kcal over your ~$target kcal target.';
  }

  @override
  String get mealQualityHeavyHighCal =>
      'Several high-calorie choices today — ease up next meals.';

  @override
  String mealQualityGoodUnderKcal(int under, int target) {
    return 'Solid day — ~$under kcal under your ~$target kcal target.';
  }

  @override
  String mealQualityGoodOnTrack(int target) {
    return 'On track with your ~$target kcal target.';
  }

  @override
  String mealQualityOverKcal(int over, int target) {
    return 'About $over kcal over ~$target kcal — prefer lighter options next.';
  }

  @override
  String mealQualityUnderKcal(int under) {
    return '~$under kcal under goal — make sure meals are logged if you ate more.';
  }

  @override
  String mealQualityBalancedHint(int total, int target) {
    return 'Intake ~$total kcal vs ~$target kcal target today.';
  }

  @override
  String mealQualityTargetLine(String label, int target) {
    return '$label · target ~$target kcal';
  }

  @override
  String get mealCategoryExcellent => 'Excellent';

  @override
  String get mealCategorySatisfactory => 'Satisfactory';

  @override
  String get mealCategoryAttention => 'Attention';

  @override
  String get mealFallbackName => 'Meal';

  @override
  String get mealOneServing => 'one serving';

  @override
  String get adviceProtectWhatWorks =>
      'Protect what works: keep today\'s activity and meal pattern, and re-check BP/glucose on a consistent schedule.';

  @override
  String get adviceBloodPressure1 =>
      'Blood pressure: measure at the same time of day, seated and rested. Cut packaged salt, and walk most days — lifestyle is first-line before medication decisions.';

  @override
  String get adviceBloodPressure2 =>
      'If readings stay ≥140/90 on repeat checks, book a clinician visit with your home log.';

  @override
  String get adviceSmoking =>
      'Smoking: pick a quit day this week, tell someone, and remove cigarettes from easy reach. Update Plus+ → Check Your Bad Habits after you cut down.';

  @override
  String get adviceGlucose1 =>
      'Glucose: swap sugary drinks for water, add fiber/protein to breakfast, and take a 10–15 minute walk after your largest meal.';

  @override
  String get adviceGlucose2 =>
      'If fasting glucose stays high, ask your clinician about labs (HbA1c) rather than relying on one reading.';

  @override
  String get adviceBmi1 =>
      'Weight: target a gentle weekly change, not a crash diet — prioritize protein, vegetables, and your step habit from Health Insights.';

  @override
  String get adviceBmi2 =>
      'Log meals with Calorie Check so nutrition advice matches what you actually eat.';

  @override
  String get adviceActivity =>
      'Activity: schedule two fixed walk slots (e.g. after lunch and evening). Answer the physical-activity check-in so adherence counts in your Index.';

  @override
  String get adviceAlcohol =>
      'Alcohol: plan alcohol-free days first, then shrink portion size on drinking days. This often improves sleep and next-day BP.';

  @override
  String get adviceNutrition =>
      'Nutrition: upgrade one meal today — more plants and protein, less ultra-processed snacks. Re-scan a meal for fresh feedback.';

  @override
  String get adviceWellness =>
      'Wellness: protect a consistent sleep window and do one short recovery block daily (breathing, stretch, or outdoor light). Retake the Wellness Check after a few days.';

  @override
  String get advicePsychotest =>
      'PsychoTest load: reduce stacked stressors where you can, and use brief body-calming routines. Retake PsychoTest when life is calmer to see the Index move.';

  @override
  String get adviceScreenTime =>
      'Screen time: set a hard evening cutoff and replace one scroll session with movement — it supports both activity and wellness scores.';

  @override
  String get adviceHeartRate1 =>
      'Heart rate: open Heart Rate & Rhythm after wearing your Apple Watch. Aim for calm evenings and consistent sleep — resting HR often improves with recovery.';

  @override
  String get adviceHeartRate2 =>
      'If resting heart rate stays high for several days or irregular rhythm alerts continue, discuss them with a clinician and keep logging how you feel.';

  @override
  String get adviceStress =>
      'Elevated pulse without much activity often points to stress or poor recovery — prioritize sleep, short walks, and retake the Wellness Check.';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get aiOfflineSleep1 =>
      'Getting adequate sleep is crucial for your health. Aim for 7-9 hours per night. Try maintaining a consistent sleep schedule and creating a relaxing bedtime routine.';

  @override
  String get aiOfflineSleep2 =>
      'Sleep affects your immune system, mood, and metabolism. If you\'re having trouble sleeping, consider limiting screen time before bed and avoiding caffeine late in the day.';

  @override
  String get aiOfflineExercise1 =>
      'Regular physical activity is key to good health. Aim for at least 150 minutes of moderate exercise per week. Find activities you enjoy!';

  @override
  String get aiOfflineExercise2 =>
      'Exercise improves cardiovascular health, mood, and energy levels. Start with activities you enjoy and gradually increase intensity.';

  @override
  String get aiOfflineStress1 =>
      'Managing stress is important for your well-being. Try meditation, deep breathing exercises, or activities you find relaxing.';

  @override
  String get aiOfflineStress2 =>
      'High stress can affect your physical and mental health. Consider talking to someone you trust or seeking professional support if needed.';

  @override
  String get aiOfflineNutrition1 =>
      'A balanced diet with plenty of fruits, vegetables, and whole grains supports your health. Stay hydrated and limit processed foods.';

  @override
  String get aiOfflineNutrition2 =>
      'Good nutrition provides energy and supports all body functions. Consider consulting a nutritionist for personalized advice.';

  @override
  String get aiOfflineWeight1 =>
      'Maintaining a healthy weight requires balanced diet and regular exercise. Small, sustainable changes are more effective than drastic ones.';

  @override
  String get aiOfflineWeight2 =>
      'Your weight is just one aspect of health. Focus on how you feel and building healthy habits rather than the number on the scale.';

  @override
  String get aiOfflineDefault1 =>
      'That\'s a great health question! Focus on balanced nutrition, regular exercise, adequate sleep, and stress management for overall wellness.';

  @override
  String get aiOfflineDefault2 =>
      'Taking care of your physical and mental health is important. Don\'t hesitate to consult with healthcare professionals for personalized advice.';

  @override
  String clinicalBmiValue(String bmi) {
    return 'BMI $bmi';
  }

  @override
  String get clinicalRecMetabolicCluster =>
      'Several warning signs are present together (weight, blood pressure, or blood sugar). Lose a little weight if you can, eat more plants and less salt, walk most days, and ask your doctor for cholesterol and sugar blood tests.';

  @override
  String get clinicalRecCombinedHigh =>
      'More than one risk is elevated. Book a checkup soon so your doctor can review blood pressure, blood sugar, and cholesterol with you.';

  @override
  String get clinicalRecWeightLoss5to7 =>
      'Aim for a gentle 5–7% weight loss over a few months — that alone often improves blood pressure and blood sugar.';

  @override
  String get clinicalRecPrediabetes =>
      'Your sugar is in the prediabetes range. Cut sugary drinks, walk after meals, and recheck fasting glucose or HbA1c with your doctor.';

  @override
  String get clinicalRecHighBp =>
      'Your blood pressure is high. Reduce salt, stay active, measure BP at home for a few days, and share the averages with your doctor.';

  @override
  String get clinicalMetabolicInsufficient =>
      'Not enough data yet. Log blood pressure, blood sugar, and weight (and waist if you can) so we can spot metabolic warning signs.';

  @override
  String get clinicalMetabolicPresent =>
      'Several risk factors are present together (weight, blood pressure, or blood sugar). This raises heart and diabetes risk — see a doctor for cholesterol and sugar tests, and improve diet and activity.';

  @override
  String get clinicalMetabolicPartial =>
      'A couple of warning signs are present. Improve diet, walk more, and watch weight — small changes help a lot.';

  @override
  String get clinicalMetabolicOk =>
      'From the data we have, metabolic warning signs look under control.';

  @override
  String get clinicalRiskMsgHigh =>
      'Several risks are elevated together. This is a strong signal to improve food and activity and see a doctor for a checkup.';

  @override
  String get clinicalRiskMsgModerate =>
      'Your overall heart and sugar risk is higher than ideal. Small daily changes — walks, less salt and sugar — make a real difference.';

  @override
  String get clinicalRiskMsgLow =>
      'Your overall heart and sugar risk looks relatively low based on weight, blood pressure, and blood sugar.';

  @override
  String get clinicalFlagExtraWeightTitle => 'Extra weight';

  @override
  String get clinicalFlagExtraWeightBody =>
      'Carrying extra weight raises the chance of high blood sugar and heart problems. Smaller portions, more vegetables, and daily walks help.';

  @override
  String get clinicalFlagTripleTitle => 'Weight + BP + sugar';

  @override
  String get clinicalFlagTripleBody =>
      'Extra weight, higher blood pressure, and higher blood sugar together greatly raise diabetes and heart risk. Focus on food, walks, and a doctor visit.';

  @override
  String get clinicalFlagLowWeightBpTitle => 'Low weight + low BP';

  @override
  String get clinicalFlagLowWeightBpBody =>
      'Low weight with low blood pressure in older age can mean frailty. Eat enough protein and ask a doctor before cutting calories.';

  @override
  String get clinicalFlagLeanDiabetesTitle => 'High sugar, not much weight';

  @override
  String get clinicalFlagLeanDiabetesBody =>
      'Blood sugar is high even without much extra weight. A doctor should check what type of diabetes this might be.';

  @override
  String get clinicalFlagYoungHtnTitle => 'High BP under 40';

  @override
  String get clinicalFlagYoungHtnBody =>
      'High blood pressure at a young age should be confirmed with repeat readings. Ask a doctor if another cause needs checking.';

  @override
  String get clinicalAgePediatric =>
      'Pediatric percentiles apply under 18 — adult BMI/BP/glucose cut-offs are not used here.';

  @override
  String get clinicalAge45WeightSugar =>
      'After 45, extra weight plus higher blood sugar raise diabetes risk. Ask your doctor about a sugar check every 1–3 years.';

  @override
  String get clinicalAge60Systolic =>
      'After 60, the top blood-pressure number often rises first. Track home averages and share them with your doctor.';

  @override
  String get clinicalAge65Target =>
      'Over 65, many people aim for blood pressure under 140/90 if they feel well. Your doctor may set a different target if you are frail.';

  @override
  String get clinicalAgeYoungDiabetesLean =>
      'Under 40 with high blood sugar but normal weight — see a doctor to find out what type of diabetes this might be.';

  @override
  String get clinicalBpOlderAdultSuffix =>
      'In older adults, the top number often rises first — focus on that trend and share home averages with your doctor.';

  @override
  String notifMorningShort(
    int steps,
    int goal,
    int kcal,
    int score,
    String status,
  ) {
    return 'Yesterday: $steps steps (goal $goal), meals $kcal kcal. Health Index $score/100 — $status.';
  }

  @override
  String notifEveningShort(int today, int yesterday, int score, String status) {
    return 'Today $today steps vs yesterday $yesterday. Health Index $score/100 — $status.';
  }

  @override
  String get notifOpenHealthInsights => 'Open Health Insights';

  @override
  String get mealIntakeChartTitle => 'Calories from meals';

  @override
  String mealZoneDeficit(int max) {
    return '≤$max kcal — deficit (weight loss)';
  }

  @override
  String mealZoneModerate(int min, int max) {
    return '$min–$max kcal — maintenance zone';
  }

  @override
  String mealZoneSurplus(int max) {
    return '>$max kcal — surplus (weight gain risk)';
  }

  @override
  String aiDocUploadedAnalysis(String fileName) {
    return 'I uploaded my analysis: $fileName';
  }

  @override
  String get uploadDicom => 'DICOM (medical imaging)';

  @override
  String get fileTypeDicom => 'DICOM (.dcm) — in-depth AI pathology review';

  @override
  String get uploadAnalyzingDicom =>
      'Analyzing DICOM with Ai Doc — thorough pathology review…';

  @override
  String get actionHeartRate => 'Heart Rate & Rhythm';

  @override
  String get actionHeartRateDesc => 'Heart check with Smart Watch';

  @override
  String get unitBpm => 'bpm';

  @override
  String get unitMs => 'ms';

  @override
  String get hrEvents => 'events';

  @override
  String get hrCurrent => 'Heart rate';

  @override
  String get hrResting => 'Resting';

  @override
  String get hrWalking => 'Walking';

  @override
  String get hrHrv => 'HRV';

  @override
  String get hrAvg => 'Avg heart rate';

  @override
  String get hrStatus => 'Status';

  @override
  String get hrStatusNormal => 'Normal';

  @override
  String get hrStatusAttention => 'Attention';

  @override
  String get hrStatusRisk => 'Risk';

  @override
  String get hrNormRange => 'Resting range';

  @override
  String hrNormRangeShort(int low, int high) {
    return '$low–$high bpm';
  }

  @override
  String get hrReading => 'Reading heart data…';

  @override
  String get hrReadingHint =>
      'Syncing heart rate and rhythm from your Apple Watch via Apple Health.';

  @override
  String get hrLive => 'Live';

  @override
  String get hrStale => 'Last reading';

  @override
  String get hrUpdatedJustNow => 'Sample just now';

  @override
  String hrUpdatedSecondsAgo(int seconds) {
    return 'Sample ${seconds}s ago';
  }

  @override
  String hrUpdatedMinutesAgo(int minutes) {
    return 'Sample ${minutes}m ago';
  }

  @override
  String get hrRefreshSame => 'No newer sample in Apple Health yet';

  @override
  String get hrRefreshOk => 'Loaded latest Apple Health sample';

  @override
  String get hrStaleHint =>
      'No heart rate from your device. Put on your Apple Watch or fitness band.';

  @override
  String get hrNoDeviceData =>
      'No heart rate from your device. Put on your Apple Watch or fitness band.';

  @override
  String get hrNeedPermission => 'Apple Health access needed';

  @override
  String get hrNeedPermissionBody =>
      'Allow PHA to read Heart Rate, Resting Heart Rate, HRV, and Irregular Rhythm from Apple Health.';

  @override
  String get hrGrantAccess => 'Grant access';

  @override
  String get hrNoData =>
      'No heart data yet. Wear your Apple Watch, then tap Refresh. Make sure Heart Rate is enabled in Apple Health.';

  @override
  String get hrRefresh => 'Refresh';

  @override
  String get hrExport => 'Export';

  @override
  String get hrExportTitle => 'PHA Heart Rate & Rhythm summary';

  @override
  String get hrExportCopied => 'Summary copied to clipboard';

  @override
  String get hrDisclaimer =>
      'This is not a medical device. Smart-watch data does not replace a doctor’s advice. Seek care if you feel unwell.';

  @override
  String get hrChartTitle => 'Heart rate trend';

  @override
  String get hrRange24h => '24h';

  @override
  String get hrRange7d => '7d';

  @override
  String get hrRange30d => '30d';

  @override
  String get hrNoChartData => 'No chart data for this period';

  @override
  String get hrWhatItMeans => 'What this means';

  @override
  String get hrWhatItMeansBody =>
      'Resting heart rate and HRV reflect stress, recovery, and fitness. Sudden jumps or several high days in a row deserve attention.';

  @override
  String get hrEcgTitle => 'Recent ECG (Apple Watch)';

  @override
  String get hrEcgSinusRhythm => 'Sinus rhythm';

  @override
  String get hrEcgAtrialFibrillation => 'Atrial fibrillation';

  @override
  String get hrEcgLowOrHighHr => 'Low or high heart rate';

  @override
  String get hrEcgInconclusive => 'Inconclusive';

  @override
  String get hrEcgNotSet => 'Not classified';

  @override
  String get hrIrregularRhythm => 'Irregular rhythm alerts';

  @override
  String get hrTrendImproving => 'Improving';

  @override
  String get hrTrendWorsening => 'Worsening';

  @override
  String get hrTrendStable => 'Stable';

  @override
  String get hrTrendUnknown => 'Trend';

  @override
  String get hrExplainNormal =>
      'Your resting heart rate looks within a healthy wellness range for you.';

  @override
  String hrExplainHighResting(int bpm, int max) {
    return 'Resting heart rate is $bpm bpm — above the usual $max bpm comfort range. Stress, illness, caffeine, or low recovery can raise it.';
  }

  @override
  String hrExplainLowResting(int bpm, int min) {
    return 'Resting heart rate is $bpm bpm — below the usual $min bpm range. Athletes often run lower; seek care if you feel dizzy or weak.';
  }

  @override
  String get hrExplainLowHrv =>
      'Heart-rate variability looks low. That can mean higher stress or incomplete recovery — prioritize sleep and rest.';

  @override
  String get hrExplainElevatedStreak =>
      'Resting heart rate has stayed in the 80–95 bpm range for several days. Watch for stress, overtraining, or early illness.';

  @override
  String get hrExplainSpike =>
      'Resting heart rate rose sharply day to day. Note how you feel and recheck tomorrow.';

  @override
  String get hrExplainIrregular =>
      'Apple Watch reported irregular rhythm notifications. This is not a diagnosis — discuss with a clinician if alerts continue or you feel unwell.';

  @override
  String get hrAlertRiskTitle => 'Heart rate alarm';

  @override
  String get hrAlertAttentionTitle => 'Elevated resting heart rate';

  @override
  String get hrAlertGenericBody =>
      'Your resting heart rate is stably high (80–95 bpm) or rising day to day. Open Heart Rate & Rhythm for details.';

  @override
  String get hrRestingChartTitle => 'Resting heart rate';

  @override
  String hrAvgResting(int bpm) {
    return 'Avg $bpm bpm';
  }

  @override
  String hrZoneNormal(int low, int high) {
    return 'Green — $low–$high bpm (normal)';
  }

  @override
  String get hrZoneAttention => 'Yellow — mild deviation';

  @override
  String get hrZoneRisk => 'Red — significant deviation / risk';
}
