# Generate WAV files for all Auditor dialogue using Windows TTS (Hazel voice).
# Run from project root: powershell -ExecutionPolicy Bypass -File scripts\generate_auditor_voice.ps1

Add-Type -AssemblyName System.Speech

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$outDir = Join-Path $projectRoot "assets\voice"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

# Try to select Hazel (UK). Common names: "Microsoft Hazel Desktop", "Hazel"
$hazel = $synth.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Name -like "*Hazel*" } | Select-Object -First 1
if ($hazel) {
    $synth.SelectVoice($hazel.VoiceInfo.Name)
    Write-Host "Using voice: $($hazel.VoiceInfo.Name)"
} else {
    Write-Host "Hazel not found. Using default voice. Install a UK voice named 'Hazel' for best results."
}

# All Auditor dialogue + extra voice lines (Hazel TTS)
$lines = @{
    # Auditor (src/core/auditor.lua)
    "CRITICAL_ERROR"             = "Critical error."
    "LIFE_LOST"                  = "Life lost."
    "LIFE_LOST_TEXT"             = "Low performance. Initialize reassignment."
    "GAME_OVER_TEXT"             = "Yield insufficient. Liquidating asset."
    "VERDICT_1"                  = "Yield insufficient."
    "VERDICT_2"                  = "Liquidating asset."
    # Extra lines
    "DEFINE_YOURSELF"            = "Define yourself."
    "WELCOME_TO_RAGE_BAIT"       = "Welcome to Rage Bait."
    "GET_READY"                  = "Get ready."
    "PLEASE_INCREASE_ENGAGEMENT" = "Please increase engagement."
    "POWER_UP_ACQUIRED"          = "Power up acquired."
    "BONUS_MULTIPLIER"           = "Bonus multiplier."
    "HOSTILITY_SPIKE"            = "Hostility spike."
}

foreach ($key in $lines.Keys) {
    $text = $lines[$key]
    $safeKey = $key -replace "[^A-Za-z0-9_]", "_"
    $wavPath = Join-Path $outDir "$safeKey.wav"
    $synth.SetOutputToWaveFile($wavPath)
    $synth.Speak($text)
    $synth.SetOutputToNull()
    Write-Host "Generated: $safeKey.wav - `"$text`""
}

$synth.Dispose()
Write-Host "`nDone. Files saved to: $outDir"
