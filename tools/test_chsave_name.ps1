# ------------------------------------------------------------------------
# test_chsave_name.ps1
#
# Logic-level regression test for the ChSave channel-name fix in
# core/settings.c : SETTINGS_SaveChannel().
#
# Replicates the exact name-handling decision block and exercises every
# call path that reaches it. Verifies that:
#   1. Editing a memory channel on the radio + ChSave  -> name PRESERVED
#   2. ChSave from a memory VFO into a different ch    -> name CLEARED
#   3. ChSave from a frequency VFO into a channel      -> name CLEARED
#   4. Scanner store into a channel (Mode 2)           -> name PRESERVED
#   5. Explicit Mode 3 save (channel copy / beam)      -> name = pVFO->Name
#   6. Mode 1 (single setting save)                    -> name untouched
# ------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

# --- constants mirroring core/misc.h ---
$MR_CHANNEL_FIRST    = 0
$MR_CHANNEL_LAST     = 199
$FREQ_CHANNEL_FIRST  = 200

function IS-MR([int]$ch) { return ($ch -le $MR_CHANNEL_LAST) }

# --- simulated EEPROM name store (channel -> name) ---
$script:eepromName = @{}

function Save-ChannelName([int]$channel, [string]$name) {
    $script:eepromName[$channel] = $name
}

# --- replica of the new decision block in SETTINGS_SaveChannel ---
# returns the name action taken: 'WRITE(<name>)', 'CLEAR', 'KEEP'
function Save-Channel([int]$Channel, [int]$VFO, [string]$pVfoName,
                      [int]$Mode, [int]$screenChannel, [int]$mrChannel) {
    if (-not (IS-MR $Channel)) { return 'NONE(freq-channel)' }

    if ($Mode -ge 3) {
        Save-ChannelName $Channel $pVfoName
        return "WRITE($pVfoName)"
    }
    elseif ($Mode -eq 2) {
        # exact discriminator from core/settings.c
        $isReSave = (IS-MR $screenChannel) -and ($screenChannel -eq $Channel)
        if (-not $isReSave) {
            Save-ChannelName $Channel ''
            return 'CLEAR'
        }
        return 'KEEP'
    }
    return 'KEEP'   # Mode 1 never touches the name
}

$failures = 0
function Check([string]$desc, [string]$got, [string]$want) {
    if ($got -eq $want) {
        Write-Host ("  PASS  {0,-58} -> {1}" -f $desc, $got)
    } else {
        Write-Host ("  FAIL  {0,-58} -> got '{1}', want '{2}'" -f $desc, $got, $want)
        $script:failures++
    }
}

Write-Host "`n=== ChSave name-handling regression test ===`n"

# Pre-existing name on channel 5
$script:eepromName[5] = 'REPEATER'

# (1) VFO on MR ch5, edit settings, ChSave back to ch5 (Mode 2).
#     Menu accept set CHANNEL_SAVE/MrChannel to 5, ScreenChannel still 5.
$script:eepromName[5] = 'REPEATER'
Check '1: on-radio edit of MR ch5, ChSave->5 (Mode 2)' `
    (Save-Channel 5 0 'REPEATER' 2 -screenChannel 5 -mrChannel 5) 'KEEP'
Check '1b: ch5 name preserved in EEPROM' $script:eepromName[5] 'REPEATER'

# (2) VFO on MR ch5, ChSave into ch20 (Mode 2). Menu accept rewrites
#     MrChannel to 20, ScreenChannel stays 5 -> not a re-save of 20.
$script:eepromName[20] = 'OLDNAME'
Check '2: MR ch5 VFO, ChSave->20 (Mode 2)' `
    (Save-Channel 20 0 'REPEATER' 2 -screenChannel 5 -mrChannel 20) 'CLEAR'
Check '2b: ch20 name cleared' $script:eepromName[20] ''

# (3) Frequency VFO (screen = FREQ_CHANNEL_FIRST + band), ChSave->20 (Mode 2)
$script:eepromName[20] = 'OLDNAME'
Check '3: freq VFO, ChSave->20 (Mode 2)' `
    (Save-Channel 20 0 '' 2 -screenChannel ($FREQ_CHANNEL_FIRST + 2) -mrChannel 20) 'CLEAR'
Check '3b: ch20 name cleared' $script:eepromName[20] ''

# (4) Scanner store: scanner wrote ScreenChannel/MrChannel = target, Mode 2
$script:eepromName[7] = 'STALE'
Check '4: scanner store -> ch7 (Mode 2)' `
    (Save-Channel 7 0 '' 2 -screenChannel 7 -mrChannel 7) 'KEEP'

# (5) Explicit Mode 3 (channel copy / beam copy) writes the VFO name
Check '5: Mode 3 channel copy' `
    (Save-Channel 30 0 'COPIED' 3 -screenChannel 200 -mrChannel 5) 'WRITE(COPIED)'
Check '5b: ch30 name written' $script:eepromName[30] 'COPIED'

# (6) Mode 1 (single setting save) must never touch the name
$script:eepromName[5] = 'REPEATER'
Check '6: Mode 1 setting save on MR ch5' `
    (Save-Channel 5 0 'REPEATER' 1 -screenChannel 5 -mrChannel 5) 'KEEP'
Check '6b: ch5 name untouched' $script:eepromName[5] 'REPEATER'

# (7) Save against a FREQ channel destination (Channel is a VFO) - no name op
Check '7: Mode 2 to a freq/VFO channel' `
    (Save-Channel ($FREQ_CHANNEL_FIRST + 3) 0 '' 2 -screenChannel 5 -mrChannel 5) 'NONE(freq-channel)'

Write-Host ""
if ($failures -eq 0) {
    Write-Host 'ALL TESTS PASSED' -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failures TEST(S) FAILED" -ForegroundColor Red
    exit 1
}
