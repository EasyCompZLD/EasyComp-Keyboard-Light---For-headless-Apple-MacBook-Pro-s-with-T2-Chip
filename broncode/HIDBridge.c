#include "HIDBridge.h"
/* Include the single verified driver; do not duplicate protocol implementations. */
#define main ecz_backlight_cli_entry
#include "HIDBacklight.c"
#undef main

int32_t ECZBacklightRun(const char *mode, const char *level, int32_t read_only) {
    if(!mode)return 2;
    int query=!strcmp(mode,"probe") || !strcmp(mode,"diagnose") || !strcmp(mode,"permissions");
    int on=!strcmp(mode,"on"),off=!strcmp(mode,"off");
    if((read_only && !query) || (!query && !on && !off))return 2;
    if(on && (!level || !*level))return 2;
    if(!on && level && *level)return 2;
    char *argv[]={"ecz-native-hid-host",(char *)mode,(char *)level,NULL};
    return ecz_backlight_cli_entry(on?3:2,argv);
}
