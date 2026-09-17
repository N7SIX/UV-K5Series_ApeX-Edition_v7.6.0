# Compile and exercise extracted firmware functions with host GCC (no radio I/O).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path ([IO.Path]::GetTempPath()) ('apex-sclist-test-' + [guid]::NewGuid())
New-Item -ItemType Directory $out | Out-Null
function Extract-Function($relative, $signature) {
    $text = [IO.File]::ReadAllText((Join-Path $root $relative))
    $start = $text.IndexOf($signature)
    if ($start -lt 0) { throw "Missing function: $signature" }
    $brace = $text.IndexOf('{', $start)
    $depth = 1; $end = $brace + 1
    while ($depth -gt 0 -and $end -lt $text.Length) {
        if ($text[$end] -eq '{') { $depth++ }
        if ($text[$end] -eq '}') { $depth-- }
        $end++
    }
    if ($depth -ne 0) { throw "Unbalanced function: $signature" }
    return $text.Substring($start, $end - $start)
}
$code = @'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#define MR_CHANNEL_LAST 199u
#define BAND7_470MHz 6
#define IS_MR_CHANNEL(ch) ((ch) <= MR_CHANNEL_LAST)
#define MENU_S_LIST 1
// Minimal host fixtures; no hardware or EEPROM writes.
typedef struct { uint8_t band, scanlist1, scanlist2, scanlist3; } ChannelAttributes_t;
static ChannelAttributes_t gMR_ChannelAttributes[200];
static bool gMR_ChannelExclude[200];
static struct {
    uint8_t SCAN_LIST_DEFAULT;
    bool SCAN_LIST_ENABLED[3];
    uint8_t SCANLIST_PRIORITY_CH1[3], SCANLIST_PRIORITY_CH2[3];
} gEeprom;
static int32_t gSubMenuSelection;
static int UI_MENU_GetCurrentMenuId(void) { return MENU_S_LIST; }
static int MENU_GetLimits(int id, int32_t *min, int32_t *max) {
    (void)id; *min=1; *max=200; return 0;
}
// Wrap helper fixture; tested menu always passes a cursor in 0..3.
static int NUMBER_AddWithWraparound(int n, int d, int min, int max) {
    n += d; return n < min ? max : n > max ? min : n;
}
'@
$code += "`n" + (Extract-Function 'app/menu.c' 'static bool MENU_GetScanListIndex(')
$code += "`n" + (Extract-Function 'app/menu.c' 'static void MENU_ClampSelection(')
$code += "`n" + (Extract-Function 'radio/radio.c' 'bool RADIO_ChannelInScanList(')
$code += "`n" + (Extract-Function 'radio/radio.c' 'bool RADIO_CheckValidChannel(')
$code += "`n" + (Extract-Function 'ui/main.c' 'static bool ScanProgress_ChannelBelongsToList(')
$code += @'

int main(void) {
    const int cycle[] = {1,2,3,200};
    for (int i=0;i<4;i++) {
        gSubMenuSelection=cycle[i]; MENU_ClampSelection(1);
        assert(gSubMenuSelection==cycle[(i+1)%4]);
        gSubMenuSelection=cycle[i]; MENU_ClampSelection(-1);
        assert(gSubMenuSelection==cycle[(i+3)%4]);
    }
    unsigned checks=0;
    for (unsigned list=0;list<256;list++) {
        uint8_t index=99;
        gEeprom.SCAN_LIST_DEFAULT=list;
        bool real=list>=1 && list<=3;
        assert(MENU_GetScanListIndex(&index)==real);
        assert(index==(real ? list-1 : 99));
        for (int d=-1;d<=1;d+=2) {
            gSubMenuSelection=list; MENU_ClampSelection(d);
            assert((gSubMenuSelection>=1 && gSubMenuSelection<=3) || gSubMenuSelection==200);
        }
        for (unsigned mask=0;mask<8;mask++) for (int enabled=0;enabled<2;enabled++) {
            ChannelAttributes_t *a=&gMR_ChannelAttributes[10];
            *a=(ChannelAttributes_t){0,!!(mask&1),!!(mask&2),!!(mask&4)};
            for (int i=0;i<3;i++) {
                gEeprom.SCAN_LIST_ENABLED[i]=enabled;
                gEeprom.SCANLIST_PRIORITY_CH1[i]=10;
                gEeprom.SCANLIST_PRIORITY_CH2[i]=20;
            }
            bool expected=list>4 ? true : list==0 ? mask==0 : list==4 ? mask!=0 : !!(mask&(1u<<(list-1)));
            if (real && enabled) expected=false;
            gMR_ChannelExclude[10]=false;
            assert(RADIO_CheckValidChannel(10,true,list)==expected);
            assert(ScanProgress_ChannelBelongsToList(10,a,list)==expected);
            gMR_ChannelExclude[10]=true;
            assert(!RADIO_CheckValidChannel(10,true,list));
            // Progress retains excluded entries to render them separately.
            assert(ScanProgress_ChannelBelongsToList(10,a,list)==expected);
            assert(RADIO_CheckValidChannel(10,false,list));
            a->band=7;
            assert(!RADIO_CheckValidChannel(10,false,list));
            assert(!ScanProgress_ChannelBelongsToList(10,a,list));
            checks++;
        }
    }
    assert(!RADIO_CheckValidChannel(200,true,200));
    printf("PASS: bidirectional cycle, 256 index/selection cases, %u filter/progress cases\n",checks);
    return 0;
}
'@
$source = Join-Path $out 'sclist.c'
$exe = Join-Path $out 'sclist.exe'
[IO.File]::WriteAllText($source, $code)
& gcc -std=c11 -Wall -Wextra -Werror -O0 $source -o $exe
if ($LASTEXITCODE -ne 0) { throw 'Host compilation failed' }
& $exe
if ($LASTEXITCODE -ne 0) { throw 'Regression test failed' }
Write-Output "Host fixtures and executable: $out"
