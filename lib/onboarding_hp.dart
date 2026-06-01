/// Onboarding Health Points (HP) — earned during quests, redeemable once at checkout.
const maxOnboardingHp = 20;
const hpUnitsReward = 5;
const hpBasicReward = 5;
const hpBpReward = 5;
const hpGlucoseReward = 5;
const hpFirstPurchaseDiscountPercent = 20;

int computeOnboardingHp({
  required bool unitsDone,
  required bool basicDone,
  required bool hasBp,
  required bool hasGlucose,
}) {
  var total = 0;
  if (unitsDone) total += hpUnitsReward;
  if (basicDone) total += hpBasicReward;
  if (hasBp) total += hpBpReward;
  if (hasGlucose) total += hpGlucoseReward;
  return total.clamp(0, maxOnboardingHp);
}

String planListPrice(String plan) => switch (plan) {
      'monthly' => '\$14',
      'semiannual' => '\$75',
      'annual' => '\$125',
      _ => '',
    };

String planDiscountedPrice(String plan) => switch (plan) {
      'semiannual' => '\$59',
      'annual' => '\$99',
      _ => planListPrice(plan),
    };

bool planEligibleForHpDiscount(String plan) =>
    plan == 'semiannual' || plan == 'annual';
