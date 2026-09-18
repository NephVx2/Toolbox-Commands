#Requires -Version 5.1
<#
.SYNOPSIS
    Toolbox-SystemCommands_Win11 - Graphical launcher for common Windows system commands.

.DESCRIPTION
    Graphical interface (WinForms, dark theme) for launching the most common system
    maintenance commands (SFC, DISM, CHKDSK, network, Windows Update) in one click,
    each in its own console window (cmd.exe /k).

    The app self-elevates on startup (same admin rights needed for most of the
    commands below). Console windows launched afterward inherit this elevation
    level, so there is no per-button UAC re-prompt.

    A confirmation (Yes/No) is requested before launching commands flagged as
    sensitive (impact on system state, restart required, etc.).

    Every launch is logged to:
    Desktop\Maintenance_Reports\ToolboxCommands\History.log

    Collapsible categories (click the header), persistent favorites (star), HTML
    export of history available from the top bar.

.NOTES
    Author   : Nephren
    Version  : 2.5.4
    Usage    : Right-click > Run with PowerShell, or .\Toolbox-SystemCommands.ps1
               -SelfTest : runs the internal test suite (command catalog integrity,
               required functions, known regressions) without opening the GUI or
               requesting admin elevation.

    Suite convention: this script follows the same conventions as the rest of the
    maintenance suite (reports under Desktop\Maintenance_Reports\<Subfolder>,
    -SelfTest parameter). For Authenticode signing, run this script through
    Manage-ScriptSignatures.ps1 (CN=Nephren PowerShell Code Signing) like the
    other 13 scripts in the suite.

    v1.1.1: switched to a FlowLayoutPanel for the button list (instead of manual
    pixel positioning) to fix a display bug where only the first button appeared;
    the search bar was also moved into its own Dock=Top panel to keep it from
    being covered by the list (Dock=Fill).

    v1.1.2: Invoke-ConsoleCommand / Write-CommandLog / Update-Filter functions
    declared at global scope (WinForms event handlers could not see script-scoped
    functions); replaced wmic (removed since Windows 11 24H2) with
    Get-CimInstance; escaped unescaped pipes that were broken by cmd.exe.

    v1.2.0: added the -SelfTest parameter (20 assertions).

    v1.3.0: the log (History.log) now includes the machine name, user, and
    Windows version on every line (useful for centralizing logs from several
    machines). -SelfTest now at 23 assertions.

    v1.4.0: collapsible categories (click the category header); persistent
    favorites (star to the left of each command, saved to Favorites.txt,
    "Favorites only" filter); HTML export of history (button in the top bar).
    Renamed Update-Filter to Update-Visibility (now handles search + favorites +
    collapsed categories). -SelfTest now at 29 assertions.

    v1.4.1: replaced "DNS configured per interface" (Get-DnsClientServerAddress,
    which does not detect the transparent WFP interception used by the NextDNS
    Desktop app) with the official NextDNS test (curl.exe -L
    https://test.nextdns.io), which reflects the real DNS traffic behavior
    instead of the interface's declared configuration.

    v1.4.2: "DNS configured per interface" restored in addition to the NextDNS
    test (the two are complementary: the former stays useful for generic
    diagnostics on a machine without NextDNS or using another resolver).

    v1.4.3: fixed "Top RAM processes" - an unescaped $_ in the command string was
    interpolated by this script itself at catalog build time (instead of being
    passed through to the child command), breaking the resulting PowerShell
    syntax. Added a -SelfTest regression assertion that scans the catalog source
    code to detect any future unescaped dollar-underscore interpolation.
    -SelfTest now at 30 assertions.

    v1.4.4: fixed "Devices in error" - Get-PnpDevice -Status Error throws a
    blocking error (ObjectNotFound) when no device matches, instead of returning
    an empty result. Replaced with after-the-fact Where-Object filtering, with a
    clear message when no device is in error.

    v2.0.0: major architectural overhaul.
    - Command catalog extracted into Commands.psd1 (external data file, must stay
      next to the script). The Cmd field is now ALWAYS single-quoted, which
      structurally eliminates the entire class of interpolation bugs ($_, $err,
      etc.) hit in v1.4.3/v1.4.4: no more need for case-by-case escaping.
    - Loaded via Import-PowerShellDataFile, with error handling (clear message if
      the file is missing or invalid, instead of a crash).
    - JSON export of history ("Export JSON" button), in addition to the existing
      HTML export. Both now share a common Get-HistoryEntries function (log
      parsing).
    - -SelfTest now at 34 assertions (checks that Commands.psd1 is present and
      loads correctly, no double-quoted Cmd in the external catalog,
      Get-HistoryEntries/Export-HistoryJson functions defined).

    v2.1.0: fixed capture of $global:winInfo (Win32_OperatingSystem.Caption +
    registry DisplayVersion/UBR instead of ProductName - a known Microsoft bug
    that has never been fixed, this registry key stays frozen on "Windows 10
    [Edition]" even on an up-to-date Windows 11 install). Logs the launched
    process's PID (Start-Process -PassThru) to History.log and both exports
    (HTML/JSON); Get-HistoryEntries stays compatible with log lines written
    before this change (optional PID=... segment in the parsing regex). Ctrl+F
    shortcut to focus the search box directly. Right-click on a command ->
    "Copy command" (clipboard). New regression assertion detecting any double
    quote in a Cmd field's content, even when properly wrapped in single quotes
    (cf. "Real-time disk latency" bug of 08/01/2026, HRESULT 0x80041017: double
    quotes mishandled by cmd.exe once packaged into Invoke-ConsoleCommand's /k
    title ... &&). -SelfTest now at 36 assertions.

    v2.2.0: new optional help button ("?") on each command, powered by a new
    optional Help field in Commands.psd1. Reserved visually on ALL rows to keep
    consistent alignment, but active (cyan, clickable, opens a MessageBox with
    the explanation text) only if the command has this field; grayed out and
    disabled otherwise. Main button width reduced from 366 to 334px to make
    room. First command equipped: "Hardware virtualization state (Hypervisor /
    VBS)" (detailed explanation of Credential Guard / HVCI / System Guard / SMM
    Firmware Measurement). -SelfTest now at 37 assertions.

    v2.3.0: overhaul of the HTML export (Export-History). PC/User columns
    removed from the table (identical on nearly every row) and moved into the
    header. Redundant 'powershell -NoExit -Command' prefix removed from the
    Detail column; commands longer than 120 characters collapsed behind a
    <details>/<summary> ('View full command'). Visual grouping by day (date
    sub-header). Sensitive commands (Confirm=$true in Commands.psd1) highlighted
    in orange, via a new global $confirmLabels HashSet populated when the
    catalog loads - lets Export-History (a global function) know each command's
    Confirm flag without re-parsing Commands.psd1 or depending on
    $commandGroups (script scope, invisible from a global function). JavaScript
    search bar built into the exported report (filters rows live, no external
    dependency). -SelfTest now at 38 assertions.

    v2.4.0: support for a second, OPTIONAL catalog, Commands.Personnel.psd1, same
    folder and same format as Commands.psd1 - but not meant to be shared between
    machines (unlike the main catalog). If absent, no impact: the main catalog
    works fine on its own, with no error or warning. If present but invalid,
    non-blocking warning (the main catalog still loads normally). Lets you keep
    machine-specific commands (e.g. scheduled-task management deemed pointless
    after analysis) out of the portable catalog. -SelfTest now at 39 assertions
    (verifies that Commands.Personnel.psd1, whether absent or present-and-valid,
    never blocks loading).

    v2.4.1: added, in Commands.psd1 (category "System integrity"), the "Full
    Integrity Pack (CHKDSK+DISM+SFC)" - chains CHKDSK C: /scan, DISM CheckHealth,
    DISM ScanHealth, then SFC /scannow in a single command, in the recommended
    order (disk -> component store -> system files, SFC benefiting from a store
    already checked by DISM). Chained deliberately with '&' (unconditional
    execution) rather than '&&', so all 4 steps always run even if an earlier
    step detects an anomaly (CHKDSK /scan, for example, returns a non-zero exit
    code as soon as an irregularity is detected, even without fixing anything) -
    with '&&' the chain would have stopped dead at the first anomaly. Visual "===
    ... ===" markers via echo between each step to catch everything in the
    scrolling output of a single console window. New -SelfTest regression
    assertion verifying this pack stays chained with '&' and never contains
    '&&'. -SelfTest now at 40 assertions.

    v2.4.2: fixed a safety flaw in the "Full Integrity Pack" (v2.4.1) - the
    unconditional '&' chaining launched SFC /scannow even if DISM ScanHealth had
    just detected component store corruption. But ScanHealth is a DIAGNOSTIC, not
    a repair: SFC risked pulling its replacement files from a still-corrupted
    store, with no visible error. Replaced with an explicit guard via
    Repair-WindowsImage -Online -ScanHealth (DISM PowerShell module, already used
    elsewhere in the catalog) and its structured ImageHealthState property
    (Healthy/Repairable/NonRepairable) - reliable and independent of the system
    language, unlike parsing dism.exe's displayed text. SFC now only runs if the
    store is confirmed healthy; otherwise the pack stops before SFC with a
    message suggesting to run DISM RestoreHealth manually first. -SelfTest
    regression assertion updated accordingly (checks for the presence of the
    ImageHealthState guard, no longer just the '&' chaining). -SelfTest stays at
    40 assertions.

    v2.4.3: improved console readability of the "Full Integrity Pack" - each step
    (CHKDSK, DISM CheckHealth, DISM ScanHealth, SFC, or the stop message) is now
    preceded by 2 blank lines (two argument-less Write-Host calls, to avoid any
    `n escape sequence incompatible with the Cmd field's single-quotes-only rule)
    and a Cyan header, to instantly spot each block in the long CHKDSK/DISM/SFC
    output. Added a "=== CHKDSK C: /scan ===" header that was missing from step 1
    (the only step without a visual announcement until now). -SelfTest stays at
    40 assertions (no new assertion: purely cosmetic change, already covered by
    the existing assertion on the presence of the ImageHealthState guard).

    v2.4.4: fixed the -SelfTest assertion added in v2.4.2 (false [FAIL] even
    though the pack itself was correct). The regex tested for the presence of
    ''Healthy'' (double single-quotes) in $packIntegrite.Cmd, conflating two
    distinct levels of escaping: ''Healthy'' is the RAW text written in the
    Commands.psd1 file (doubling required by .psd1 syntax to represent a literal
    single quote), but Import-PowerShellDataFile automatically unwraps this
    doubling on read - the real value in memory in $packIntegrite.Cmd contains
    'Healthy' with a single quote on each side, never two. Regex fixed
    accordingly (eq\s+'Healthy' instead of eq\s+''Healthy''). -SelfTest back to
    40/40.

    v2.4.5: display adjustments to the "Full Integrity Pack" (Commands.psd1, no
    code change in this script) following real visual feedback in the console.
    Two points: (1) the header cyan switches from the classic ConsoleColor.Cyan
    (dull depending on the Windows Terminal theme) to a direct bright-cyan ANSI
    code ([char]27+'[96m', reset by [char]27+'[0m'), with no colored background or
    full banner - just more contrasted text. (2) Repair-WindowsImage's animated
    progress bar (Write-Progress) caused a visual glitch in conhost/Windows
    Terminal (it displayed in a fixed area not synced with the CHKDSK output
    scrolling) - fixed by disabling progress display via $ProgressPreference =
    'SilentlyContinue', WITHOUT reverting to the classic 'DISM /Online
    /Cleanup-Image /ScanHealth': the latter exposes its result only as localized
    text, which would have reintroduced the system-language dependency that the
    ImageHealthState guard (v2.4.2) had specifically removed. -SelfTest stays at
    40/40 (assertion unchanged, still based on the presence of 'ImageHealthState'
    and "eq 'Healthy'" in the Cmd).

    v2.4.6: fixed a blocking bug in Commands.psd1 (no code change in this script)
    introduced in v2.4.5 - the "Full Integrity Pack"'s Help field (DOUBLE-quoted,
    unlike Cmd which always stays single-quoted) contained the literal,
    unescaped text "$ProgressPreference". In double quotes, PowerShell
    interprets $ProgressPreference as variable interpolation, and
    Import-PowerShellDataFile's "restricted language" mode forbids any variable
    reference - result: complete failure to load Commands.psd1, empty fallback
    catalog, cascading failure of 10 -SelfTest assertions (command count,
    Confirm active on sensitive commands, etc.). Fixed by escaping the dollar
    sign with a backtick (`$ProgressPreference) to force it to literal text.
    Reminder of the rule: Cmd must always stay single-quoted (no interpolation
    possible, so never this risk); Desc and Help stay double-quoted by existing
    convention, but any literal $ sign written in them must always be escaped
    with a backtick. Added a dedicated -SelfTest regression assertion that scans
    every Desc/Help line in Commands.psd1 for a $ not preceded by a backtick, to
    catch this kind of bug before deployment on other machines instead of on the
    first -SelfTest run there. -SelfTest now at 41 assertions.

    v2.4.7: redesign of the "Full Integrity Pack" (Commands.psd1, no code change
    in this script) to simplify and permanently remove two problems at the
    source rather than working around them. Reverted to the classic 'DISM
    /Online /Cleanup-Image /ScanHealth' (native dism.exe) instead of the
    Repair-WindowsImage -ScanHealth PowerShell cmdlet: no more Write-Progress
    progress bar, so no more possible visual glitch in conhost/Windows Terminal
    (the problem fixed in v2.4.5 by $ProgressPreference disappears structurally,
    so that patch is no longer needed and is removed). SFC switches from
    /scannow (gated by ImageHealthState since v2.4.2) to /verifyonly: SFC never
    automatically repairs anything in this pack anymore, it only verifies - the
    original risk ("SFC repairs from a component store that is itself
    corrupted", fixed by the ImageHealthState guard in v2.4.2) therefore also
    disappears structurally, with no need for reliable detection or conditional
    logic. If CHKDSK, DISM, or SFC reports an anomaly, a final yellow message
    simply reminds you to run DISM RestoreHealth then SFC /scannow manually
    (separate commands from the catalog) - the repair remains a human decision.
    CHKDSK, DISM, and SFC remain native tools invoked directly; PowerShell now
    only serves as a wrapper for display (bright ANSI cyan + spacing).
    -SelfTest assertion updated accordingly: verifies that SFC runs in
    /verifyonly and that /scannow is never chained as an executable instruction
    (only mentioned as instructional text). -SelfTest stays at 41/41.

    v2.4.8: simplified the "Full Integrity Pack" headers (Commands.psd1, no code
    change in this script) - reverted from bright-cyan ANSI code
    ([char]27+'[96m', $c/$r variables and concatenations) to PowerShell's native
    -ForegroundColor Cyan. Verified by direct visual comparison on the target
    machine: the Windows Terminal theme in use already renders native Cyan
    vividly and contrasted enough (unlike the default "Campbell" theme, duller on
    this color slot), making the ANSI workaround unnecessary here. Shorter code,
    no intermediate variable or string concatenation. No functional change (same
    4 diagnostic steps, same behavior) - purely cosmetic/simplification.
    -SelfTest stays at 41/41 (assertion unchanged, still based on /verifyonly and
    the absence of chained /scannow).

    v2.4.9: search (Ctrl+F) extended to the Help field in addition to Label/Desc,
    already concatenated into $entry.Search since this feature was created.
    $helpCopy was already available in scope when Search was built (used just
    above for the "?" button) but was never included in the search string itself
    - an oversight rather than a choice, fixed in one line. Becomes useful with a
    catalog of 100+ commands: several relevant keywords (e.g. ASR rule GUID
    names, event codes like "6008", detailed technical terms) only appear in
    Help, not in Label or Desc, and were therefore unfindable via Ctrl+F until
    now. No behavior change for commands without Help ($helpCopy = $null, silent
    interpolation as an empty string in "$labelCopy $descCopy $helpCopy", no
    error). -SelfTest unchanged (no assertion covers $entry.Search's content).

    v2.4.10: added a -SelfTest regression assertion closing a gap found during a
    catalog audit: sequentially loading Commands.Personnel.psd1 after
    Commands.psd1 ($commandGroups[$cat.Name] = $cat.Commands) silently overwrites
    an entire category of the main catalog's content if a personal category has
    exactly the same Name - with no visible error or warning, unlike load
    failures already covered by $global:personalCatalogLoadError. The new
    assertion compares the category names of the two catalogs already loaded in
    memory ($catalogData/$personalCatalogData) and fails if a collision is
    detected, before the problem manifests as a main-catalog category being
    silently gutted with no explanation. -SelfTest now at 42 assertions.

    v2.4.11: following a full audit of the launcher and both catalogs (script +
    Commands.psd1 + Commands.Personnel.psd1), 2 fixes and 1 improvement.
    - Export-History (HTML export): removing the redundant 'powershell -NoExit
      -Command' prefix (v2.3.0) did not match '-EncodedCommand', introduced on
      08/08/2026 to work around a -Command reconstruction bug in
      cmd.exe/PowerShell 5.1. Consequence: commands using -EncodedCommand showed
      a long, unreadable Base64 blob in the export's Detail column, instead of
      the script actually executed. Fixed by decoding these commands before
      display (with a silent fallback to the raw line on invalid Base64, rather
      than crashing the export). Also added basic HTML escaping (& < >) on the
      displayed content, absent until now and without consequence as long as
      Commands.psd1 only contained classic Cmd -Command entries (already covered
      by the "no double quote" assertion), but more cautious now that a script
      decoded from Base64 is freer-form text.
    - SELFTEST region header comment: had stayed frozen at "39 assertions" since
      v2.4.0 even though the real counter had already progressed to 41 then 42
      across subsequent versions, without this comment ever being updated.
      Corrected to 44 (42 existing + 2 new below).
    - New -SelfTest assertions (42 -> 44): -SelfTest already validated the
      catalog's structure (Label/Cmd/Desc/Confirm, no double quotes, no
      unescaped $...) but no assertion checked that a -EncodedCommand decodes
      correctly - invalid or truncated Base64 breaks neither Commands.psd1
      parsing (a plain string as far as the .psd1 is concerned) nor the old
      assertion set; the failure would only show up on an actual click in the
      interface (empty window, same symptom as the "AutoPlay/AutoRun" bug that
      motivated adopting -EncodedCommand). Added 2 regression assertions: (1)
      every -EncodedCommand in the catalog decodes without exception from its
      Base64, (2) the resulting script is syntactically valid via the real
      PowerShell AST parser
      ([System.Management.Automation.Language.Parser]::ParseInput) rather than a
      simple brace/paren count - a more reliable check that does not require
      running the script (so no dependency on the Windows-only cmdlets it
      invokes).

    v2.5.0: complete overhaul of Export-History (History.html report), requested
    on 09/08/2026.
    - Visual identity aligned with SpicyCheck-v7.1: same Windows-95-like logo
      (exact SVG, paths and colors extracted directly from the supplied
      SpicyCheck report, not a reinterpretation) and same midnight-blue palette
      (--bg/--bg2.../--accent... CSS variables reused as-is), for a consistent
      identity across every report in the suite rather than each script with its
      own improvised theme.
    - Windows column removed from the table (needlessly repeated across 328+
      rows when it almost never varies) - moved into the header's meta bar, next
      to Machine/User which were already there.
    - Day groups are now collapsible (click the day header), sorted by
      descending date (most recent day first and expanded by default, earlier
      ones collapsed) rather than the log file's ascending write order - recent
      activity is what matters most on opening the report. Entry count per day
      shown next to the date. Search (filterHistory) automatically expands all
      groups as soon as text is typed, so a filtered result is never hidden
      inside a collapsed group.
    - Stat cards added at the top (total commands, active days, sensitive
      commands launched, most-used command) - an improvement not explicitly
      requested but useful, added while doing the overhaul.
    - Known limitation, not addressed in this version: the report shows the
      command that was executed, not its actual output (stdout/stderr) -
      Invoke-ConsoleCommand launches each command in a separate interactive
      cmd.exe window (Start-Process) without redirecting or capturing its
      output, so History.log only records the command itself. Capturing the
      actual output would require redirecting every invocation to a log file, a
      broader architectural change touching the catalog's 130 commands (some of
      which are deliberately left interactive/open) - out of scope for this
      version, to be revisited if the need is confirmed.

    v2.5.1: the v2.5.0 fix (-EncodedCommand decoding) had only been applied in
    Export-History (HTML export) - History.log (on write, via Write-CommandLog)
    and History.json (via Export-HistoryJson, which exported $r.Cmd with no
    transformation) therefore still contained the raw Base64 blob, unreadable
    even opened directly in a text editor outside the Toolbox (user feedback of
    09/08/2026). Decoding logic extracted into a shared Resolve-DisplayCommand
    function, called at two levels:
    - Write-CommandLog: decodes before writing the line, so History.log is
      readable from the moment it is created (only affects logging -
      Invoke-ConsoleCommand still launches the raw $Command as-is for actual
      execution).
    - Get-HistoryEntries: also decodes again on read (a no-op for lines already
      readable post-v2.5.1, the regex does not match) - retroactively fixes the
      display of entries already written in raw Base64 before this fix, both in
      History.json and the HTML export, without having to rewrite History.log
      itself on disk.
    Decoding block that had become redundant removed from Export-History (a
    single source of truth now, instead of two implementations to maintain in
    parallel).

    v2.5.2: the 2-3 longest labels in the catalog (e.g. "Sponsored suggestions
    and apps (Start menu) - disable", 61 characters - the longest in the whole
    catalog) exceeded the command button's width (334px in Segoe UI 9pt, the
    window is capped at 470px wide total, so no margin to widen the button
    without risking breaking the layout): rendered cut off/distorted at the end
    of the label rather than cleanly truncated, for lack of AutoEllipsis enabled
    on the control (user feedback of 09/08/2026, screenshot provided). Fixed by
    enabling AutoEllipsis on the button - the full label remains viewable on
    hover via the fixed description panel that already displayed it in full, so
    no information is lost, just a clean display of a truncation that was
    already unavoidable either way.

    v2.5.3: fixed a single-element array "unwrapping" bug in Export-History
    (same trap already documented and fixed elsewhere in the suite, e.g.
    Dashboard-Global_Win11), visible only when the entire history fits on a
    single day - so never noticed until now since a multi-day history naturally
    produces a real array of groups (user feedback of 08/11/2026, freshly reset
    history, 8 commands launched the same day).
    $grouped = $rows | Group-Object {...} | Sort-Object {...} -Descending: when
    Group-Object produces only ONE group, PowerShell unwraps the result and
    $grouped becomes the GroupInfo object itself rather than a one-element
    array. But GroupInfo itself has a .Count property - which represents the
    number of ITEMS IN THAT GROUP (8, in the reported case), not the number of
    groups/days (which should have been 1). The HTML row generation loop
    ($i -lt $grouped.Count) then ran 8 times instead of 1, and $grouped[$i]
    beyond index 0 no longer pointing to anything valid, generated 7 phantom
    day-separator rows ("(0 entries)", no date) in addition to the real one. The
    "Active days" stat card also showed the wrong number via the same mechanism
    ($grouped.Count reused as-is). Fixed by wrapping the entire pipeline in
    @(...), forcing $grouped to always be a real array regardless of the number
    of groups obtained (0, 1, or several) - a pattern already used several times
    elsewhere in the catalog and the suite for this same kind of trap.

    v2.5.4: preventive optimization of the interface build - wrapped the loop
    that creates the catalog's buttons (~145 commands x 3 sub-controls = ~435
    controls added to $flowPanel) with $flowPanel.SuspendLayout() /
    .ResumeLayout(), absent until now. Without it, every individual
    Controls.Add() triggered a full recalculation of the panel's layout before
    the next addition - a cost that does not grow linearly with the number of
    commands in the catalog (each new recalculation has to reposition every
    control already present), so a risk of increasingly noticeable startup
    slowdown as the catalog keeps growing. At the current scale (145 commands)
    the effect stayed imperceptible - fix applied preventively rather than in
    response to an already-observed slowdown. No change to the final rendering:
    the displayed layout is strictly identical, only the number of intermediate
    recalculations drops from ~290 (one per row/header added to $flowPanel) to 1
    (a single one, at the end, via ResumeLayout).
#>

param(
    [switch]$SelfTest
)

# ============================================================
# REGION: AUTO-ELEVATION
# ============================================================
if (-not $SelfTest) {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`""
        )
        exit
    }
}
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# Logging - Desktop\Maintenance_Reports\ToolboxCommands\History.log
# ------------------------------------------------------------
$global:logDir = Join-Path $env:USERPROFILE "Desktop\Maintenance_Reports\ToolboxCommands"
if (-not (Test-Path $global:logDir)) {
    New-Item -Path $global:logDir -ItemType Directory -Force | Out-Null
}
$global:logFile = Join-Path $global:logDir "History.log"

# Machine context, captured once at startup (avoids re-querying the registry on every command)
$global:machineName = $env:COMPUTERNAME
$global:userName    = $env:USERNAME
try {
    # ProductName (registry) stays frozen on "Windows 10 [Edition]" even on an up-to-date
    # Windows 11 install: a known Microsoft bug, never fixed (confirmed on
    # learn.microsoft.com). Win32_OperatingSystem's Caption, on the other hand, is reliable;
    # DisplayVersion (registry) is too.
    $winReg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $osCaption = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption
    $global:winInfo = "$osCaption $($winReg.DisplayVersion)".Trim()
} catch {
    $global:winInfo = "Windows (unknown version)"
}

# ------------------------------------------------------------
# Favorites - persisted to Desktop\Maintenance_Reports\ToolboxCommands\Favorites.txt
# ------------------------------------------------------------
$global:favFile = Join-Path $global:logDir "Favorites.txt"
$global:favorites = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
if (Test-Path $global:favFile) {
    foreach ($favLine in (Get-Content -Path $global:favFile -Encoding UTF8)) {
        if (-not [string]::IsNullOrWhiteSpace($favLine)) {
            [void]$global:favorites.Add($favLine.Trim())
        }
    }
}

# Category collapse state (Group -> $true if collapsed)
$global:collapsedGroups = @{}

# ------------------------------------------------------------
# Resolves a catalog Cmd into readable text for logging/export:
# commands using -EncodedCommand (Base64 UTF-16LE, used since 08/08/2026 for
# scripts too complex to survive -Command reconstruction by
# cmd.exe/PowerShell 5.1 - cf. "AutoPlay/AutoRun" bug) are decoded rather
# than left as an unreadable blob. Centralized function (single source of
# truth) called both by Write-CommandLog (so History.log is readable from
# the moment it's written, even opened directly in a text editor outside
# the Toolbox) and by Get-HistoryEntries (so entries already written in
# Base64 before this fix become readable again on re-read, both in
# History.json and the HTML export - without having to rewrite the
# existing .log file on disk).
# ------------------------------------------------------------
function global:Resolve-DisplayCommand {
    param([string]$Cmd)
    if ($Cmd -match '^powershell -NoExit -EncodedCommand\s+(\S+)') {
        try {
            return [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($matches[1])) + " (decoded from -EncodedCommand)"
        } catch {
            # Invalid Base64 (should never happen if the catalog passed -SelfTest, but
            # staying defensive rather than crashing the caller).
            return $Cmd
        }
    }
    return $Cmd
}

# ------------------------------------------------------------
# Logs a launched command
# ------------------------------------------------------------
function global:Write-CommandLog {
    param(
        [string]$Title,
        [string]$Command,
        [int]$ProcessId = 0
    )
    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $pidPart = if ($ProcessId -gt 0) { "PID=$ProcessId" } else { "PID=?" }
    $entry = "[$timestamp] PC=$($global:machineName) | User=$($global:userName) | Win=$($global:winInfo) | $pidPart | $Title -> $(Resolve-DisplayCommand $Command)"
    Add-Content -Path $global:logFile -Value $entry -Encoding UTF8
}

# ------------------------------------------------------------
# Launches a command in a new, persistent console window.
# If $Confirm is true, asks for a Yes/No confirmation before launching.
# ------------------------------------------------------------
function global:Invoke-ConsoleCommand {
    param(
        [string]$Title,
        [string]$Command,
        [string]$Desc,
        [bool]$Confirm
    )

    if ($Confirm) {
        $message = "$Desc`n`nConfirm launching:`n$Title ?"
        $result = [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Confirmation required",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }
    }

    $escapedTitle = $Title -replace '"', ''
    # -PassThru: retrieves the process object (and thus its PID) without waiting for it to
    # finish, which stays compatible with /k (window left open indefinitely to read the
    # result).
    $proc = Start-Process cmd.exe -ArgumentList "/k title $escapedTitle && $Command" -PassThru
    Write-CommandLog -Title $Title -Command $Command -ProcessId $proc.Id
}

# ------------------------------------------------------------
# Saves the favorites list to disk
# ------------------------------------------------------------
function global:Save-Favorites {
    $global:favorites | Set-Content -Path $global:favFile -Encoding UTF8
}

# ------------------------------------------------------------
# Parses History.log into a list of structured objects.
# Shared between the HTML export and the JSON export.
# ------------------------------------------------------------
function global:Get-HistoryEntries {
    if (-not (Test-Path $global:logFile)) {
        return @()
    }

    $lines = Get-Content -Path $global:logFile -Encoding UTF8
    $rows = foreach ($line in $lines) {
        # The PID=... segment is optional in the regex to stay compatible with lines
        # written before it was introduced (existing History.log, no format migration
        # needed).
        if ($line -match '^\[(?<date>[^\]]+)\] PC=(?<pc>.+?) \| User=(?<user>.+?) \| Win=(?<win>.+?) \| (?:PID=(?<pid>\d+|\?) \| )?(?<title>.+?) -> (?<cmd>.+)$') {
            [PSCustomObject]@{
                Date  = $Matches.date.Trim()
                PC    = $Matches.pc.Trim()
                User  = $Matches.user.Trim()
                Win   = $Matches.win.Trim()
                PID   = if ($Matches.pid) { $Matches.pid.Trim() } else { "" }
                Title = $Matches.title.Trim()
                # Resolve-DisplayCommand is already applied by Write-CommandLog for entries
                # written since this fix (v2.5.1), but reapplied here for entries written
                # before it (still raw Base64 on disk): this way History.json and the HTML
                # export become readable again retroactively for the entire existing
                # history, without having to rewrite History.log itself (a no-op for
                # entries already readable, the regex does not match).
                Cmd   = Resolve-DisplayCommand ($Matches.cmd.Trim())
            }
        }
    }
    return @($rows)
}

# ------------------------------------------------------------
# Exports history (History.log) as a dark-theme HTML report and opens
# it in the default browser.
# ------------------------------------------------------------
function global:Export-History {
    $rows = Get-HistoryEntries
    if ($rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No history to export yet.",
            "History export",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    # PC/User/Windows almost never vary from one line to the next (same machine) -> shown
    # once in the header instead of repeated on every line (and the Windows column was
    # removed from the table for this same reason, v2.5.0 - cf. user request of 09/08/2026),
    # which frees up width for the Detail column that needs it.
    $derniereEntree = $rows[$rows.Count - 1]

    # Sorted by descending date (most recent day first) rather than the log file's
    # ascending write order: recent activity is what matters most on opening the report.
    # ParseExact in InvariantCulture to avoid the trap documented elsewhere in the suite
    # (dd/MM/yyyy misread as MM/dd/yyyy depending on system culture).
    # @() around the whole pipeline: when the entire history fits on a single day,
    # Group-Object produces only ONE group and PowerShell "unwraps" it (same unwrapping
    # trap documented elsewhere in the suite) - $grouped then becomes the GroupInfo object
    # itself rather than a one-element array. But GroupInfo itself has a .Count property,
    # which represents the number of ITEMS IN THAT GROUP (e.g. 8 commands launched today),
    # not the number of groups/days (which should be 1) - the loop further down then ran 8
    # times instead of 1, producing 7 phantom day-separator rows ("(0 entries)") in
    # addition to the real one (user feedback of 08/11/2026, freshly reset history so
    # entirely on a single day - a condition that had masked this latent bug until then, a
    # multi-day history naturally producing a real array).
    $grouped = @($rows | Group-Object { ($_.Date -split ' ')[0] } | Sort-Object {
        [datetime]::ParseExact($_.Name, 'dd/MM/yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
    } -Descending)

    # Stat cards at the top of the report: total, number of days covered, sensitive
    # commands (Confirm=true) launched, and the most frequently used command - improvised
    # in addition to the original request as a useful improvement (v2.5.0).
    $nbSensibles = ($rows | Where-Object { $global:confirmLabels.Contains($_.Title) }).Count
    $commandePlusUtilisee = ($rows | Group-Object Title | Sort-Object Count -Descending | Select-Object -First 1).Name

    $htmlRows = for ($i = 0; $i -lt $grouped.Count; $i++) {
        $grp = $grouped[$i]
        $collapsedClass = if ($i -eq 0) { "" } else { " collapsed" }
        "<tr class=`"daysep$collapsedClass`" data-group=`"$i`" onclick=`"toggleDay($i)`"><td colspan=`"4`"><span class=`"chevron`">&#9662;</span>$($grp.Name)<span class=`"count`">($($grp.Count) entr$(if($grp.Count -gt 1){'ies'}else{'y'}))</span></td></tr>"
        foreach ($r in $grp.Group) {
            $sensible = $global:confirmLabels.Contains($r.Title)
            $rowClass = if ($sensible) { "row sensible" } else { "row" }
            $styleAttr = if ($i -eq 0) { "" } else { " style=`"display:none`"" }
            $titreHtml = if ($sensible) { "<span class=`"label-sensible`">$($r.Title)</span>" } else { $r.Title }

            # The 'powershell -NoExit -Command' prefix is identical on the vast majority of
            # non-encoded lines - removed for readability, it adds nothing new with each
            # repetition. Commands already in -EncodedCommand form are already decoded
            # upstream by Get-HistoryEntries (Resolve-DisplayCommand, v2.5.1) so this
            # -replace is already a no-op for them (no -Command prefix to find in a decoded
            # script): no need to duplicate the Base64 decoding logic here, a single source
            # of truth is enough.
            $cmdAffiche = $r.Cmd -replace '^powershell -NoExit -Command ', ''

            # Basic HTML escaping: a script decoded from Base64 is freer-form text than a
            # classic Cmd -Command entry (already validated by -SelfTest for the absence of
            # double quotes), so it's safer to never inject unescaped < > & into the
            # generated HTML, even though the current catalog does not contain any.
            $cmdAffiche = $cmdAffiche -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'

            if ($cmdAffiche.Length -gt 120) {
                $detailHtml = "<details><summary>View full command</summary><code>$cmdAffiche</code></details>"
            } else {
                $detailHtml = "<code>$cmdAffiche</code>"
            }

            "<tr class=`"$rowClass`" data-group=`"$i`"$styleAttr><td>$($r.Date)</td><td>$($r.PID)</td><td>$titreHtml</td><td>$detailHtml</td></tr>"
        }
    }

    # Windows-95-like logo and midnight-blue palette: identical (same SVG paths, same CSS
    # variables) to SpicyCheck-v7.1, for a consistent visual identity across every report
    # in the suite - cf. user request of 09/08/2026, screenshot and SpicyCheck source files
    # provided for exact extraction rather than an approximate reinterpretation.
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>History - Toolbox System Commands</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:       #080b12;
  --bg2:      #0d1117;
  --bg3:      #111827;
  --bg4:      #1a2235;
  --bg5:      #0a0f1a;
  --border:   #1e2d45;
  --border2:  #243350;
  --accent:   #00d4ff;
  --accent2:  #0099cc;
  --accent3:  #005f80;
  --purple:   #7c6af7;
  --yellow:   #ffb347;
  --text:     #e2e8f0;
  --text2:    #94a3b8;
  --text3:    #475569;
}
body{background:var(--bg);color:var(--text);font-family:'Segoe UI',system-ui,sans-serif;font-size:13px;line-height:1.6;min-height:100vh}
::-webkit-scrollbar{width:12px;height:12px}
::-webkit-scrollbar-track{background:var(--bg2)}
::-webkit-scrollbar-thumb{background:var(--border2);border-radius:6px;border:3px solid var(--bg2)}
::-webkit-scrollbar-thumb:hover{background:var(--accent3)}
header{background:linear-gradient(160deg,#060c1a 0%,#0a1628 50%,#060a14 100%);border-bottom:2px solid var(--accent3);padding:32px 48px 24px;position:relative;overflow:hidden}
header::before{content:'';position:absolute;top:0;left:0;right:0;bottom:0;background:radial-gradient(ellipse at 20% 50%,rgba(0,212,255,.06) 0%,transparent 60%),radial-gradient(ellipse at 80% 20%,rgba(124,106,247,.05) 0%,transparent 50%);pointer-events:none}
.titlerow{display:flex;align-items:flex-end;gap:0;position:relative;z-index:1}
.title-text h1{font-family:'Cascadia Code','Consolas','Courier New',monospace;font-size:26px;font-weight:700;color:var(--accent);text-shadow:0 0 20px rgba(0,212,255,.4);letter-spacing:1px;margin:0 0 10px 0}
.logo-sub{font-family:'Cascadia Code','Consolas',monospace;font-size:12px;color:var(--text2);letter-spacing:2px;margin-bottom:14px}
.logo-sub b{color:var(--accent)}
.meta-bar{display:flex;flex-wrap:wrap;gap:8px 24px;font-size:11.5px;color:var(--text3);border-top:1px solid var(--border);padding-top:12px;margin-top:4px;position:relative;z-index:1}
.meta-bar span{display:flex;align-items:center;gap:6px}
.meta-bar b{color:var(--text2)}
.meta-dot{width:5px;height:5px;border-radius:50%;background:var(--accent);display:inline-block;box-shadow:0 0 6px var(--accent)}
main{padding:24px 48px 64px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:22px}
.stat-card{background:var(--bg3);border:1px solid var(--border);border-radius:8px;padding:14px 16px}
.stat-card .num{font-size:22px;font-weight:700;color:var(--accent);line-height:1.2}
.stat-card .lbl{font-size:11px;color:var(--text3);text-transform:uppercase;letter-spacing:.05em;margin-top:2px}
.stat-card.warn .num{color:var(--yellow)}
.searchbar{margin-bottom:18px;position:sticky;top:12px;z-index:5}
.searchbar input{width:100%;max-width:380px;padding:10px 14px;background:var(--bg3);border:1px solid var(--border2);color:var(--text);border-radius:6px;font-size:13px;transition:border-color .15s,box-shadow .15s}
.searchbar input::placeholder{color:var(--text3)}
.searchbar input:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px rgba(0,212,255,.12)}
table{border-collapse:collapse;width:100%}
th,td{padding:9px 12px;border-bottom:1px solid var(--border);text-align:left;font-size:13px;vertical-align:top}
th{color:var(--accent);text-transform:uppercase;font-size:11px;letter-spacing:.05em;background:var(--bg5);position:sticky;top:52px}
tr.row{transition:background-color .1s}
tr.row:hover{background:var(--bg3)}
tr.row.sensible{background:rgba(255,179,71,.06)}
tr.row.sensible:hover{background:rgba(255,179,71,.12)}
tr.daysep{cursor:pointer;user-select:none}
tr.daysep td{background:var(--bg4);color:var(--accent);font-weight:700;font-size:12.5px;text-transform:uppercase;letter-spacing:.05em;padding:12px;border-bottom:1px solid var(--border2)}
tr.daysep:hover td{background:#212c45}
tr.daysep .count{color:var(--text3);font-weight:400;text-transform:none;letter-spacing:normal;margin-left:8px}
.chevron{display:inline-block;margin-right:8px;transition:transform .18s;color:var(--purple)}
tr.daysep.collapsed .chevron{transform:rotate(-90deg)}
.label-sensible{color:var(--yellow);font-weight:600}
.label-sensible::before{content:"⚠ "}
code{color:var(--accent2);background:var(--bg4);padding:2px 6px;border-radius:4px;font-family:Consolas,'Cascadia Code',monospace;font-size:12px;word-break:break-all}
details summary{cursor:pointer;color:var(--purple);font-size:12px;list-style:none}
details summary::-webkit-details-marker{display:none}
details summary::before{content:"▸ "}
details[open] summary::before{content:"▾ "}
details[open] summary{margin-bottom:6px;display:block}
</style>
</head>
<body>

<header>
  <div class="titlerow">
    <div class="title-text">
      <h1>History - Toolbox System Commands</h1>
      <div class="logo-sub">by <b>Nephren</b></div>
    </div>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="9.39 8.477 484.197 428.149" style="width:76px;height:76px;margin-left:24px;align-self:flex-end;filter:drop-shadow(0 0 12px rgba(0,212,255,.4));flex-shrink:0"><path d="m347.015 235.334 42.877-112.525 67.515 25.727-42.877 112.524z" fill="#a8ce81"/><path d="m303.267 350.143 42.92-112.634 67.514 25.726-42.919 112.634z" fill="#fddb1d"/><path d="m263.921 207.033 42.879-112.525 67.406 25.685-42.877 112.525z" fill="#ef7066"/><path d="m220.505 320.972 42.588-111.764 67.406 25.685-42.588 111.764z" fill="#6eaed7"/><path d="m415.69 247.559c-12.962-10.418-30.606-21.623-53.002-30.158-1.455-.43-2.827-1.077-4.131-1.574l33.307-87.41c1.755.295 3.277.875 4.893 1.864 22.194 8.083 39.661 19.097 52.64 29.147zm-44.284 116.221a216.14 216.14 0 0 0 -53.045-30.048c-1.496-.321-2.91-.86-4.131-1.574l34.136-89.586c1.673.513 3.236.984 4.893 1.865 22.153 8.192 39.62 19.206 52.392 29.8zm122.181-212.166s-25.485-37.351-81.827-59.07c-56.66-21.216-98.7-15.447-98.482-15.364l-15.038 39.466c-.135-.3 27.632-5.533 68.583 3.971l-33.597 88.172c-41.045-9.913-68.776-3.795-68.693-4.013l-10.29 27.33s27.736-7.111 69.123 2.558l-34.717 91.108c-33.74-8.499-58.772-7.828-67.506-6.798l-14.5 38.052c10.873-1.087 47.89-2.17 95.075 15.809 56.467 21.392 82.284 57.873 82.408 57.547zm-241.467-32.87 14.747-38.705 41.45-2.259-14.748 38.705zm-91.514 240.162 14.748-38.704 41.45-2.259-14.5 38.052zm16.364-42.944 13.38-35.117 41.492-2.367-13.423 35.225zm60.11-157.752 13.382-35.118 41.45-2.259-13.381 35.117zm-30.034 78.821 13.381-35.116 41.45-2.26-13.381 35.117zm-15.038 39.466 13.38-35.117 41.45-2.26-13.38 35.117zm30.035-78.823 13.422-35.225 41.45-2.259-13.423 35.225zm-10.213-90.174 11.476-30.115 40.145-2.756-11.766 30.876zm-110.927-84.974 4.93-12.937 16.36-1.112-4.93 12.937zm76.852 67.881 8.99-23.592 35.117-2.306-9.03 23.7zm-28.691-20.768 6.835-17.94 28.455-1.483-6.836 17.94zm-24.068-24.734 5.469-14.351 23.495-.884-5.179 13.59zm40.932 183.057 11.476-30.115 39.855-1.995-11.475 30.115zm-110.927-84.974 4.93-12.938 16.36-1.111-5.178 13.59zm76.852 67.881 9.031-23.7 35.077-2.198-9.032 23.7zm-28.691-20.769 6.835-17.938 28.455-1.484-6.835 17.939zm-24.067-24.734 5.22-13.698 23.743-1.536-5.179 13.59zm41.222 182.297 11.475-30.115 40.145-2.757-11.475 30.116zm-110.927-84.974 5.178-13.59 16.112-.46-4.93 12.938zm77.1 67.229 8.74-22.94 35.119-2.307-8.783 23.05zm-28.691-20.769 6.587-17.287 28.454-1.483-6.587 17.286zm-24.026-24.843 5.178-13.59 23.495-.883-5.178 13.59z" fill="#000101"/><path d="m114.017 84.174 4.889-12.83 17.411-1.582-4.888 12.829zm88.133 61.472 9.529-25.006 32.364-1.612-9.28 24.353zm-34.836-17.383 7.913-20.766 29.355-1.887-7.913 20.766zm-29.271-19.247 6.049-15.873 22.733-1.173-6.007 15.764zm-50.589-48.909 4.102-10.763 12.995-.776-4.101 10.764zm11.525 63.532 4.93-12.938 17.411-1.583-4.93 12.938zm88.133 61.472 9.57-25.114 32.612-2.265-9.528 25.006zm-34.588-18.035 7.664-20.113 29.397-1.996-7.954 20.874zm-29.478-18.703 6.007-15.764 22.734-1.174-5.758 15.112zm-50.63-48.8 4.392-11.525 12.995-.775-4.392 11.524z" fill="#ef7066"/><path d="m68.115 204.635 4.93-12.937 17.122-.822-4.93 12.938zm87.844 62.234 9.57-25.114 32.653-2.374-9.57 25.114zm-34.547-18.144 7.913-20.766 29.107-1.235-7.664 20.113zm-29.229-19.355 5.717-15.004 22.733-1.173-5.717 15.003zm-50.92-48.04 4.391-11.524 12.995-.776-4.35 11.416zm11.814 62.77 4.93-12.937 17.122-.822-4.93 12.938zm88.133 61.473 9.28-24.353 32.654-2.374-9.57 25.115zm-34.836-17.383 7.913-20.765 29.397-1.996-7.955 20.874zm-29.229-19.355 5.717-15.004 23.023-1.934-6.007 15.764zm-50.631-48.801 4.102-10.763 12.995-.775-4.101 10.763z" fill="#6eaed7"/></svg>
  </div>
  <div class="meta-bar">
    <span><span class="meta-dot"></span>Generated on <b>$(Get-Date -Format "dd MMM yyyy HH:mm:ss" -AsUTC:$false)</b></span>
    <span><b>$($rows.Count)</b> entr$(if($rows.Count -gt 1){'ies'}else{'y'})</span>
    <span>Machine: <b>$($derniereEntree.PC)</b></span>
    <span>User: <b>$($derniereEntree.User)</b></span>
    <span>Windows: <b>$($derniereEntree.Win)</b></span>
  </div>
</header>

<main>
  <div class="stats">
    <div class="stat-card"><div class="num">$($rows.Count)</div><div class="lbl">Commands launched</div></div>
    <div class="stat-card"><div class="num">$($grouped.Count)</div><div class="lbl">Active days</div></div>
    <div class="stat-card warn"><div class="num">$nbSensibles</div><div class="lbl">Sensitive commands</div></div>
    <div class="stat-card"><div class="num">$commandePlusUtilisee</div><div class="lbl">Most used command</div></div>
  </div>

  <div class="searchbar"><input type="text" id="searchBox" placeholder="Filter (command name, date, PID...)" onkeyup="filterHistory()"></div>

  <table>
    <tr><th>Date</th><th>PID</th><th>Command</th><th>Detail</th></tr>
    $($htmlRows -join "`n")
  </table>
</main>

<script>
function toggleDay(id) {
  var header = document.querySelector('tr.daysep[data-group="' + id + '"]');
  var collapsed = header.classList.toggle('collapsed');
  document.querySelectorAll('tr.row[data-group="' + id + '"]').forEach(function(r) {
    r.style.display = collapsed ? 'none' : '';
  });
}
function filterHistory() {
  var filtre = document.getElementById('searchBox').value.toLowerCase();
  var groups = document.querySelectorAll('tr.daysep');
  if (filtre === '') {
    groups.forEach(function(g, idx) {
      var id = g.getAttribute('data-group');
      var collapse = idx !== 0;
      g.classList.toggle('collapsed', collapse);
      document.querySelectorAll('tr.row[data-group="' + id + '"]').forEach(function(r) {
        r.style.display = collapse ? 'none' : '';
      });
    });
    return;
  }
  groups.forEach(function(g) { g.classList.remove('collapsed'); });
  document.querySelectorAll('tr.row').forEach(function(ligne) {
    var texte = ligne.textContent.toLowerCase();
    ligne.style.display = texte.indexOf(filtre) !== -1 ? '' : 'none';
  });
}
</script>
</body>
</html>
"@


    $htmlPath = Join-Path $global:logDir "History.html"
    Set-Content -Path $htmlPath -Value $html -Encoding UTF8
    Start-Process $htmlPath
}

# ------------------------------------------------------------
# Exports history (History.log) as structured JSON, usable by a future
# multi-machine aggregation script (same logic as the rest of the
# suite's JSON baselines).
# ------------------------------------------------------------
function global:Export-HistoryJson {
    $rows = Get-HistoryEntries
    if ($rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No history to export yet.",
            "History export",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $jsonPath = Join-Path $global:logDir "History.json"
    $rows | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
    Start-Process $jsonPath
}
# ------------------------------------------------------------
# Catalog of commands - loaded from Commands.psd1 (must be located
# in the same folder as this script). See Commands.psd1 for the
# format and conventions (in particular: Cmd is always single-quoted).
# ------------------------------------------------------------
$global:catalogPath = Join-Path $PSScriptRoot "Commands.psd1"
$commandGroups = [ordered]@{}
$global:catalogLoadError = $null
# HashSet of Labels with Confirm=$true, populated when the catalog loads - lets
# Export-History (a global function, cannot see $commandGroups which is script-scoped)
# know which history lines to highlight without having to re-parse Commands.psd1.
$global:confirmLabels = [System.Collections.Generic.HashSet[string]]::new()

if (-not (Test-Path $global:catalogPath)) {
    $global:catalogLoadError = "Commands.psd1 file not found next to the script (expected path: $global:catalogPath)."
} else {
    try {
        $catalogData = Import-PowerShellDataFile -Path $global:catalogPath -ErrorAction Stop
        foreach ($cat in $catalogData.Categories) {
            $commandGroups[$cat.Name] = $cat.Commands
            foreach ($cmdItem in $cat.Commands) {
                if ($cmdItem.Confirm) {
                    [void]$global:confirmLabels.Add($cmdItem.Label)
                }
            }
        }
    } catch {
        $global:catalogLoadError = "Failed to load Commands.psd1: $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------
# PERSONAL catalog, optional - Commands.Personnel.psd1, same folder, same format as
# Commands.psd1. Unlike the main catalog, this one is NOT meant to be shared between
# machines (settings/decisions specific to one particular machine). If absent, nothing
# happens: no error, the main catalog works normally on its own - this is what guarantees
# that Commands.psd1 + the script stay copyable as-is to another machine without this
# file. If present but invalid, same defensive logic as the main catalog: a clear message
# instead of a crash, without blocking the rest.
$global:personalCatalogPath = Join-Path $PSScriptRoot "Commands.Personnel.psd1"
$global:personalCatalogLoadError = $null
if (Test-Path $global:personalCatalogPath) {
    try {
        $personalCatalogData = Import-PowerShellDataFile -Path $global:personalCatalogPath -ErrorAction Stop
        foreach ($cat in $personalCatalogData.Categories) {
            $commandGroups[$cat.Name] = $cat.Commands
            foreach ($cmdItem in $cat.Commands) {
                if ($cmdItem.Confirm) {
                    [void]$global:confirmLabels.Add($cmdItem.Label)
                }
            }
        }
    } catch {
        $global:personalCatalogLoadError = "Failed to load Commands.Personnel.psd1: $($_.Exception.Message)"
    }
}

if ($global:catalogLoadError -and -not $SelfTest) {
    [System.Windows.Forms.MessageBox]::Show(
        $global:catalogLoadError,
        "Catalog load error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

if ($global:personalCatalogLoadError -and -not $SelfTest) {
    # Deliberately non-blocking: Commands.Personnel.psd1 is optional, an error on it must
    # never prevent the main (portable) catalog from working normally.
    [System.Windows.Forms.MessageBox]::Show(
        "$($global:personalCatalogLoadError)`n`nThe main catalog (Commands.psd1) is still loaded normally - only the personal category is missing.",
        "Personal catalog not loaded",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}

# ------------------------------------------------------------
# Updates the visibility of command rows based on:
#  - the search text ($global:searchBox)
#  - the "favorites only" filter ($global:favOnlyCheck)
#  - each category's collapse state ($global:collapsedGroups)
# The FlowLayoutPanel takes care of re-stacking visible elements
# without leaving gaps. Global function because it is called from
# WinForms event handlers.
# ------------------------------------------------------------
function global:Update-Visibility {
    $filterLower  = ""
    if ($global:searchBox) { $filterLower = $global:searchBox.Text.Trim().ToLowerInvariant() }
    $filterActive = $filterLower -ne ""

    $favOnly = $false
    if ($global:favOnlyCheck) { $favOnly = $global:favOnlyCheck.Checked }

    $groupHasMatch = @{}

    foreach ($entry in $global:layoutItems) {
        if ($entry.Type -ne "Button") { continue }

        $matchesSearch = (-not $filterActive) -or ($entry.Search -like "*$filterLower*")
        $matchesFav    = (-not $favOnly) -or $global:favorites.Contains($entry.Label)
        $groupCollapsed = [bool]$global:collapsedGroups[$entry.Group]

        $matchesFilters = $matchesSearch -and $matchesFav
        if ($matchesFilters) { $groupHasMatch[$entry.Group] = $true }

        # A collapsed category hides its commands, unless a search or the favorites filter
        # is active (in which case relevant results are shown anyway).
        $overrideCollapse = $filterActive -or $favOnly
        $entry.Control.Visible = $matchesFilters -and (-not $groupCollapsed -or $overrideCollapse)
    }

    foreach ($entry in $global:layoutItems) {
        if ($entry.Type -ne "Header") { continue }
        $entry.Control.Visible = [bool]$groupHasMatch[$entry.Group]
        $collapsed = [bool]$global:collapsedGroups[$entry.Group]
        $arrow = if ($collapsed) { "+" } else { "-" }
        $entry.Control.Text = "[$arrow] $($entry.Group)"
    }
}

# ============================================================
# REGION: SELFTEST
# 47 assertions on the integrity of the command catalog and required
# functions. Does not require admin rights, does not open the GUI.
# ============================================================
if ($SelfTest) {
    $script:testTotal = 0
    $script:testPass   = 0

    function Test-Assertion {
        param([string]$Name, [bool]$Condition)
        $script:testTotal++
        if ($Condition) {
            $script:testPass++
            Write-Host "  [PASS] $Name" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $Name" -ForegroundColor Red
        }
    }

    Write-Host "=== SelfTest Toolbox-SystemCommands ===" -ForegroundColor Cyan

    $allCommands = foreach ($grp in $commandGroups.Keys) { $commandGroups[$grp] }

    # --- Catalog structural integrity ---
    Test-Assertion "Command catalog is not empty" ($commandGroups.Count -gt 0)

    $categoriesVides = $commandGroups.Keys | Where-Object { $commandGroups[$_].Count -eq 0 }
    Test-Assertion "Every category contains at least one command" ($categoriesVides.Count -eq 0)

    Test-Assertion "At least 20 commands total" ($allCommands.Count -ge 20)

    $labelsVides = $allCommands | Where-Object { [string]::IsNullOrWhiteSpace($_.Label) }
    Test-Assertion "All labels are filled in" ($labelsVides.Count -eq 0)

    $cmdsVides = $allCommands | Where-Object { [string]::IsNullOrWhiteSpace($_.Cmd) }
    Test-Assertion "All commands have a Cmd filled in" ($cmdsVides.Count -eq 0)

    $descsVides = $allCommands | Where-Object { [string]::IsNullOrWhiteSpace($_.Desc) }
    Test-Assertion "All commands have a Desc filled in" ($descsVides.Count -eq 0)

    $confirmManquant = $allCommands | Where-Object { $null -eq $_.Confirm }
    Test-Assertion "All commands have a Confirm flag defined" ($confirmManquant.Count -eq 0)

    $labelsDupliques = $allCommands.Label | Group-Object | Where-Object { $_.Count -gt 1 }
    Test-Assertion "No duplicate label" ($labelsDupliques.Count -eq 0)

    # --- Known regressions ---
    $pipeNonEchappe = $allCommands | Where-Object { ($_.Cmd -replace '\^\|', '') -match '\|' }
    Test-Assertion "No unescaped pipe in commands (cmd.exe regression)" ($pipeNonEchappe.Count -eq 0)

    $usesWmic = $allCommands | Where-Object { $_.Cmd -match '(?i)\bwmic\b' }
    Test-Assertion "No command uses wmic (removed since Windows 11 24H2)" ($usesWmic.Count -eq 0)

    # Regression: -EncodedCommand (introduced 08/08/2026 to work around a -Command
    # reconstruction bug in cmd.exe/PowerShell 5.1 on "AutoPlay/AutoRun", then reused on
    # several commands in the Privacy/Telemetry category) encodes the script in Base64
    # UTF-16LE: invalid or truncated Base64 would break neither Commands.psd1 parsing (a
    # plain string) nor this -SelfTest without these two dedicated assertions - the failure
    # would only show up on an actual click in the interface, silently (empty window, cf.
    # the "AutoPlay/AutoRun" bug of 08/08/2026 that motivated this workaround). So each
    # -EncodedCommand is decoded here to verify (1) that the Base64 decodes without
    # exception and (2) that the resulting script is syntactically valid via the real
    # PowerShell AST parser - a more reliable check than a simple brace/paren count, and
    # one that does not require running the script (so no dependency on the Windows-only
    # cmdlets it invokes, which would even let this assertion run correctly off Windows).
    $commandesEncoded = $allCommands | Where-Object { $_.Cmd -match 'EncodedCommand\s+(\S+)' }
    $echecsDecodage = 0
    $echecsSyntaxe = 0
    foreach ($cmdEncoded in $commandesEncoded) {
        if ($cmdEncoded.Cmd -match 'EncodedCommand\s+(\S+)') {
            $b64 = $matches[1].Trim("'")
            try {
                $scriptDecode = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($b64))
                $tokensAst = $null
                $erreursAst = $null
                [void][System.Management.Automation.Language.Parser]::ParseInput($scriptDecode, [ref]$tokensAst, [ref]$erreursAst)
                if ($erreursAst -and $erreursAst.Count -gt 0) { $echecsSyntaxe++ }
            } catch {
                $echecsDecodage++
            }
        }
    }
    Test-Assertion "Every -EncodedCommand decodes correctly from its Base64" ($commandesEncoded.Count -eq 0 -or $echecsDecodage -eq 0)
    Test-Assertion "Every decoded -EncodedCommand script is syntactically valid (AST)" ($commandesEncoded.Count -eq 0 -or $echecsSyntaxe -eq 0)

    # Regression: the "Full Integrity Pack" must stay 100% diagnostic - SFC runs there in
    # /verifyonly (repairs nothing) and /scannow must never be executed automatically there
    # (only mentioned as instructional text if an anomaly is detected). Does it automatically
    # repair from a potentially corrupted component store? With /verifyonly this question no
    # longer arises: nothing is ever modified by this pack, the repair remains a human
    # decision.
    $packIntegrite = $allCommands | Where-Object { $_.Label -eq "Full Integrity Pack (CHKDSK+DISM+SFC)" }
    $packSfcGate = $packIntegrite -and ($packIntegrite.Cmd -match '(?i)sfc\s+/verifyonly') -and ($packIntegrite.Cmd -notmatch '(?i);\s*sfc\s+/scannow')
    Test-Assertion "Full Integrity Pack: SFC in /verifyonly only, never auto /scannow" $packSfcGate

    # --- External catalog (Commands.psd1) ---
    Test-Assertion "Commands.psd1 file present next to the script" (Test-Path $global:catalogPath)
    Test-Assertion "At least one command has a Help field ('?' button)" (($allCommands | Where-Object { $_.Help }).Count -gt 0)
    Test-Assertion "Commands.psd1 loads without error" (-not $global:catalogLoadError)
    Test-Assertion "Commands.Personnel.psd1 absent or loads without error (optional)" (-not $global:personalCatalogLoadError)

    # Regression: if a category in Commands.Personnel.psd1 has the same Name as a category
    # in Commands.psd1, sequential loading ($commandGroups[$cat.Name] = ...) silently
    # overwrites the main catalog's commands for that category, with no error or warning
    # visible to the user - only the personal content survives in $commandGroups. This
    # assertion catches that case before it goes unnoticed.
    $categoriesPrincipal = @($catalogData.Categories | ForEach-Object { $_.Name })
    $categoriesPersonnel = @($personalCatalogData.Categories | ForEach-Object { $_.Name })
    $categoriesEnCollision = $categoriesPersonnel | Where-Object { $categoriesPrincipal -contains $_ }
    Test-Assertion "No Commands.Personnel.psd1 category overwrites a Commands.psd1 category (silent collision regression)" ($categoriesEnCollision.Count -eq 0)

    # Regression: the Cmd field must always be single-quoted ('...'), never double-quoted
    # ("..."), to guarantee that no variable ($_, $err, etc.) is ever interpolated into it
    # by mistake (cf. the "Top RAM processes" bug of 07/30/2026, fixed structurally by this
    # naming convention rather than by case-by-case escaping).
    $catalogRaw = Get-Content -Path $global:catalogPath -Raw -ErrorAction SilentlyContinue
    $cmdEnGuillemetsDoubles = $false
    if ($catalogRaw) {
        $cmdEnGuillemetsDoubles = $catalogRaw -match 'Cmd\s*=\s*"'
    }
    Test-Assertion "Every Cmd field in Commands.psd1 is single-quoted (regression)" (-not $cmdEnGuillemetsDoubles)

    # Regression: even a Cmd correctly wrapped in single quotes must never contain a double
    # quote in its content (e.g. -Filter "Name='_Total'") - cf. the "Real-time disk latency"
    # bug of 08/01/2026 (HRESULT 0x80041017, double quotes mishandled by cmd.exe once
    # packaged into Invoke-ConsoleCommand's /k title ... &&). Prefer Where-Object with
    # single quotes over a WQL/-Filter filter that requires double quotes.
    $cmdAvecGuillemetsDoublesInternes = $false
    if ($catalogRaw) {
        $cmdLines = $catalogRaw -split "`r?`n" | Where-Object { $_ -match "^\s*Cmd\s*=\s*'" }
        $cmdAvecGuillemetsDoublesInternes = [bool]($cmdLines | Where-Object { $_ -match '"' })
    }
    Test-Assertion "No double quote in the content of Cmd commands (cmd.exe regression)" (-not $cmdAvecGuillemetsDoublesInternes)

    # Regression: the Desc and Help fields are double-quoted ("...") by convention - any $
    # sign written in them without a preceding backtick (`$) would be interpreted by
    # PowerShell as variable interpolation, which Import-PowerShellDataFile's "restricted
    # language" mode simply forbids outright (complete catalog load failure). Cf. the
    # "Full Integrity Pack" v2.4.5 bug ($ProgressPreference unescaped in Help, fixed in
    # v2.4.6).
    $descHelpAvecDollarNonEchappe = $false
    if ($catalogRaw) {
        $descHelpLines = $catalogRaw -split "`r?`n" | Where-Object { $_ -match '^\s*(Desc|Help)\s*=\s*"' }
        foreach ($ligneDescHelp in $descHelpLines) {
            $sansEchappes = $ligneDescHelp -replace '`\$', ''
            if ($sansEchappes -match '\$') { $descHelpAvecDollarNonEchappe = $true; break }
        }
    }
    Test-Assertion 'No unescaped $ in the Desc/Help fields of Commands.psd1 (interpolation regression)' (-not $descHelpAvecDollarNonEchappe)

    Test-Assertion "Get-HistoryEntries function defined" ([bool](Get-Command Get-HistoryEntries -ErrorAction SilentlyContinue))

    # v2.5.1 regression: Resolve-DisplayCommand must exist and decode correctly, otherwise
    # History.log/.json become unreadable again for any -EncodedCommand command (cf. user
    # feedback of 09/08/2026 - raw Base64 blob in both of these files).
    Test-Assertion "Resolve-DisplayCommand function defined" ([bool](Get-Command Resolve-DisplayCommand -ErrorAction SilentlyContinue))
    if (Get-Command Resolve-DisplayCommand -ErrorAction SilentlyContinue) {
        $testB64 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("Write-Host 'test'"))
        $testResultat = Resolve-DisplayCommand "powershell -NoExit -EncodedCommand $testB64"
        Test-Assertion "Resolve-DisplayCommand correctly decodes a -EncodedCommand" ($testResultat -match "Write-Host 'test'")
        Test-Assertion "Resolve-DisplayCommand leaves a classic -Command command unchanged" ((Resolve-DisplayCommand 'ipconfig /flushdns') -eq 'ipconfig /flushdns')
    }
    Test-Assertion "Export-HistoryJson function defined" ([bool](Get-Command Export-HistoryJson -ErrorAction SilentlyContinue))

    # --- Sensitive commands: confirmation always active ---
    $labelsSensibles = @(
        "CHKDSK C: /f /r (on reboot)",
        "Reset Winsock",
        "Reset TCP/IP stack",
        "Reset WU components",
        "Restart PC",
        "Shut down PC"
    )
    foreach ($labelSensible in $labelsSensibles) {
        $entree = $allCommands | Where-Object { $_.Label -eq $labelSensible }
        Test-Assertion "Confirmation active for: $labelSensible" ($entree -and $entree.Confirm -eq $true)
    }

    # --- Required functions ---
    Test-Assertion "Invoke-ConsoleCommand function defined" ([bool](Get-Command Invoke-ConsoleCommand -ErrorAction SilentlyContinue))
    Test-Assertion "Write-CommandLog function defined" ([bool](Get-Command Write-CommandLog -ErrorAction SilentlyContinue))
    Test-Assertion "Write-CommandLog accepts the ProcessId parameter (logged PID)" ((Get-Command Write-CommandLog).Parameters.ContainsKey('ProcessId'))
    Test-Assertion "Update-Visibility function defined" ([bool](Get-Command Update-Visibility -ErrorAction SilentlyContinue))
    Test-Assertion "Save-Favorites function defined" ([bool](Get-Command Save-Favorites -ErrorAction SilentlyContinue))
    Test-Assertion "Export-History function defined" ([bool](Get-Command Export-History -ErrorAction SilentlyContinue))
    Test-Assertion "confirmLabels populated for highlighting sensitive commands in the HTML export" ($global:confirmLabels.Count -gt 0)

    # --- Logging ---
    Test-Assertion "Log folder accessible or created" (Test-Path $global:logDir)
    Test-Assertion "Valid log file path" (-not [string]::IsNullOrWhiteSpace($global:logFile))
    Test-Assertion "Machine name captured" (-not [string]::IsNullOrWhiteSpace($global:machineName))
    Test-Assertion "User name captured" (-not [string]::IsNullOrWhiteSpace($global:userName))
    Test-Assertion "Windows version captured" (-not [string]::IsNullOrWhiteSpace($global:winInfo))

    # --- Favorites ---
    Test-Assertion "Valid favorites file path" (-not [string]::IsNullOrWhiteSpace($global:favFile))
    Test-Assertion "Favorites structure initialized (HashSet)" ($null -ne $global:favorites)

    # --- Auto-elevation ---
    try {
        $null = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $principalOk = $true
    } catch {
        $principalOk = $false
    }
    Test-Assertion "WindowsPrincipal check functional (auto-elevation)" $principalOk

    Write-Host ""
    if ($script:testPass -eq $script:testTotal) {
        Write-Host "ALL TESTS PASSED ($($script:testPass)/$($script:testTotal))" -ForegroundColor Green
        exit 0
    } else {
        $echecs = $script:testTotal - $script:testPass
        Write-Host "$echecs test(s) failed out of $($script:testTotal) ($($script:testPass) passed)" -ForegroundColor Red
        exit 1
    }
}

# ============================================================
# Building the interface
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text          = "Toolbox System Commands - Nephren"
$form.Size          = New-Object System.Drawing.Size(470, 780)
$form.StartPosition = "CenterScreen"
$form.BackColor     = [System.Drawing.Color]::FromArgb(24,24,27)
$form.ForeColor     = [System.Drawing.Color]::White
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 9)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox   = $false

# KeyPreview = $true: the window receives keyboard events before child controls,
# needed to intercept Ctrl+F regardless of where focus is.
$form.KeyPreview = $true
$form.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::F) {
        $global:searchBox.Focus()
        $global:searchBox.SelectAll()
        $e.SuppressKeyPress = $true
    }
})

# ------------------------------------------------------------
# Top bar: search + export + favorites filter
# In its own Dock=Top panel so it is never covered by the list
# (Dock=Fill).
# ------------------------------------------------------------
$topBar = New-Object System.Windows.Forms.Panel
$topBar.Dock = "Top"
$topBar.Height = 78
$topBar.BackColor = [System.Drawing.Color]::FromArgb(24,24,27)
$form.Controls.Add($topBar)

$global:searchBox = New-Object System.Windows.Forms.TextBox
$global:searchBox.Location = New-Object System.Drawing.Point(10, 8)
$global:searchBox.Width = 210
$global:searchBox.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
$global:searchBox.ForeColor = [System.Drawing.Color]::White
$global:searchBox.BorderStyle = "FixedSingle"
$global:searchBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$topBar.Controls.Add($global:searchBox)

$searchHint = New-Object System.Windows.Forms.Label
$searchHint.Text = "Search for a command..."
$searchHint.ForeColor = [System.Drawing.Color]::FromArgb(120,120,125)
$searchHint.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$searchHint.Location = New-Object System.Drawing.Point(14, 11)
$searchHint.AutoSize = $true
$searchHint.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
$topBar.Controls.Add($searchHint)
$searchHint.BringToFront()

$global:searchBox.Add_GotFocus({ $searchHint.Visible = $false })
$global:searchBox.Add_LostFocus({ if ($global:searchBox.Text -eq "") { $searchHint.Visible = $true } })

$exportJsonBtn = New-Object System.Windows.Forms.Button
$exportJsonBtn.Text = "Export JSON"
$exportJsonBtn.Location = New-Object System.Drawing.Point(228, 7)
$exportJsonBtn.Width = 90
$exportJsonBtn.Height = 24
$exportJsonBtn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
$exportJsonBtn.ForeColor = [System.Drawing.Color]::FromArgb(0,200,255)
$exportJsonBtn.FlatStyle = "Flat"
$exportJsonBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
$exportJsonBtn.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$exportJsonBtn.Add_Click({ Export-HistoryJson })
$topBar.Controls.Add($exportJsonBtn)

$exportBtn = New-Object System.Windows.Forms.Button
$exportBtn.Text = "Export HTML"
$exportBtn.Location = New-Object System.Drawing.Point(322, 7)
$exportBtn.Width = 100
$exportBtn.Height = 24
$exportBtn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
$exportBtn.ForeColor = [System.Drawing.Color]::FromArgb(0,200,255)
$exportBtn.FlatStyle = "Flat"
$exportBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
$exportBtn.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$exportBtn.Add_Click({ Export-History })
$topBar.Controls.Add($exportBtn)

$global:favOnlyCheck = New-Object System.Windows.Forms.CheckBox
$global:favOnlyCheck.Text = "Favorites only"
$global:favOnlyCheck.Location = New-Object System.Drawing.Point(10, 42)
$global:favOnlyCheck.AutoSize = $true
$global:favOnlyCheck.ForeColor = [System.Drawing.Color]::FromArgb(255,190,90)
$global:favOnlyCheck.Add_CheckedChanged({ Update-Visibility })
$topBar.Controls.Add($global:favOnlyCheck)

$catHint = New-Object System.Windows.Forms.Label
$catHint.Text = "Click a category to collapse it"
$catHint.ForeColor = [System.Drawing.Color]::FromArgb(120,120,125)
$catHint.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$catHint.Location = New-Object System.Drawing.Point(180, 44)
$catHint.AutoSize = $true
$topBar.Controls.Add($catHint)

# ------------------------------------------------------------
# Fixed description panel at the bottom (updates on hover)
# ------------------------------------------------------------
$descPanel = New-Object System.Windows.Forms.Panel
$descPanel.Dock = "Bottom"
$descPanel.Height = 130
$descPanel.BackColor = [System.Drawing.Color]::FromArgb(18,18,20)
$form.Controls.Add($descPanel)

$descTitle = New-Object System.Windows.Forms.Label
$descTitle.Text = "Hover over a command..."
$descTitle.ForeColor = [System.Drawing.Color]::FromArgb(0,200,255)
$descTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$descTitle.Location = New-Object System.Drawing.Point(10, 6)
$descTitle.AutoSize = $true
$descPanel.Controls.Add($descTitle)

$descLabel = New-Object System.Windows.Forms.Label
$descLabel.Text = "Each command's explanation is displayed here."
$descLabel.ForeColor = [System.Drawing.Color]::FromArgb(210,210,215)
$descLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$descLabel.Location = New-Object System.Drawing.Point(10, 26)
$descLabel.Size = New-Object System.Drawing.Size(445, 95)
$descPanel.Controls.Add($descLabel)

# Native tooltip as a fallback (useful for keyboard/Tab navigation)
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 15000
$toolTip.InitialDelay = 400
$toolTip.ReshowDelay  = 200

# ------------------------------------------------------------
# Command list: FlowLayoutPanel (automatic stacking, natively
# handles hiding filtered elements without leaving gaps)
# ------------------------------------------------------------
$flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$flowPanel.Dock = "Fill"
$flowPanel.FlowDirection = "TopDown"
$flowPanel.WrapContents = $false
$flowPanel.AutoScroll = $true
$flowPanel.BackColor = [System.Drawing.Color]::FromArgb(24,24,27)
$flowPanel.Padding = New-Object System.Windows.Forms.Padding(6)
$form.Controls.Add($flowPanel)
$flowPanel.BringToFront()

# Lookup table for filtering: each entry = {Control, Group, Search, Type, Label}
$global:layoutItems = New-Object System.Collections.Generic.List[object]

# SuspendLayout/ResumeLayout (v2.5.4): without it, every $flowPanel.Controls.Add() further
# down (about 145 x 2 = ~290 direct additions to $flowPanel - one per category header and
# one per command row, each row itself made of 3 sub-controls) triggers a full recalculation
# of the panel's layout, immediately, before the next addition. At 145 commands this cost
# stays low, but it does not grow linearly with the number of commands in the catalog (each
# new recalculation has to reposition every control already present) - a preventive fix
# before this becomes noticeable at startup if the catalog keeps growing. No visual change:
# the final layout is strictly identical, only the number of intermediate recalculations is
# reduced to a single one, right at the end (ResumeLayout), once every control is already in
# place.
$flowPanel.SuspendLayout()

foreach ($group in $commandGroups.Keys) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "[-] $group"
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(0,200,255)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lbl.AutoSize = $true
    $lbl.Margin = New-Object System.Windows.Forms.Padding(4,10,4,4)
    $lbl.Cursor = [System.Windows.Forms.Cursors]::Hand
    $flowPanel.Controls.Add($lbl)

    $groupNameCopy = $group
    $lbl.Add_Click({
        if (-not $global:collapsedGroups.ContainsKey($groupNameCopy)) {
            $global:collapsedGroups[$groupNameCopy] = $false
        }
        $global:collapsedGroups[$groupNameCopy] = -not $global:collapsedGroups[$groupNameCopy]
        Update-Visibility
    }.GetNewClosure())

    $global:layoutItems.Add([PSCustomObject]@{
        Type    = "Header"
        Control = $lbl
        Group   = $group
        Search  = $null
        Label   = $null
    })

    foreach ($item in $commandGroups[$group]) {
        # Row = small horizontal panel containing [star] + [command button]
        $row = New-Object System.Windows.Forms.FlowLayoutPanel
        $row.FlowDirection = "LeftToRight"
        $row.WrapContents = $false
        $row.AutoSize = $true
        $row.AutoSizeMode = "GrowAndShrink"
        $row.Margin = New-Object System.Windows.Forms.Padding(4,2,4,2)
        $row.BackColor = [System.Drawing.Color]::FromArgb(24,24,27)

        $labelCopy   = $item.Label
        $cmdCopy     = $item.Cmd
        $descCopy    = $item.Desc
        $confirmCopy = [bool]$item.Confirm

        $starBtn = New-Object System.Windows.Forms.Button
        $starBtn.Width = 28
        $starBtn.Height = 32
        $starBtn.Margin = New-Object System.Windows.Forms.Padding(0,0,4,0)
        $starBtn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
        $starBtn.FlatStyle = "Flat"
        $starBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
        $starBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        if ($global:favorites.Contains($labelCopy)) {
            $starBtn.Text = "*"
            $starBtn.ForeColor = [System.Drawing.Color]::FromArgb(255,190,90)
        } else {
            $starBtn.Text = "o"
            $starBtn.ForeColor = [System.Drawing.Color]::FromArgb(110,110,115)
        }
        $toolTip.SetToolTip($starBtn, "Add/remove from favorites")
        $starBtn.Add_Click({
            if ($global:favorites.Contains($labelCopy)) {
                [void]$global:favorites.Remove($labelCopy)
                $starBtn.Text = "o"
                $starBtn.ForeColor = [System.Drawing.Color]::FromArgb(110,110,115)
            } else {
                [void]$global:favorites.Add($labelCopy)
                $starBtn.Text = "*"
                $starBtn.ForeColor = [System.Drawing.Color]::FromArgb(255,190,90)
            }
            Save-Favorites
            Update-Visibility
        }.GetNewClosure())
        $row.Controls.Add($starBtn)

        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $item.Label
        $btn.Width = 334
        $btn.Height = 32
        $btn.Margin = New-Object System.Windows.Forms.Padding(0)
        $btn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
        $btn.TextAlign = "MiddleLeft"
        $btn.Padding = New-Object System.Windows.Forms.Padding(10,0,0,0)
        # The 2-3 longest labels in the catalog (e.g. "Sponsored suggestions and apps
        # (Start menu) - disable", 61 characters) exceed the button's width (334px in Segoe
        # UI 9pt): without AutoEllipsis, WinForms cuts the text off abruptly instead of
        # showing '...', which produces a distorted/unreadable rendering at the end of the
        # label (user feedback of 09/08/2026, screenshot provided). The full label remains
        # viewable on hover either way via the fixed description panel (Add_MouseEnter,
        # $descTitle.Text = $labelCopy just below) - AutoEllipsis therefore loses no
        # information, just a clean display of a truncation that was already unavoidable.
        $btn.AutoEllipsis = $true

        # Visual warning if confirmation is required
        if ($item.Confirm) {
            $btn.ForeColor = [System.Drawing.Color]::FromArgb(255,190,90)
        }

        $btn.Add_Click({
            Invoke-ConsoleCommand -Title $labelCopy -Command $cmdCopy -Desc $descCopy -Confirm $confirmCopy
        }.GetNewClosure())

        # Updates the fixed description panel on hover
        $btn.Add_MouseEnter({
            $descTitle.Text = $labelCopy
            $descLabel.Text = $descCopy
            $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0,200,255)
            $btn.FlatAppearance.BorderSize = 2
        }.GetNewClosure())
        $btn.Add_MouseLeave({
            $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
            $btn.FlatAppearance.BorderSize = 1
        }.GetNewClosure())

        # Native tooltip as a fallback (keyboard focus / accessibility)
        $toolTip.SetToolTip($btn, $descCopy)

        # Right-click: copy the raw command to the clipboard (reuse elsewhere, in a script
        # or a direct terminal, without having to retype it).
        $copyMenu = New-Object System.Windows.Forms.ContextMenuStrip
        $copyItem = New-Object System.Windows.Forms.ToolStripMenuItem "Copy command"
        $copyItem.Add_Click({
            [System.Windows.Forms.Clipboard]::SetText($cmdCopy)
        }.GetNewClosure())
        [void]$copyMenu.Items.Add($copyItem)
        $btn.ContextMenuStrip = $copyMenu

        $row.Controls.Add($btn)

        # Optional help button ("?"): reserved on EVERY row to keep consistent alignment
        # across the whole list, but active/bright only if the command has a Help field in
        # Commands.psd1 - grayed out and disabled otherwise.
        $helpCopy = $item.Help
        $helpBtn = New-Object System.Windows.Forms.Button
        $helpBtn.Text = "?"
        $helpBtn.Width = 28
        $helpBtn.Height = 32
        $helpBtn.Margin = New-Object System.Windows.Forms.Padding(4,0,0,0)
        $helpBtn.FlatStyle = "Flat"
        $helpBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        if ($helpCopy) {
            $helpBtn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
            $helpBtn.ForeColor = [System.Drawing.Color]::FromArgb(40,220,255)
            $helpBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
            $toolTip.SetToolTip($helpBtn, "More explanation")
            $helpBtn.Add_Click({
                [System.Windows.Forms.MessageBox]::Show(
                    $helpCopy,
                    $labelCopy,
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }.GetNewClosure())
        } else {
            $helpBtn.BackColor = [System.Drawing.Color]::FromArgb(32,32,36)
            $helpBtn.ForeColor = [System.Drawing.Color]::FromArgb(150,150,155)
            $helpBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(45,45,50)
            # Enabled is deliberately left $true: a disabled WinForms button (Enabled=$false)
            # ignores ForeColor and applies its own system "grayed out" rendering, which made
            # any color customization invisible. Here, no click handler attached -> visually
            # discreet but with no effect on click, without this rendering issue.
        }
        $row.Controls.Add($helpBtn)

        $flowPanel.Controls.Add($row)

        $global:layoutItems.Add([PSCustomObject]@{
            Type    = "Button"
            Control = $row
            Group   = $group
            Search  = ("$labelCopy $descCopy $helpCopy").ToLowerInvariant()
            Label   = $labelCopy
        })
    }
}

$flowPanel.ResumeLayout()

$global:searchBox.Add_TextChanged({ Update-Visibility })

Update-Visibility

[System.Windows.Forms.Application]::Run($form)

# SIG # Begin signature block
# MIIFwgYJKoZIhvcNAQcCoIIFszCCBa8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBpX0QMe27VQtv4
# llDo+3ZRJTY/HXrRbyjzOkoNDrZvcqCCAygwggMkMIICDKADAgECAhB6X4r8AlBU
# p0MV3JpMuQ6sMA0GCSqGSIb3DQEBCwUAMCoxKDAmBgNVBAMMH05lcGhyZW4gUG93
# ZXJTaGVsbCBDb2RlIFNpZ25pbmcwHhcNMjYwNzA0MDIzMzIwWhcNMzEwNzA0MDI0
# MzIwWjAqMSgwJgYDVQQDDB9OZXBocmVuIFBvd2VyU2hlbGwgQ29kZSBTaWduaW5n
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1JnV5AocUnAMNIG3nYF9
# 5mOQz5NzMYJqc9D6mq3pjRlmuYIgvYEuJL5dvt8eoAiUKd+XHTaY5wl+zt7LUon+
# TmEldVwfrYvROpI+5TDyBRc5BzY4uACsA4JUM4ienjX04BBKT3uH6JwHzBluWqcG
# Xrg16NqzDiae7WNzVrev+BME00mgSvBo3hKp3sHIvFQaAmjGXLyJd+llfnBpmoD9
# JnOxMKO7VFIlhAz5cEUnFu/xDLHgARdBUfXA5odScWKiDvygNZsH1vHo07Oo7pDK
# awR3bT6lcXWRXSUmawgE1mZra+b9qpeNol+5J+86zN83RccBKZBUtQQoyy+cv20x
# VQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# HQYDVR0OBBYEFNxVaDYoNv8UXQWnbtEy/DTaQHjYMA0GCSqGSIb3DQEBCwUAA4IB
# AQCE4NqZbeximmbNEORyLxvIYiMQwP59B9R95blQQ/zugPSt4wab61yBbgO1E3mH
# mUdN0fCHhN/u0uB7h7ZBYw1w4hnzoiBac4UYzsXH4/D41gBjutbtDllRy6/zs3dl
# /hbbHAmwKXdjNVLG9cPkpWlkvKR1DJLMugU2uj+S6k+U7DfHo76sbAKqiu3biXtd
# mao6PP99EU7JBYZjsJ+BsnYcZ2KcnZ8TKiRuhSXoxAyPman7Z0BVo1H2O+fxd96b
# 4W8VclmpFh7T2CyRAHolwEy5coFYyueisO0PZg+nKwXr66+m1T1CBLQYwh79/SKO
# wGUJyU5RtTryD+hfLwkTQKVCMYIB8DCCAewCAQEwPjAqMSgwJgYDVQQDDB9OZXBo
# cmVuIFBvd2VyU2hlbGwgQ29kZSBTaWduaW5nAhB6X4r8AlBUp0MV3JpMuQ6sMA0G
# CWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIKNkBUfP0R6+mS+WfdI0sifoYFwFSbPEVtc7SQdE
# rmaZMA0GCSqGSIb3DQEBAQUABIIBADPsM/F5b4N22lVg0AvWh4oJPpde9i5YwOAx
# 2QVt8/v57IWvGl9jH1hzrCS1VD+0lvZjvW+tgZCSEhnByierWJg2B+FQWLtB3U/8
# DE9ZJAERgUADACsJTNNJimHLnPYDNMoRDaDHq8JeM+M7L3ZU0hIrZXskdFY3FAoA
# CaxTAIOCs97OoYA0P9+qY967Png9BkO6OL+H5yKWlCAqK6GG3WS2yuvVhLp6yb2A
# bft9lRX/NGX8pmoEuiR3NBDaK0BhN6WAPYmMPjnnbEdyn1CcdWKxM58VnJDtOhIv
# tK025nOQrOVW19IYED3KLIgxjLW0lJykFxYB76221nR+cJ+N4LU=
# SIG # End signature block
