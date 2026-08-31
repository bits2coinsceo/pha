// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'PHA — 个人健康助手';

  @override
  String get appNameShort => 'PHA';

  @override
  String get personalHealthAssistant => '个人健康助手';

  @override
  String get tagline => '您的健康，我们的优先事项';

  @override
  String get taglineBody => '用 PHA 追踪、分析并改善健康。您的数据保持私密与安全。';

  @override
  String get startingPha => '正在启动 PHA…';

  @override
  String get loading => '加载中…';

  @override
  String get startupFailed => '启动失败';

  @override
  String get noContent => '暂无内容';

  @override
  String get retry => '重试';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get done => '完成';

  @override
  String get save => '保存';

  @override
  String get continueAction => '继续';

  @override
  String get back => '返回';

  @override
  String get next => '下一步';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get ok => '确定';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get add => '添加';

  @override
  String get noDataYet => '暂无数据';

  @override
  String get noData => '无数据';

  @override
  String get comingSoon => '即将推出';

  @override
  String get navHome => '首页';

  @override
  String get navHistory => '历史';

  @override
  String get navInsights => '洞察';

  @override
  String get navProfile => '我的';

  @override
  String get quickActions => '快捷操作';

  @override
  String get healthIndex => '健康指数';

  @override
  String get healthMetrics => '健康指标';

  @override
  String get steps => '步数';

  @override
  String get calories => '卡路里';

  @override
  String get distance => '距离';

  @override
  String get activeTime => '活动时长';

  @override
  String get weight => '体重';

  @override
  String get height => '身高';

  @override
  String get water => '饮水';

  @override
  String get bloodGlucose => '血糖';

  @override
  String get bloodPressure => '血压';

  @override
  String get bpSystolic => '收缩压';

  @override
  String get bpDiastolic => '舒张压';

  @override
  String get language => '语言';

  @override
  String get chooseLanguage => '选择语言';

  @override
  String get chooseLanguageSubtitle => '之后可在个人资料中更改。';

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
  String get theme => '主题';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get appearance => '外观';

  @override
  String get goodMorning => '早上好';

  @override
  String get goodAfternoon => '下午好';

  @override
  String get goodEvening => '晚上好';

  @override
  String get welcomeBack => '欢迎回来';

  @override
  String get createYourAccount => '创建账户';

  @override
  String get signIn => '登录';

  @override
  String get signUp => '注册';

  @override
  String get createAccount => '创建账户';

  @override
  String get signUpForFree => '免费注册';

  @override
  String get alreadyHaveAccount => '已有账户？登录';

  @override
  String get dontHaveAccount => '没有账户？注册';

  @override
  String get email => '邮箱';

  @override
  String get password => '密码';

  @override
  String get displayName => '显示名称';

  @override
  String get yourName => '您的姓名';

  @override
  String get signOut => '退出登录';

  @override
  String get account => '账户';

  @override
  String get agreement => '用户协议';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get acceptAgreement => '我接受用户协议';

  @override
  String get acceptPrivacy => '我接受隐私政策';

  @override
  String get pleaseAcceptLegal => '请阅读并接受用户协议和隐私政策以继续。';

  @override
  String get passwordTooShort => '密码至少需要 8 个字符。';

  @override
  String get featureTrackVitals => '追踪生命体征与血糖';

  @override
  String get featureAiInsights => 'AI 健康洞察';

  @override
  String get featureSmartAnalysis => '智能分析';

  @override
  String get profileTitle => '个人资料';

  @override
  String get profileSubtitle => '管理您的账户设置';

  @override
  String get age => '年龄';

  @override
  String get heightCm => '身高（厘米）';

  @override
  String get weightKg => '体重（公斤）';

  @override
  String get saveChanges => '保存更改';

  @override
  String get profileSaved => '资料已保存';

  @override
  String get historyTitle => '健康历史';

  @override
  String get historySubtitle => '您随时间记录的健康指标';

  @override
  String get stepsChartTitle => '步数';

  @override
  String stepsAvgPerDay(String avg) {
    return '日均 $avg';
  }

  @override
  String get days7 => '7 天';

  @override
  String get days30 => '30 天';

  @override
  String get days90 => '90 天';

  @override
  String get allFilter => '全部';

  @override
  String recordsCount(int count) {
    return '$count 条记录';
  }

  @override
  String get recordCountOne => '1 条记录';

  @override
  String get noMetricsYet => '尚未记录任何指标';

  @override
  String get noMetricsHint => '使用主页上的记录按钮开始追踪健康。';

  @override
  String get insightsTitle => '健康洞察';

  @override
  String get insightsSubtitle => '来自健康数据的趋势与模式';

  @override
  String get avgHealthIndex => '平均健康指数';

  @override
  String get avgWellnessScore => '平均身心评分';

  @override
  String get stepTrend => '步数趋势';

  @override
  String get healthIndexHistory => '健康指数历史';

  @override
  String get wellnessCheckHistory => '身心检查历史';

  @override
  String get stepActivity => '步数活动';

  @override
  String lastNDays(int count) {
    return '近 $count 天';
  }

  @override
  String minLabel(String value) {
    return '最低：$value';
  }

  @override
  String avgLabel(String value) {
    return '平均：$value';
  }

  @override
  String maxLabel(String value) {
    return '最高：$value';
  }

  @override
  String get noInsightsYet => '暂无洞察';

  @override
  String get noInsightsHint => '开始记录健康指标并完成身心检查后，这里会显示洞察。';

  @override
  String get noHealthIndexYet => '尚无健康指数数据';

  @override
  String get noWellnessYet => '尚无身心检查。请在主页尝试身心检查。';

  @override
  String get healthAnalysis => '健康分析';

  @override
  String get healthAnalysisSubtitle => '与健康指数相同评分，并含发现与建议';

  @override
  String get analyze => '分析';

  @override
  String get reAnalyze => '重新分析';

  @override
  String get analyzing => '分析中…';

  @override
  String get noAnalysisYet => '尚无分析。点击分析，根据已记录指标获得个性化健康结论。';

  @override
  String get metricFindings => '指标发现';

  @override
  String get recommendations => '建议';

  @override
  String lastAnalyzed(String when) {
    return '上次分析：$when';
  }

  @override
  String get statusExcellent => '优秀';

  @override
  String get statusGood => '良好';

  @override
  String get statusFair => '一般';

  @override
  String get statusNeedsAttention => '需要关注';

  @override
  String get actionUploadAnalysis => '上传化验单';

  @override
  String get actionUploadAnalysisDesc => '分析 PDF 或照片';

  @override
  String get actionAiConsultation => 'AI 咨询';

  @override
  String get actionAiConsultationDesc => '与 Ai Doc 聊天';

  @override
  String get actionWellnessCheck => '身心检查';

  @override
  String get actionWellnessCheckDesc => '评估您的身心状态';

  @override
  String get actionBadHabits => '检查不良习惯';

  @override
  String get actionBadHabitsDesc => '吸烟、饮酒与屏幕时间';

  @override
  String get actionPhysicalActivity => '开始身体活动';

  @override
  String get actionPhysicalActivityDesc => '选择每日锻炼计划';

  @override
  String get actionMealCalories => '餐食热量';

  @override
  String get actionMealCaloriesDesc => '拍照 → 热量与营养建议';

  @override
  String get actionPsychoTest => '心理测试';

  @override
  String get actionPsychoTestDesc => '压力与身心评估';

  @override
  String get actionTreatmentSchedule => '治疗日程';

  @override
  String get actionTreatmentScheduleDesc => '药物与补剂提醒';

  @override
  String get actionFamilyHealth => '家庭健康追踪';

  @override
  String get actionFamilyHealthDesc => '添加家人以追踪他们的健康';

  @override
  String get logMetric => '记录';

  @override
  String get todayVitals => '今日生命体征';

  @override
  String get onboardingQuest1TitleBefore => '任务 1：选择你的世界';

  @override
  String get onboardingQuest1TitleAfter => '选择计量单位';

  @override
  String get onboardingQuest1BodyBefore => '开始健康之旅——3 个快速任务，然后注册。';

  @override
  String get onboardingQuest1BodyAfter => '按地区定制图表与提示。';

  @override
  String get onboardingQuest1CardTitle => '任务 1 · 计量体系';

  @override
  String get onboardingQuest1CardSubtitle => '用你的语言解锁图表';

  @override
  String get imperial => '英制';

  @override
  String get imperialUnits => '英尺 · 磅 · mg/dL';

  @override
  String get metric => '公制';

  @override
  String get metricUnits => '厘米 · 公斤 · mmol/L';

  @override
  String get startQuest1 => '开始任务 1 →';

  @override
  String get onboardingQuest2Title => '任务 2：关于你';

  @override
  String get onboardingQuest3Title => '任务 3：你的体征';

  @override
  String get onboardingVictoryTitle => '准备就绪！';

  @override
  String get onboardingVictoryBody => '你的健康之旅现在开始。';

  @override
  String get activityYourPlan => '你的活动计划';

  @override
  String get activityCurrentPlan => '当前计划';

  @override
  String get activityWhatsIncluded => '包含内容';

  @override
  String get activityChangePlan => '更改计划';

  @override
  String get activityStartTitle => '开始身体活动';

  @override
  String get activityChangeTitle => '更改计划';

  @override
  String get activityChooseProgram => '选择计划，开始每日身体活动。';

  @override
  String get activityChangeHint => '选择新计划。晚间打卡将跟随新计划。';

  @override
  String get activityKeepCurrent => '保留当前计划';

  @override
  String get activityProgramStarted => '计划已开始';

  @override
  String get activityProgramSaved => '每日活动计划已保存。每晚我们会询问你是否完成。';

  @override
  String get activityStartThis => '开始此计划';

  @override
  String get activitySwitchToThis => '切换到此计划';

  @override
  String get activityChooseAnother => '选择其他';

  @override
  String get activityCurrentBadge => '当前';

  @override
  String get activityStarter => '入门';

  @override
  String get activityStarterSubtitle => '开始每日身体活动';

  @override
  String get activityAdvanced => '进阶';

  @override
  String get activityAdvancedSubtitle => '用结构化组数建立坚持';

  @override
  String get activityProfessional => '专业';

  @override
  String get activityProfessionalSubtitle => '高容量每日自重训练';

  @override
  String get activitySuperman => '超人';

  @override
  String get activitySupermanSubtitle => '健身房高强度训练';

  @override
  String get partially => '部分完成';

  @override
  String get notifications => '通知';

  @override
  String get phaPlus => 'PHA Plus+';

  @override
  String get upgrade => '升级';

  @override
  String get trialExpired => '试用已到期';

  @override
  String get unitSteps => '步';

  @override
  String get unitKcal => '千卡';

  @override
  String get unitMin => '分钟';

  @override
  String get unitMl => '毫升';

  @override
  String get unitMmhg => '毫米汞柱';

  @override
  String get healthOverviewToday => '这是您今天的健康概览。';

  @override
  String get unitYears => '岁';

  @override
  String get unitKg => '公斤';

  @override
  String get unitCm => '厘米';

  @override
  String get unitLbs => 'lbs';

  @override
  String get unitMmol => 'mmol/L';

  @override
  String get unitMgdl => 'mg/dL';

  @override
  String get unitKm => '公里';

  @override
  String get unitMiles => 'miles';

  @override
  String healthIndexAvgScore(int score) {
    return '平均 $score/100';
  }

  @override
  String get indexCardExcellent => '优秀 — 继续保持。';

  @override
  String get indexCardGood => '状态良好。';

  @override
  String get indexCardFair => '有些方面需要关注。';

  @override
  String get indexCardNeedsAttention => '需要关注 — 请审视您的习惯。';

  @override
  String get stepsMsgSedentary => '今日活动偏低。先从 15 分钟步行开始 — 长期心脏健康贵在坚持。';

  @override
  String stepsMsgBuilding(int goal) {
    return '您正在养成步行习惯。朝向 $goal+ 步，以获得更强代谢益处。';
  }

  @override
  String stepsMsgBaseline(int goal) {
    return '基础活动扎实。再多几次短走可进入许多指南认可的 $goal+ 范围。';
  }

  @override
  String stepsMsgStrong(int goal) {
    return '活动水平强 — 远超久坐。保持节奏；$goal 步是加分目标，不是必须。';
  }

  @override
  String stepsMsgGoal(int goal) {
    return '出色的活动水平 — 您达到了经典的 $goal 步日。';
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
  String get todaysNotifications => '今日通知';

  @override
  String get morningNotificationTitle => '早上好 — 您的健康回顾';

  @override
  String get noNotificationsToday => 'No notifications for today yet.';

  @override
  String get notificationsAppearHere =>
      'Notifications that already arrived today appear here.';

  @override
  String get phaPlusUnlockedTitle => '您已开通 PHA Plus+！';

  @override
  String get phaPlusUnlockedBody => '所有功能已解锁。享受无限上传、PsychoTest 和治疗日程。';

  @override
  String get onboardingQuest2BuildAvatar => 'Quest 2: Build your avatar';

  @override
  String onboardingQuest2FillFields(int hp) {
    return 'Fill all 3 fields — earn +$hp HP on complete.';
  }

  @override
  String get rewardedStats => 'Rewarded stats';

  @override
  String get yourGender => '您的性别';

  @override
  String get male => '男';

  @override
  String get female => '女';

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
  String get badgeHeartTrack => '心率追踪';

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
  String get categoryBloodPressure => '血压';

  @override
  String get categoryBloodGlucose => '血糖';

  @override
  String get categoryWeight => 'Weight';

  @override
  String get categoryWeightBmi => '体重 / BMI';

  @override
  String get categoryDailyActivity => '日常活动';

  @override
  String get categoryCalorieBurn => '卡路里消耗';

  @override
  String get categoryMentalWellness => '心理健康';

  @override
  String get categorySmoking => '吸烟';

  @override
  String get categoryAlcohol => '饮酒';

  @override
  String get categoryScreenTime => '屏幕时间';

  @override
  String get categoryNutrition => '营养';

  @override
  String get categoryPsychoTest => 'PsychoTest';

  @override
  String get categoryActivity => '活动';

  @override
  String get categoryHeartRate => '心率与心律';

  @override
  String get categoryAge => '年龄';

  @override
  String get categoryStress => '压力（心率偏高）';

  @override
  String get analysisSummaryExcellent => '您的健康指数非常出色。';

  @override
  String get analysisSummaryGood => '您的健康指数总体良好。';

  @override
  String get analysisSummaryFair => '您的健康指数一般 — 一些调整就能提升。';

  @override
  String get analysisSummaryNeedsAttention => '您的健康指数需要关注 — 请重点关注以下差距。';

  @override
  String get analysisSummaryDefault => '这是您的健康概览。';

  @override
  String analysisScoreMatches(int score) {
    return '得分 $score/100 与首页健康指数一致。';
  }

  @override
  String analysisStrengths(String names) {
    return '优势：$names。';
  }

  @override
  String analysisBiggestDrag(String names) {
    return '当前拉低指数的主要因素：$names。';
  }

  @override
  String get glucoseMsgHypoglycemia => '血糖偏低（低血糖）。请尽快摄入快速碳水化合物，并咨询医生。';

  @override
  String get glucoseMsgNormal => '空腹血糖在正常范围。代谢健康良好。';

  @override
  String get glucoseMsgPrediabetes =>
      '血糖处于糖尿病前期范围。少喝含糖饮料，每餐增加纤维，饭后步行 10–15 分钟。';

  @override
  String get glucoseMsgDiabetes => '血糖处于糖尿病范围。请咨询医疗专业人员。';

  @override
  String get bmiMsgWeightOnly => '已记录体重。请在个人资料中添加身高，以便计算健康指数中的 BMI。';

  @override
  String get bmiMsgUnderweight => '您的体重相对身高偏低。多吃富含蛋白质的食物；若非计划减重请咨询医生。';

  @override
  String get bmiMsgHealthy => '您的体重相对身高健康。做得好！';

  @override
  String get bmiMsgOverweight => '您的体重略高于健康范围。建议温和每周减重，保持蛋白质摄入和每日步数。';

  @override
  String get bmiMsgObeseI => '您的体重明显高于健康范围。这可能升高血压和血糖。改善饮食、多步行，并与医生制定计划会很有帮助。';

  @override
  String get bmiMsgObeseII => '您的体重远高于健康范围。请咨询医生制定安全计划，保护心脏和代谢。';

  @override
  String stepsLabel(String count) {
    return '$count steps';
  }

  @override
  String get calorieBurnGood => '卡路里消耗与步数一致。请搭配均衡餐食以支持恢复。';

  @override
  String calorieBurnInfo(int calories) {
    return '您通过活动消耗了 $calories 千卡。请用餐食记录使摄入与目标匹配。';
  }

  @override
  String get wellnessMsgExcellent => '身心健康得分优秀 — 压力低、心理韧性强。';

  @override
  String get wellnessMsgGood => '身心健康良好。睡眠或恢复方面的小改进可升到优秀。';

  @override
  String get wellnessMsgModerate => '身心健康中等。试试 5 分钟呼吸、户外散步或更早关灯。';

  @override
  String get wellnessMsgNeedsAttention => '身心得分提示压力偏高。保护睡眠、减少晚咖啡因，本周多社交连接。';

  @override
  String get wellnessMsgCritical => '压力负荷高。考虑重做 Wellness Check；若持续请咨询心理健康专业人士。';

  @override
  String get smokingGood => '未报告吸烟 — 对心肺健康是最强保护因素之一。';

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
  String get smokingWarning => '吸烟是健康指数的主要风险因素。设定戒烟日、去除诱因，并用 Plus+ → 坏习惯追踪进度。';

  @override
  String get alcoholNone => '无';

  @override
  String get alcoholGood => '未报告饮酒 — 有助于血压、睡眠和肝脏。';

  @override
  String get alcoholOccasional => '偶尔';

  @override
  String get alcoholOccasionalTip => '保持偶尔饮酒，一周多数日子不饮酒。';

  @override
  String get alcoholRegular => '经常';

  @override
  String get alcoholRegularTip => '减少饮酒天数；酒精会升高血压和热量。';

  @override
  String get alcoholHeavy => '大量';

  @override
  String get alcoholHeavyTip => '大量饮酒严重损害健康指数 — 请寻求支持安全减量。';

  @override
  String get alcoholDefault => '饮酒';

  @override
  String get alcoholDefaultTip => '本周记录频率，争取多个无酒日。';

  @override
  String get screenRarely => '很少';

  @override
  String get screenRarelyTip => '社交媒体负担低 — 有利于睡眠和专注。';

  @override
  String get screenUnderHour => '<1 小时/天';

  @override
  String get screenUnderHourTip => '习惯合理。若睡眠变差，睡前不要带手机进卧室。';

  @override
  String get screenOneTwoHours => '1–2 小时/天';

  @override
  String get screenOneTwoTip => '中等使用。尝试晚间 30 分钟截止以保护恢复。';

  @override
  String get screenConstant => '持续不断';

  @override
  String get screenConstantTip => '高屏幕时间挤占运动和睡眠。设置应用限制，用步行替换一次刷手机。';

  @override
  String get screenDefaultTip => '检查屏幕习惯 — 晚间小限制常能帮助身心得分。';

  @override
  String nutritionRecentMeals(int count) {
    return '$count recent meals';
  }

  @override
  String get nutritionWarning => '最近几餐需要关注。多吃蔬菜和蛋白质，少超加工零食；记录下一餐以获得反馈。';

  @override
  String get nutritionGood => '最近餐食质量良好。保持这个模式 — 有助于血糖和体重。';

  @override
  String get nutritionInfo => '最近餐食质量参差。每天改进一项（更多纤维或蛋白质，少含糖饮料）。';

  @override
  String psychoLoad(int total, String label) {
    return 'Load $total · $label';
  }

  @override
  String get psychoLow => '低';

  @override
  String get psychoModerate => '中等';

  @override
  String get psychoHigh => '高';

  @override
  String get psychoLowMsg => '心身指标在健康范围。请继续保持身心习惯。';

  @override
  String get psychoModerateMsg => '中等心身负荷。注意休息、放松和健康边界。';

  @override
  String get psychoHighMsg => '显著压力与心身紧张。考虑咨询专家并减轻负荷。';

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
  String get eveningNotificationTitle => '晚间检查';

  @override
  String get bpMsgLow => '血压低于通常成人范围（低血压）。保持水分，若头晕请咨询医生。';

  @override
  String get bpMsgOptimal => '血压理想（<120/<80）。请继续保持健康生活方式。';

  @override
  String get bpMsgNormal => '血压在正常成人范围（约 120/80）。对大多数成人是健康目标。';

  @override
  String get bpMsgHighNormal => '血压略高（尚未达到高血压）。请定期监测，少盐、保持活动并关注趋势。';

  @override
  String get bpMsgGrade1 => '血压偏高。首先调整生活方式：少盐、多步行。若持续偏高请复查并咨询医生。';

  @override
  String get bpMsgGrade2 => '血压明显偏高。请尽快就医。';

  @override
  String get bpMsgGrade3 => '血压非常高。请立即就医。';

  @override
  String get bpMsgDiabetes => '血压非常高。请立即就医。';

  @override
  String get uploadAnalysisTitle => '上传分析';

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
  String get mealTakePhoto => '拍摄或上传餐食照片';

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
  String get aiDocTitle => 'Ai Doc 助手';

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
  String get badHabitsDoYouSmoke => '您吸烟吗？';

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
  String get treatmentYourSchedule => '您的日程';

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
  String get treatmentSaveSchedule => '保存日程';

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
  String get psychoStartAssessment => '开始评估';

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
  String get activityCurrentPlanSubtitle => '您当前的身体活动计划';

  @override
  String get activityCustomPlanHint => '计划已启用。完成每日锻炼并回答晚间打卡。';

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
  String get wellnessQ1 => '您现在感到多大压力？';

  @override
  String get wellnessQ2 => '昨晚睡得怎么样？';

  @override
  String get wellnessQ3 => '今天的精力如何？';

  @override
  String get wellnessQ4 => '您如何评价今天的心情？';

  @override
  String get wellnessQ5 => '整体健康状况如何？';

  @override
  String get badHabitsSmokeLessPack => '每天少于一包';

  @override
  String get badHabitsSmokeOnePack => '每天一包';

  @override
  String get badHabitsSmokeMorePack => '每天超过一包';

  @override
  String get badHabitsAlcoholOccasionally => '偶尔——每周少于100克烈酒、1–2杯葡萄酒或最多2罐啤酒';

  @override
  String get badHabitsAlcoholRegularly => '经常——每周200–300克烈酒、1–2瓶葡萄酒或超过2升啤酒';

  @override
  String get badHabitsAlcoholHeavy => '每周醉酒1–2次至失忆';

  @override
  String get badHabitsSocialRarely => '很少或从不';

  @override
  String get badHabitsSocialUnderHour => '每天少于1小时';

  @override
  String get badHabitsSocialOneTwoHours => '每天约1–2小时';

  @override
  String get badHabitsSocialConstantly => '空闲时间 constantly 刷手机';

  @override
  String get activitySwitchHint => '切换到此计划：';

  @override
  String get activityStartHint => '用此计划开始每日运动：';

  @override
  String get activityStarterEx1 => '全天做15个俯卧撑';

  @override
  String get activityStarterEx2 => '每天20个深蹲';

  @override
  String get activityStarterEx3 => '20个仰卧起坐';

  @override
  String get activityStarterEx4 => '15个背手撑（沙发或其他物体）';

  @override
  String get activityAdvancedEx1 => '全天45个俯卧撑，建议：20、15、10';

  @override
  String get activityAdvancedEx2 => '每天50个深蹲，2组×25';

  @override
  String get activityAdvancedEx3 => '30个仰卧起坐、20个抬体、10个屈膝抬腿';

  @override
  String get activityAdvancedEx4 => '背手撑25个：15和10';

  @override
  String get activityProEx1 => '每天超过100个俯卧撑';

  @override
  String get activityProEx2 => '全天超过100个深蹲';

  @override
  String get activityProEx3 => '每天超过70个腹部练习';

  @override
  String get activityProEx4 => '全天超过60个背手撑';

  @override
  String get activitySupermanEx1 => '每周在健身房锻炼3次以上，每次超过60分钟';

  @override
  String get treatmentSaving => '保存中...';

  @override
  String treatmentEntryNumber(int n) {
    return '条目 $n';
  }

  @override
  String get onboardingLevelShort => '等级';

  @override
  String onboardingDayStreak(int count) {
    return '$count天连续';
  }

  @override
  String get onboardingHudHealthPower => '健康力';

  @override
  String get onboardingQuest1Complete => '任务1完成！';

  @override
  String get onboardingQuest2Complete => '任务2完成！';

  @override
  String get onboardingBonusComplete => '奖励任务完成！';

  @override
  String get featurePrivateSecure => '私密安全';

  @override
  String get loginHeroLine1 => '您的健康，';

  @override
  String get loginHeroLine2 => '智能';

  @override
  String get loginHeroLine3 => '追踪。';

  @override
  String get loginHeroBody => '监测指标，获取 AI 洞察，掌控健康之旅。';

  @override
  String get loginTrustedBy => '受到全球健康意识用户的信赖。';

  @override
  String get loginSignUpSubtitle => '今天开始追踪健康——永久免费。';

  @override
  String get loginSignInSubtitle => '登录以访问健康面板。';

  @override
  String get loginFullName => '全名';

  @override
  String get loginNamePlaceholder => '张三';

  @override
  String get loginEmailLabel => '电子邮箱';

  @override
  String get loginEmailPlaceholder => 'you@example.com';

  @override
  String get loginPasswordHintSignUp => '至少 8 个字符';

  @override
  String get loginPasswordHintSignIn => '••••••••';

  @override
  String get legalAgreePrefix => '我已阅读并同意';

  @override
  String get creatingAccount => '正在创建账户…';

  @override
  String get signingIn => '正在登录…';

  @override
  String get loginLegalFooter => '继续即表示您同意我们的条款。本应用提供健康指导，非医疗诊断。';

  @override
  String get onboardingErrorAge => '输入年龄以获得 Foundation 徽章。';

  @override
  String get onboardingErrorGender => '请选择性别。';

  @override
  String get onboardingErrorHeightImperial => '输入身高（英尺 1–8，英寸 0–11）。';

  @override
  String get onboardingErrorHeightMetric => '输入身高 50–250 厘米。';

  @override
  String get onboardingErrorWeightImperial => '输入体重 44–660 磅。';

  @override
  String get onboardingErrorWeightMetric => '输入体重 20–300 公斤。';

  @override
  String get onboardingErrorQuest2First => '请先完成任务 2。';

  @override
  String get onboardingTrailUnits => '单位';

  @override
  String get onboardingTrailBasics => '基础';

  @override
  String get onboardingTrailBoost => '加成';

  @override
  String get onboardingAgeHint => '例如 32';

  @override
  String get onboardingFtIn => '英尺和英寸';

  @override
  String get onboardingHeightHintMetric => '例如 175';

  @override
  String get onboardingWeightHintImperial => '例如 165';

  @override
  String get onboardingWeightHintMetric => '例如 70';

  @override
  String get vitalsBpBothOrNone => '输入两个血压值，或都留空。';

  @override
  String get vitalsDailyPrompt => '每天记录一次血压和血糖。可跳过稍后记录。';

  @override
  String get vitalsPromptTurnOff => '关闭';

  @override
  String get vitalsPromptTurnOffHint => '跳过每日血压/血糖提示。';

  @override
  String get vitalsPromptEvery5Days => '每 5 天询问一次';

  @override
  String get vitalsPromptEvery5DaysHint => '每 5 天提醒，非每天。';

  @override
  String get vitalsBpLabel => '血压 (mmHg)';

  @override
  String vitalsGlucoseLabel(String unit) {
    return '血糖 ($unit)';
  }

  @override
  String get vitalsGlucoseHintImperial => '例如 95';

  @override
  String get vitalsGlucoseHintMetric => '例如 5.3';

  @override
  String get notNow => '稍后';

  @override
  String get enterValidPositiveNumber => '请输入有效的正数。';

  @override
  String get logHealthMetric => '记录健康指标';

  @override
  String get metricSaved => '指标已保存！';

  @override
  String get metricType => '指标类型';

  @override
  String metricValueLabel(String unit) {
    return '数值 ($unit)';
  }

  @override
  String get metricNotesOptional => '备注（可选）';

  @override
  String get metricNotesPlaceholder => '其他备注...';

  @override
  String get saveMetric => '保存指标';

  @override
  String get logMetricHintSteps => '例如 8000';

  @override
  String get logMetricHintCalories => '例如 350';

  @override
  String get logMetricHintDistanceImperial => '例如 3.2';

  @override
  String get logMetricHintDistanceMetric => '例如 5.2';

  @override
  String get logMetricHintActiveTime => '例如 45';

  @override
  String get logMetricHintWeightImperial => '例如 165';

  @override
  String get logMetricHintWeightMetric => '例如 72.5';

  @override
  String get logMetricHintWater => '例如 2000';

  @override
  String get upgradeTrialTitle => '解锁 PHA Plus+ 全部功能';

  @override
  String get upgradeTrialBody1 => '全面掌控健康！解锁 PHA Plus+ 所有高级功能。';

  @override
  String get upgradeTrialBody2 => '了解潜在风险并调整生活方式。无限计算卡路里并获得个性化建议。';

  @override
  String get upgradeTagline => '您的健康。您的掌控。始终如此。';

  @override
  String get upgradeTitle => '解锁全部功能';

  @override
  String get upgradeSubtitle => '释放个人健康助手的全部能力';

  @override
  String upgradeHpBanner(int hp, int percent) {
    return '您有 $hp HP！可兑换 $percent% 折扣。';
  }

  @override
  String get upgradeTableFeature => '功能';

  @override
  String get upgradeTableFree => '免费';

  @override
  String get upgradeTablePlus => 'PLUS+';

  @override
  String get upgradeFeatAnalysisUploads => '上传分析';

  @override
  String get upgradeFeatMealCalories => '餐食卡路里检查';

  @override
  String get upgradeFeatPagesPerFile => '每文件页数';

  @override
  String get upgradeFeatPsychoTest => '心理测试';

  @override
  String get upgradeFeatTreatment => '治疗计划';

  @override
  String get upgradeFeatBadHabits => '检查坏习惯';

  @override
  String get upgradeFeatActivity => '开始运动';

  @override
  String get upgradeFeatAiConsult => 'AI 咨询';

  @override
  String get upgradeFeatWellness => '健康检查';

  @override
  String get upgradeVal2Files => '2 个文件';

  @override
  String get upgradeVal2PerDay => '2 / 24小时';

  @override
  String get upgradeVal2Pages => '2 页';

  @override
  String get upgradeValUnlimited => '无限制';

  @override
  String get upgradeValLocked => '锁定';

  @override
  String get upgradeValFullAccess => '完整访问';

  @override
  String get upgradeValIncluded => '已包含';

  @override
  String get planMonthly => '月付';

  @override
  String get planBilledMonthly => '按月计费。';

  @override
  String get planSemiannual => '6 个月';

  @override
  String get planAnnual => '年付';

  @override
  String get planHpDiscountNote => '已应用 20% HP 折扣。';

  @override
  String get planSave17 => '节省约 17%。';

  @override
  String get planSave42 => '节省约 42%。';

  @override
  String get planPerMonth => '/月';

  @override
  String get planPer6Mo => '/6月';

  @override
  String get planPerYear => '/年';

  @override
  String get planBestBadge => '最佳';

  @override
  String get psychoTestPromoBody => '深度自评压力水平、心身模式及心理健康指标。';

  @override
  String psychoQuestionOfBlock(int current, int total) {
    return '第 $current/$total 题';
  }

  @override
  String psychoStressLevelTitle(String label) {
    return '$label 压力水平';
  }

  @override
  String get analysisNoData => '未找到健康数据。请先记录指标。';

  @override
  String get analysisAllSolid => '所有健康指数因素良好。继续记录指标、饮食和活动。';

  @override
  String get syncPlatformOnly => '设备活动同步仅在 iOS 和 Android 上可用。';

  @override
  String get syncPermissionDenied => '未授予活动权限。';

  @override
  String get syncReadFailed => '无法读取活动数据。请在健康设置中启用步数和距离。';

  @override
  String get aiDocNoOnboardingData => '尚未找到您的 onboarding 数据。请先完成 onboarding。';

  @override
  String get activityYourProgramFallback => '您的计划';

  @override
  String get trialSevenDayFree => '7 天免费试用';

  @override
  String get uploadImageFormats => 'JPG、PNG、GIF';

  @override
  String mealSaveFailed(String error) {
    return '无法保存：$error';
  }

  @override
  String mealCaloriesShort(int n) {
    return '$n 卡';
  }

  @override
  String treatmentDosesDaily(int n, String times) {
    return '每天 $n 次 · $times';
  }

  @override
  String get notifMorningFallback => '早上好！今天记录指标并查看健康指数。';

  @override
  String get notifEveningFallback => '晚间检查：今天的健康目标如何？';

  @override
  String get notifChannelName => '每日健康提示';

  @override
  String get notifChannelDesc => '早晚健康提醒';

  @override
  String notifMedicationTitle(String name) {
    return '药物：$name';
  }

  @override
  String notifMedicationBody(String name) {
    return '服用 $name';
  }

  @override
  String get notifActivityTitle => '运动检查';

  @override
  String notifActivityBody(String label) {
    return '今天完成了 $label 吗？';
  }

  @override
  String get notifIncompleteAssessmentsTitle => '请完成健康检查';

  @override
  String notifIncompleteAssessmentsBody(String items) {
    return '请完成：$items。这有助于更准确地评估您的健康指数。';
  }

  @override
  String notifActivitySaved(String answer) {
    return '已保存：$answer — 健康指数已更新';
  }

  @override
  String notifDoseLabel(int current, int total) {
    return '第 $current/$total 剂 — ';
  }

  @override
  String get validationBpCheck => '请检查血压值。';

  @override
  String validationBpRange(int sysMin, int sysMax, int diaMin, int diaMax) {
    return '检查血压 ($sysMin–$sysMax / $diaMin–$diaMax mmHg)。';
  }

  @override
  String get validationBpDiaLower => '舒张压应低于收缩压。';

  @override
  String get validationGlucoseEnter => '请输入血糖值。';

  @override
  String validationGlucoseRangeMgdl(int min, int max) {
    return '血糖 $min–$max mg/dL。';
  }

  @override
  String validationGlucoseRangeMmol(String min, String max) {
    return '血糖 $min–$max mmol/L。';
  }

  @override
  String get validationWeightEnter => '请输入有效体重。';

  @override
  String validationWeightRange(int min, int max) {
    return '体重 $min–$max 公斤。';
  }

  @override
  String get validationHeightEnter => '请输入有效身高。';

  @override
  String validationHeightRange(int min, int max) {
    return '身高 $min–$max 厘米。';
  }

  @override
  String get validationAgeEnter => '请输入有效年龄。';

  @override
  String validationAgeRange(int min, int max) {
    return '年龄 $min–$max。';
  }

  @override
  String get psychoQ1 => '您多久感到不堪重负或无法控制生活中的重要事情？';

  @override
  String get psychoQ2 => '您多久因压力出现头痛、肌肉紧张或疲劳？';

  @override
  String get psychoQ3 => '您多久出现睡眠问题？';

  @override
  String get psychoQ4 => '您多久感到焦虑或担忧？';

  @override
  String get psychoQ5 => '您多久觉得难以放松？';

  @override
  String get psychoQ6 => '您是否经常有：';

  @override
  String get psychoQ7 => '压力后症状是否加重？';

  @override
  String get psychoQ8 => '您是否有：';

  @override
  String get psychoQ9 => '您是否有胃肠道问题：';

  @override
  String get psychoQ10 => '您是否感到气短？';

  @override
  String get psychoQ11 => '您是否有慢性疲劳？';

  @override
  String get psychoQ12 => '您是否有肌肉紧张？';

  @override
  String get psychoQ13 => '冲突或焦虑时症状是否加重？';

  @override
  String get psychoQ14 => '您是否倾向于：';

  @override
  String get psychoQ15 => '您是否经常：';

  @override
  String get psychoQ16 => '您是否难以说「不」？';

  @override
  String get psychoQ17 => '您是否害怕失去控制？';

  @override
  String get psychoQ18 => '即使在平静环境中是否也感到持续内心紧张？';

  @override
  String get psychoQ19 => '尽管有交流是否仍感到孤独？';

  @override
  String get psychoQ20 => '您是否经常「把一切都藏在心里」？';

  @override
  String get psychoSubHeadaches => '头痛';

  @override
  String get psychoSubMuscleSpasms => '肌肉痉挛';

  @override
  String get psychoSubNeckPain => '颈部疼痛';

  @override
  String get psychoSubChestPressure => '胸部压迫感';

  @override
  String get psychoSubStomachHeaviness => '胃部沉重感';

  @override
  String get psychoSubTachycardia => '心动过速';

  @override
  String get psychoSubBpSurges => '血压飙升';

  @override
  String get psychoSubSweating => '出汗';

  @override
  String get psychoSubTrembling => '颤抖';

  @override
  String get psychoSubBloating => '腹胀';

  @override
  String get psychoSubHeartburn => '胃灼热';

  @override
  String get psychoSubSpasms => '痉挛';

  @override
  String get psychoSubDiarrheaConstipation => '腹泻/便秘';

  @override
  String get psychoSubKeepControl => '控制一切';

  @override
  String get psychoSubAvoidConflicts => '避免冲突';

  @override
  String get psychoSubAccumulateEmotions => '积累情绪';

  @override
  String get psychoSubTakeResponsibility => '为所有人负责';

  @override
  String get psychoSubWorkOvertime => '加班';

  @override
  String get psychoSubDontRest => '不休息';

  @override
  String get psychoSubFeelGuilty => '感到内疚';

  @override
  String get clinicalCategoryHealthyWeight => '健康体重范围';

  @override
  String get clinicalCategoryMetabolic => '代谢健康';

  @override
  String get clinicalCategoryCombinedRisk => '整体心脏和血糖风险';

  @override
  String get clinicalCategoryWhatMeans => '这意味着什么';

  @override
  String get clinicalCategoryForAge => '针对您的年龄';

  @override
  String get clinicalIdealWeightNote =>
      '这只是健康体重的粗略估计。最佳范围取决于肌肉、体型和自我感受 — 不是单一公式。';

  @override
  String clinicalAroundKg(int kg) {
    return '约 $kg 公斤';
  }

  @override
  String get clinicalBpHighNormalMsg => '读数略偏高。减盐、保持活动并改日再测。';

  @override
  String clinicalWarningSigns(int n) {
    return '$n 个警告信号';
  }

  @override
  String get clinicalLookingOkay => '看起来正常';

  @override
  String get clinicalRiskVeryHigh => '高 — 立即行动';

  @override
  String get clinicalRiskElevated => '升高';

  @override
  String get clinicalRiskModerate => '中等';

  @override
  String get clinicalRiskLow => '低';

  @override
  String get clinicalGlucoseTooLow => '过低';

  @override
  String get clinicalGlucoseNormal => '正常';

  @override
  String get clinicalGlucosePrediabetes => '糖尿病前期';

  @override
  String get clinicalGlucoseDiabetes => '糖尿病范围';

  @override
  String get clinicalBpVeryHigh => '非常高 — 就医';

  @override
  String get clinicalBpHighGrade2 => '高（2级）';

  @override
  String get clinicalBpHigh => '高';

  @override
  String get clinicalBpALittleHigh => '略高';

  @override
  String get clinicalBpLow => '低';

  @override
  String get clinicalBmiActionOver => ' 关注更小份量、更多蔬菜和每日步行。减重 5–7% 已有助于心脏和血糖。';

  @override
  String get clinicalBmiActionNormal => ' 小习惯（步数 + 餐中蛋白质）有助于防止体重上升。';

  @override
  String get clinicalBmiActionUnder => ' 更常吃富含蛋白质的餐食；若非计划减重请咨询医生。';

  @override
  String get activityCheckinSavedHint => '您的回答已保存到健康记录。';

  @override
  String get notifMorningFallbackDetailed => '打开 PHA：查看昨日步数、餐食卡路里和今日营养建议。';

  @override
  String get notifEveningOpenApp => '打开 PHA 进行晚间打卡 — 对比今天与昨天。';

  @override
  String notifEveningStepsToday(int today) {
    return '今天您记录了 $today 步。继续养成习惯 — 打开 PHA 完成打卡。';
  }

  @override
  String notifEveningStepsUp(int today, int yesterday) {
    return '今天 $today 步，比昨天 ($yesterday) 更多。进展不错！';
  }

  @override
  String notifEveningStepsDown(int today, int yesterday) {
    return '今天 $today 步，比昨天 ($yesterday) 少。明天再动起来 — 短走也有帮助。';
  }

  @override
  String get notifActivityChannelDesc => '每日提醒记录是否完成锻炼';

  @override
  String get indexSummaryExcellent => '优秀 — 继续保持健康习惯。';

  @override
  String get indexSummaryGood => '您做得很好。';

  @override
  String get indexSummaryFair => '有些方面需要关注 — 每日小改变有帮助。';

  @override
  String get indexSummaryPoor => '健康指数需要关注 — 请检查指标和习惯。';

  @override
  String get validationGlucoseOutOfRange => '血糖超出允许范围。';

  @override
  String get validationWeightOutOfRange => '体重超出允许范围。';

  @override
  String get validationStepsUnrealistic => '步数看起来不真实。';

  @override
  String get validationCaloriesUnrealistic => '卡路里看起来不真实。';

  @override
  String get validationWaterUnrealistic => '饮水量看起来不真实。';

  @override
  String get validationActiveTimeRange => '活动时间必须为 0–1440 分钟。';

  @override
  String get validationDistanceUnrealistic => '距离看起来不真实。';

  @override
  String get mealQualityNoMeals => '未记录餐食';

  @override
  String get mealQualityHeavyDay => '高热量日';

  @override
  String get mealQualityGoodChoices => '选择良好';

  @override
  String get mealQualityOverTarget => '超过目标';

  @override
  String get mealQualityUnderTarget => '低于目标';

  @override
  String get mealQualityBalanced => '均衡';

  @override
  String mealQualityHeavyOverKcal(int over, int target) {
    return '约超出目标 $over 千卡（~$target 千卡）。';
  }

  @override
  String get mealQualityHeavyHighCal => '今天多项高热量选择 — 下一餐请清淡些。';

  @override
  String mealQualityGoodUnderKcal(int under, int target) {
    return '不错 — 约低于目标 $under 千卡（~$target 千卡）。';
  }

  @override
  String mealQualityGoodOnTrack(int target) {
    return '符合 ~$target 千卡目标。';
  }

  @override
  String mealQualityOverKcal(int over, int target) {
    return '约超出 ~$target 千卡 $over 千卡 — 请选择更轻食。';
  }

  @override
  String mealQualityUnderKcal(int under) {
    return '低于目标 ~$under 千卡 — 如已进食请确保记录。';
  }

  @override
  String mealQualityBalancedHint(int total, int target) {
    return '今日摄入 ~$total 千卡，目标 ~$target 千卡。';
  }

  @override
  String mealQualityTargetLine(String label, int target) {
    return '$label · 目标 ~$target 千卡';
  }

  @override
  String get mealCategoryExcellent => '优秀';

  @override
  String get mealCategorySatisfactory => '满意';

  @override
  String get mealCategoryAttention => '注意';

  @override
  String get mealFallbackName => '餐食';

  @override
  String get mealOneServing => '一份';

  @override
  String get adviceProtectWhatWorks => '保持有效做法：维持今日活动与饮食，定期检查血压/血糖。';

  @override
  String get adviceBloodPressure1 => '血压：同一时间、静坐休息后测量。少盐、多步行。';

  @override
  String get adviceBloodPressure2 => '若重复测量仍 ≥140/90，请带家庭记录就医。';

  @override
  String get adviceSmoking => '吸烟：本周定戒烟日，告知他人，移走香烟。减少后在 Plus+ 更新坏习惯。';

  @override
  String get adviceGlucose1 => '血糖：用水代替含糖饮料，早餐加纤维和蛋白质，主餐后步行 10–15 分钟。';

  @override
  String get adviceGlucose2 => '若空腹血糖持续偏高，请医生检查 HbA1c。';

  @override
  String get adviceBmi1 => '体重：温和每周变化，优先蛋白质、蔬菜和步数习惯。';

  @override
  String get adviceBmi2 => '用卡路里检查记录餐食，使建议与实际饮食一致。';

  @override
  String get adviceActivity => '活动：固定两次步行（午饭后和晚间），完成活动打卡。';

  @override
  String get adviceAlcohol => '酒精：先安排无酒日，再减少饮酒量 — 有助于睡眠和次日血压。';

  @override
  String get adviceNutrition => '营养：改善一餐 — 更多蔬果和蛋白质，少超加工零食。';

  @override
  String get adviceWellness => '健康：固定睡眠窗口和短恢复时段。几天后重做 Wellness Check。';

  @override
  String get advicePsychotest => '心理测试：减少压力源，使用简短放松练习。生活平静后重测。';

  @override
  String get adviceScreenTime => '屏幕时间：设定晚间截止，用运动替代刷手机。';

  @override
  String get adviceHeartRate1 =>
      '心率：佩戴 Apple Watch 后打开「心率与心律」。规律睡眠与放松的晚间有助于改善静息心率。';

  @override
  String get adviceHeartRate2 => '若静息心率连续多日偏高或不规则心律提醒持续出现，请咨询医生并记录身体感觉。';

  @override
  String get adviceStress => '活动不多却心率偏高，多半与压力或恢复不足有关——请优先睡眠、短途步行，并重新做一次身心状态检查。';

  @override
  String errorWithMessage(String message) {
    return '错误：$message';
  }

  @override
  String get aiOfflineSleep1 => '充足睡眠对健康至关重要。目标 7–9 小时，保持规律作息。';

  @override
  String get aiOfflineSleep2 => '睡眠影响免疫、情绪和代谢。睡前少看屏幕、少喝咖啡。';

  @override
  String get aiOfflineExercise1 => '规律活动是健康关键。每周至少 150 分钟中等强度运动。';

  @override
  String get aiOfflineExercise2 => '运动改善心血管、情绪和精力。从喜欢的活动开始。';

  @override
  String get aiOfflineStress1 => '管理压力很重要。尝试冥想、深呼吸或放松活动。';

  @override
  String get aiOfflineStress2 => '高压力影响身心。与信任的人交谈或寻求支持。';

  @override
  String get aiOfflineNutrition1 => '均衡饮食含蔬果和全谷物。多喝水，少加工食品。';

  @override
  String get aiOfflineNutrition2 => '良好营养提供能量。可咨询营养师。';

  @override
  String get aiOfflineWeight1 => '健康体重需平衡饮食与运动。小步可持续改变更有效。';

  @override
  String get aiOfflineWeight2 => '体重只是健康的一方面。关注感受和习惯。';

  @override
  String get aiOfflineDefault1 => '好问题！均衡营养、运动、睡眠和压力管理是健康基础。';

  @override
  String get aiOfflineDefault2 => '照顾身心健康。请咨询专业人士获取个性化建议。';

  @override
  String clinicalBmiValue(String bmi) {
    return 'BMI $bmi';
  }

  @override
  String get clinicalRecMetabolicCluster =>
      '多项警示同时出现（体重、血压或血糖）。尽量减一点体重，多吃蔬果少盐，几乎每天步行，并请医生检查胆固醇和血糖。';

  @override
  String get clinicalRecCombinedHigh => '多项风险升高。请尽快预约检查，让医生评估血压、血糖和胆固醇。';

  @override
  String get clinicalRecWeightLoss5to7 => '争取在几个月内温和减重 5–7% — 仅此往往就能改善血压和血糖。';

  @override
  String get clinicalRecPrediabetes =>
      '您的血糖处于糖尿病前期。少喝含糖饮料，饭后步行，并与医生复查空腹血糖或 HbA1c。';

  @override
  String get clinicalRecHighBp => '您的血压偏高。少盐、保持活动，在家测几天血压并把平均值告诉医生。';

  @override
  String get clinicalMetabolicInsufficient =>
      '数据还不够。请记录血压、血糖和体重（如能测腰围更好），以便发现代谢风险。';

  @override
  String get clinicalMetabolicPresent =>
      '多项风险因素同时存在（体重、血压或血糖）。这会升高心脏和糖尿病风险 — 请就医检查胆固醇和血糖，并改善饮食与活动。';

  @override
  String get clinicalMetabolicPartial => '出现若干警示信号。改善饮食、多步行并关注体重 — 小改变也很有帮助。';

  @override
  String get clinicalMetabolicOk => '根据现有数据，代谢警示看起来处于可控范围。';

  @override
  String get clinicalRiskMsgHigh => '多项风险同时升高。这是强烈信号：改善饮食与活动，并尽快就医检查。';

  @override
  String get clinicalRiskMsgModerate => '您的整体心脏与血糖风险高于理想水平。每日步行、少盐少糖会带来实质改善。';

  @override
  String get clinicalRiskMsgLow => '根据体重、血压和血糖，您的整体心脏与血糖风险相对较低。';

  @override
  String get clinicalFlagExtraWeightTitle => '体重超标';

  @override
  String get clinicalFlagExtraWeightBody =>
      '多余体重会升高高血糖和心脏问题的风险。减小份量、多吃蔬菜并每日步行有帮助。';

  @override
  String get clinicalFlagTripleTitle => '体重 + 血压 + 血糖';

  @override
  String get clinicalFlagTripleBody =>
      '多余体重、偏高血压与偏高血糖同时存在，会大幅升高糖尿病和心脏风险。关注饮食、步行并就医。';

  @override
  String get clinicalFlagLowWeightBpTitle => '低体重 + 低血压';

  @override
  String get clinicalFlagLowWeightBpBody =>
      '老年阶段低体重伴随低血压可能提示衰弱。保证足够蛋白质，减热量前先咨询医生。';

  @override
  String get clinicalFlagLeanDiabetesTitle => '血糖高但体重不高';

  @override
  String get clinicalFlagLeanDiabetesBody => '即使没有明显多余体重，血糖也偏高。医生应检查可能的糖尿病类型。';

  @override
  String get clinicalFlagYoungHtnTitle => '40 岁前高血压';

  @override
  String get clinicalFlagYoungHtnBody => '年轻时血压偏高应通过重复测量确认。询问医生是否需排查其他原因。';

  @override
  String get clinicalAgePediatric => '18 岁以下使用儿童百分位 — 此处不使用成人 BMI/血压/血糖切点。';

  @override
  String get clinicalAge45WeightSugar =>
      '45 岁后，多余体重加上偏高血糖会升高糖尿病风险。请咨询医生每 1–3 年检查血糖。';

  @override
  String get clinicalAge60Systolic => '60 岁后，收缩压往往先升高。记录家庭平均值并与医生分享。';

  @override
  String get clinicalAge65Target =>
      '65 岁后，许多人在感觉良好时以血压低于 140/90 为目标。若较虚弱，医生可能设定不同目标。';

  @override
  String get clinicalAgeYoungDiabetesLean => '40 岁前血糖偏高但体重正常 — 请就医了解可能的糖尿病类型。';

  @override
  String get clinicalBpOlderAdultSuffix =>
      '在老年人中，上压往往先升高 — 关注这一趋势，并把家庭平均值告诉医生。';

  @override
  String notifMorningShort(
    int steps,
    int goal,
    int kcal,
    int score,
    String status,
  ) {
    return '昨天：$steps 步（目标 $goal），餐食 $kcal 千卡。健康指数 $score/100 — $status。';
  }

  @override
  String notifEveningShort(int today, int yesterday, int score, String status) {
    return '今天 $today 步，昨天 $yesterday 步。健康指数 $score/100 — $status。';
  }

  @override
  String get notifOpenHealthInsights => '打开健康分析';

  @override
  String get mealIntakeChartTitle => '餐食摄入热量';

  @override
  String mealZoneDeficit(int max) {
    return '≤$max 千卡 — 赤字（减重）';
  }

  @override
  String mealZoneModerate(int min, int max) {
    return '$min–$max 千卡 — 中间区间';
  }

  @override
  String mealZoneSurplus(int max) {
    return '>$max 千卡 — 盈余（增重风险）';
  }

  @override
  String aiDocUploadedAnalysis(String fileName) {
    return '我上传了分析文件：$fileName';
  }

  @override
  String get uploadDicom => 'DICOM（医学影像）';

  @override
  String get fileTypeDicom => 'DICOM (.dcm) — 深度 AI 病理分析';

  @override
  String get uploadAnalyzingDicom => 'Ai Doc 正在分析 DICOM — 深度病理审查…';

  @override
  String get actionHeartRate => '心率与心律';

  @override
  String get actionHeartRateDesc => '智能手表心脏检查';

  @override
  String get unitBpm => '次/分';

  @override
  String get unitMs => '毫秒';

  @override
  String get hrEvents => '次事件';

  @override
  String get hrCurrent => '心率';

  @override
  String get hrResting => '静息';

  @override
  String get hrWalking => '步行';

  @override
  String get hrHrv => '心率变异性';

  @override
  String get hrAvg => '平均心率';

  @override
  String get hrStatus => '状态';

  @override
  String get hrStatusNormal => '正常';

  @override
  String get hrStatusAttention => '注意';

  @override
  String get hrStatusRisk => '风险';

  @override
  String get hrNormRange => '静息范围';

  @override
  String hrNormRangeShort(int low, int high) {
    return '$low–$high 次/分';
  }

  @override
  String get hrReading => '正在读取心脏数据…';

  @override
  String get hrReadingHint => '正在通过 Apple 健康同步 Apple Watch 的心率与心律。';

  @override
  String get hrLive => '实时';

  @override
  String get hrStale => '上次';

  @override
  String get hrUpdatedJustNow => '刚刚采集';

  @override
  String hrUpdatedSecondsAgo(int seconds) {
    return '$seconds 秒前的记录';
  }

  @override
  String hrUpdatedMinutesAgo(int minutes) {
    return '$minutes 分钟前的记录';
  }

  @override
  String get hrRefreshSame => 'Apple 健康中还没有更新的记录';

  @override
  String get hrRefreshOk => '已加载 Apple 健康最新记录';

  @override
  String get hrStaleHint => '设备暂无心率数据。请戴上 Apple Watch 或运动手环。';

  @override
  String get hrNoDeviceData => '设备暂无心率数据。请戴上 Apple Watch 或运动手环。';

  @override
  String get hrNeedPermission => '需要健康权限';

  @override
  String get hrNeedPermissionBody =>
      '请允许 PHA 读取 Apple 健康中的心率、静息心率、心率变异性和不规则节律。';

  @override
  String get hrGrantAccess => '授权访问';

  @override
  String get hrNoData => '暂无心脏数据。请佩戴 Apple Watch 后点击刷新，并在 Apple 健康中开启心率。';

  @override
  String get hrRefresh => '刷新';

  @override
  String get hrExport => '导出';

  @override
  String get hrExportTitle => 'PHA 心率与心律摘要';

  @override
  String get hrExportCopied => '摘要已复制到剪贴板';

  @override
  String get hrDisclaimer => '这不是医疗器械。智能手表数据不能替代医生建议。如感不适请就医。';

  @override
  String get hrChartTitle => '心率趋势';

  @override
  String get hrRange24h => '24小时';

  @override
  String get hrRange7d => '7天';

  @override
  String get hrRange30d => '30天';

  @override
  String get hrNoChartData => '该时段无图表数据';

  @override
  String get hrWhatItMeans => '这意味着什么';

  @override
  String get hrWhatItMeansBody => '静息心率与心率变异性反映压力、恢复和体能。突然升高或连续多日偏高需要关注。';

  @override
  String get hrEcgTitle => '近期心电图（Apple Watch）';

  @override
  String get hrEcgSinusRhythm => '窦性心律';

  @override
  String get hrEcgAtrialFibrillation => '心房颤动';

  @override
  String get hrEcgLowOrHighHr => '心率过低或过高';

  @override
  String get hrEcgInconclusive => '无法判定';

  @override
  String get hrEcgNotSet => '未分类';

  @override
  String get hrIrregularRhythm => '不规则心律提醒';

  @override
  String get hrTrendImproving => '改善';

  @override
  String get hrTrendWorsening => '变差';

  @override
  String get hrTrendStable => '稳定';

  @override
  String get hrTrendUnknown => '趋势';

  @override
  String get hrExplainNormal => '您的静息心率处于健康范围。';

  @override
  String hrExplainHighResting(int bpm, int max) {
    return '静息心率为 $bpm 次/分 — 高于通常上限 $max。压力、疾病、咖啡因或恢复不足可能升高。';
  }

  @override
  String hrExplainLowResting(int bpm, int min) {
    return '静息心率为 $bpm 次/分 — 低于通常下限 $min。运动员常较低；如头晕乏力请就医。';
  }

  @override
  String get hrExplainLowHrv => '心率变异性偏低，可能表示压力较大或恢复不足 — 请优先睡眠与休息。';

  @override
  String get hrExplainElevatedStreak => '静息心率连续多日处于 80–95 次/分。请留意压力、过度训练或早期疾病。';

  @override
  String get hrExplainSpike => '静息心率较前一日明显升高。请留意身体感觉并明日复查。';

  @override
  String get hrExplainIrregular =>
      'Apple Watch 报告了不规则心律。这不是诊断 — 若提醒持续或身体不适，请咨询医生。';

  @override
  String get hrAlertRiskTitle => '心率警报';

  @override
  String get hrAlertAttentionTitle => '静息心率偏高';

  @override
  String get hrAlertGenericBody => '静息心率稳定在 80–95 次/分，或逐日上升。请打开「心率与心律」查看详情。';

  @override
  String get hrRestingChartTitle => '静息心率';

  @override
  String hrAvgResting(int bpm) {
    return '平均 $bpm 次/分';
  }

  @override
  String hrZoneNormal(int low, int high) {
    return '绿色 — $low–$high 次/分（正常）';
  }

  @override
  String get hrZoneAttention => '黄色 — 轻度偏离';

  @override
  String get hrZoneRisk => '红色 — 显著偏离 / 风险';
}
