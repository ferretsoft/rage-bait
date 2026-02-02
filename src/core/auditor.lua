-- src/core/auditor.lua
-- THE AUDITOR dialogue lines

local Auditor = {}

-- Error message shown during system freeze
Auditor.CRITICAL_ERROR = "CRITICAL_ERROR"

-- Life lost auditor screen message
Auditor.LIFE_LOST = "LIFE LOST"

-- Life lost auditor text (shown in text trace and top banner)
Auditor.LIFE_LOST_TEXT = "LOW PERFORMANCE - INITIALIZE REASSIGNMENT"

-- Game over text (shown in text trace and top banner)
Auditor.GAME_OVER_TEXT = "YIELD INSUFFICIENT - LIQUIDATING ASSET"

-- Final game over verdict messages
Auditor.VERDICT = {
    "YIELD INSUFFICIENT.",
    "LIQUIDATING ASSET."
}

return Auditor















