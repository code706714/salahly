/// What a consumer says is wrong, from the chips on the first request step.
/// Each trade has its own list (see the catalog); `other` ends every one.
enum RequestIssue {
  // Air conditioning.
  notCooling,
  leaking,
  noisy,
  needsCleaning,
  installation,

  // Plumbing.
  plumbingLeak,
  plumbingClog,
  plumbingMixer,
  plumbingHeater,
  plumbingLowPressure,

  // Electrical.
  electricalNoPower,
  electricalShort,
  electricalOutlet,
  electricalLighting,
  electricalPanel,

  // Washing machines.
  washerNotSpinning,
  washerNotDraining,
  washerLeaking,
  washerNoisy,
  washerNotStarting,

  // Refrigerators.
  fridgeNotCooling,
  fridgeIceBuildup,
  fridgeNoisy,
  fridgeLeaking,
  fridgeDoorSeal,

  other,
}
