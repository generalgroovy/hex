class_name PlayerTuning
extends RefCounted


# All resource values use milli-units so future ancestry/champion modifiers can
# remain integer, bounded, and visible in content hashes.
const HEALTH_MAXIMUM: int = 100_000
const HEALTH_RECOVERY_PER_SECOND: int = 2_000
const HEALTH_RECOVERY_DELAY_MS: int = 5_500

const FLUX_MAXIMUM: int = 100_000
const FLUX_RECOVERY_PER_SECOND: int = 20_000
const FLUX_RECOVERY_DELAY_MS: int = 700

# Unused Flux and Stamina recover independently. Their existing spend delays
# remain separate; eligible quiet time ramps authored base rates, never Health.
const RESOURCE_RECOVERY_RAMP_MS: int = 3000
const RESOURCE_RECOVERY_MAXIMUM_RATIO: int = 3000
